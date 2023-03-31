const std = @import("std");
const uefi = std.os.uefi;
const elf = std.elf;
const efi = @import("efi.zig");
const logger = @import("logger.zig");
const mem = @import("mem.zig");

pub fn main() void {
    efiMain() catch {
        while (true) {}
    };
}

fn efiMain() !void {
    try efi.init(uefi.system_table);
    logger.setLoevel(.Debug);

    errdefer |err| {
        logger.log(.Error, "Loader error is {s}\r\n", .{@errorName(err)});
    }

    try efi.con_out.clearScreen().err();

    logger.log(.Info, "start boot\r\n", .{});

    var frame_buffer_config = efi.FrameBufferConfig{
        .frame_buffer = @intToPtr([*]u8, efi.gop.mode.frame_buffer_base),
        .pixels_per_scan_line = efi.gop.mode.info.pixels_per_scan_line,
        .horizontal_resolution = efi.gop.mode.info.horizontal_resolution,
        .vertical_resolution = efi.gop.mode.info.vertical_resolution,
        .pixel_format = switch (efi.gop.mode.info.pixel_format) {
            .PixelRedGreenBlueReserved8BitPerColor => efi.PixelFormat.PixelRGBResv8BitPerColor,
            .PixelBlueGreenRedReserved8BitPerColor => efi.PixelFormat.PixelBGRResv8BitPerColor,
            else => unreachable,
        },
    };
    logger.log(.Info, "frame_buffer={*}, horizontal={x}, vertical={x}\r\n", .{
        frame_buffer_config.frame_buffer,
        frame_buffer_config.horizontal_resolution,
        frame_buffer_config.vertical_resolution,
    });
    const writer = efi.PixelWriter.init(&frame_buffer_config);

    var mmap = efi.MemoryMap{};
    try getMemoryMap(&mmap);
    logger.log(.Info, "get memory map\r\n", .{});

    var root_dir: *uefi.protocols.FileProtocol = undefined;
    try efi.fs.openVolume(&root_dir).err();
    logger.log(.Info, "open root directory\r\n", .{});

    var kernel_file: *uefi.protocols.FileProtocol = undefined;
    try root_dir.open(
        &kernel_file,
        &[_:0]u16{ 'k', 'e', 'r', 'n', 'e', 'l', '.', 'e', 'l', 'f' },
        uefi.protocols.FileProtocol.efi_file_mode_read,
        uefi.protocols.FileProtocol.efi_file_read_only,
    ).err();
    // try root_dir.close().err();
    logger.log(.Info, "open kernel.elf\r\n", .{});

    var file_info_size: usize = 0;
    var file_info: uefi.protocols.FileInfo = undefined;
    if (kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info)) != .Success) {
        logger.log(.Debug, "file_info_size: 0x{x}\r\n", .{file_info_size});
        try kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info)).err();
    }
    logger.log(.Info, "get file info: file_size={d}\r\n", .{file_info.file_size});

    var header_size: usize = @sizeOf(elf.Elf64_Ehdr);
    var header_buffer: [*]align(8) u8 = undefined;
    try readAndAllocate(kernel_file, &header_size, &header_buffer);
    const header = try elf.Header.parse(header_buffer[0..64]);
    const entry_point = header.entry;
    logger.log(.Info, "kernel entry point=0x{x}\r\n", .{entry_point});

    var kernel_first_addr: elf.Elf64_Addr align(4096) = std.math.maxInt(elf.Elf64_Addr);
    var kernel_last_addr: elf.Elf64_Addr = 0;
    var iter = header.program_header_iterator(kernel_file);
    logger.log(.Debug, "PhysAddr, FileSiz, MemSiz\r\n", .{});
    while (try iter.next()) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        logger.log(.Debug, "0x{x:0>6}, 0x{x:0>5}, 0x{x:0>4}\r\n", .{ phdr.p_paddr, phdr.p_filesz, phdr.p_memsz });
        if (phdr.p_vaddr < kernel_first_addr) {
            kernel_first_addr = phdr.p_vaddr;
        }
        if (phdr.p_vaddr + phdr.p_memsz > kernel_last_addr) {
            kernel_last_addr = phdr.p_vaddr + phdr.p_memsz;
        }
    }
    logger.log(.Info, "kernel: first_addr=0x{x}, last_addr=0x{x}\r\n", .{ kernel_first_addr, kernel_last_addr });

    var pages = (kernel_last_addr - kernel_first_addr + 0xfff) / 0x1000;
    try efi.bs.allocatePages(.AllocateAddress, .LoaderData, pages, @ptrCast(*[*]align(4096) u8, &kernel_first_addr)).err();
    logger.log(.Info, "allocate pages for kernel\r\n", .{});

    try efi.bs.freePool(header_buffer).err();

    try exitBootServices(mmap.map_key);

    {
        var x: usize = 0;
        // while (x < frame_buffer_config.horizontal_resolution) : (x += 1) {
        while (x < 50) : (x += 1) {
            var y: usize = 0;
            // while (y < frame_buffer_config.vertical_resolution) : (y += 1) {
            while (y < 50) : (y += 1) {
                writer.write(x, y, .{ .r = 45, .g = 118, .b = 237 });
            }
        }
    }

    while (true) {}
}

fn readAndAllocate(file: *uefi.protocols.FileProtocol, size: *usize, buffer: *[*]align(8) u8) !void {
    try efi.bs.allocatePool(uefi.tables.MemoryType.LoaderData, size.*, buffer).err();
    try file.read(size, buffer.*).err();
}

fn exitBootServices(map_key: usize) !void {
    if (efi.bs.exitBootServices(uefi.handle, map_key) == uefi.Status.InvalidParameter) {
        var mmap = efi.MemoryMap{};
        try getMemoryMap(&mmap);
        try efi.bs.exitBootServices(uefi.handle, mmap.map_key).err();
    }
}

fn getMemoryMap(mmap: *efi.MemoryMap) !void {
    while (uefi.Status.BufferTooSmall == efi.bs.getMemoryMap(
        &mmap.mem_size,
        mmap.descriptors,
        &mmap.map_key,
        &mmap.descriptor_size,
        &mmap.descriptor_version,
    )) {
        try efi.bs.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap.mem_size, @ptrCast(*[*]align(8) u8, &mmap.descriptors)).err();
    }
}
