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
    _ = writer;

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
    logger.log(.Info, "open kernel.elf\r\n", .{});

    var file_info_size: usize = 0;
    var file_info: uefi.protocols.FileInfo = undefined;
    if (kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info)) != .Success) {
        logger.log(.Debug, "file_info_size: 0x{x}\r\n", .{file_info_size});
        try kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info)).err();
    }
    logger.log(.Info, "get file info: file_size={d}\r\n", .{file_info.file_size});

    var kernel_buffer: [*]align(8) u8 = undefined;
    try readAndAllocate(kernel_file, &file_info.file_size, &kernel_buffer);
    logger.log(.Info, "loaded kernel buffer: {*}\r\n", .{kernel_buffer});

    // var header_size: usize = @sizeOf(elf.Elf64_Ehdr);
    // var header_buffer: [*]align(8) u8 = undefined;
    // try readAndAllocate(kernel_file, &header_size, &header_buffer);
    const header = try elf.Header.parse(kernel_buffer[0..@sizeOf(elf.Elf64_Ehdr)]);
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

    iter = header.program_header_iterator(kernel_file);
    while (try iter.next()) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        loadProgramSegment(@ptrToInt(kernel_buffer), phdr);
    }

    // try kernel_file.close().err();
    // try efi.bs.freePool(header_buffer).err();
    try efi.bs.freePool(kernel_buffer).err();
    try root_dir.close().err();
    logger.log(.Info, "free temporary memory\r\n", .{});

    // カーネル実行
    const kernel_entry = @intToPtr(*fn () callconv(.C) void, entry_point);
    logger.log(.Debug, "kernel_first_addr=0x{x}, kernel_last_addr=0x{x}\r\n", .{ kernel_first_addr, kernel_last_addr });
    logger.log(.Debug, "entry_point={x}, kernel_entry={*}\r\n", .{ entry_point, kernel_entry });

    try exitBootServices(mmap.map_key);

    {
        var x: usize = 0;
        while (x < 200) : (x += 1) {
            var y: usize = 0;
            while (y < 200) : (y += 1) {
                var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * y + x)]);
                p[0] = 255;
                p[1] = 0;
                p[2] = 0;
            }
        }
    }

    kernel_entry();

    {
        var x: usize = 0;
        while (x < 150) : (x += 1) {
            var y: usize = 0;
            while (y < 150) : (y += 1) {
                var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * y + x)]);
                p[0] = 0;
                p[1] = 255;
                p[2] = 0;
            }
        }
    }

    while (true) {}
}

fn loadProgramSegment(base: usize, phdr: elf.Elf64_Phdr) void {
    logger.log(.Debug, "base: 0x{x}\r\n", .{base});
    if (phdr.p_type != elf.PT_LOAD) return;
    var dest: [*]u8 = @intToPtr([*]u8, phdr.p_vaddr);
    var src: [*]u8 = @intToPtr([*]u8, base + phdr.p_offset);
    logger.log(.Debug, "copyMem: dest=0x{x}, src=0x{x}, len=0x{x}\r\n", .{ phdr.p_vaddr, base + phdr.p_offset, phdr.p_filesz });
    efi.bs.copyMem(dest, src, phdr.p_filesz);
    var zero_fill_count = phdr.p_memsz - phdr.p_filesz;
    if (zero_fill_count > 0) {
        logger.log(.Debug, "zero fill: start=0x{x}, len=0x{x}\r\n", .{ phdr.p_vaddr + phdr.p_filesz, zero_fill_count });
        efi.bs.setMem(@intToPtr([*]u8, phdr.p_vaddr + phdr.p_filesz), zero_fill_count, 0);
    }
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
