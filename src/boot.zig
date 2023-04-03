const std = @import("std");
const uefi = std.os.uefi;
const elf = std.elf;
const efi = @import("efi.zig");
const util = @import("util.zig");

pub fn main() void {
    efi_main() catch {
        util.halt();
    };
}
fn efi_main() !void {
    var status: uefi.Status = undefined;

    status = efi.init();
    try efi.tryStatus(status);

    errdefer |err| {
        efi.printf("boot error: {}\r\r", .{err});
    }

    status = efi.con_out.clearScreen();
    try efi.tryStatus(status);

    efi.printf("start boot\r\n", .{});

    const frame_buffer_config = efi.FrameBufferConfig{
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

    var root_dir: *uefi.protocols.FileProtocol = undefined;
    status = efi.fs.openVolume(&root_dir);
    try efi.tryStatus(status);
    efi.printf("open root dir\r\n", .{});

    var kernel_file: *uefi.protocols.FileProtocol = undefined;
    status = root_dir.open(
        &kernel_file,
        &[_:0]u16{ 'k', 'e', 'r', 'n', 'e', 'l', '.', 'e', 'l', 'f' },
        uefi.protocols.FileProtocol.efi_file_mode_read,
        uefi.protocols.FileProtocol.efi_file_read_only,
    );
    try efi.tryStatus(status);
    efi.printf("open kernel file\r\n", .{});

    var header_buffer: [*]align(8) u8 = undefined;
    var header_size: usize = @sizeOf(elf.Elf64_Ehdr);
    try readAndAllocate(kernel_file, &header_size, &header_buffer);
    efi.printf("read header buffer\r\n", .{});

    const header = try elf.Header.parse(header_buffer[0..@sizeOf(elf.Elf64_Ehdr)]);
    efi.printf("parse header from header buffer\r\n", .{});

    var kernel_first_addr: elf.Elf64_Addr align(4096) = std.math.maxInt(elf.Elf64_Addr);
    var kernel_last_addr: elf.Elf64_Addr = 0;
    var iter = header.program_header_iterator(kernel_file);
    while (try iter.next()) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        if (phdr.p_vaddr < kernel_first_addr) {
            kernel_first_addr = phdr.p_vaddr;
        }
        if (phdr.p_vaddr + phdr.p_memsz > kernel_last_addr) {
            kernel_last_addr = phdr.p_vaddr + phdr.p_memsz;
        }
    }
    efi.printf("find kernel addr:  first_addr=0x{x}, last_addr=0x{x}\r\n", .{ kernel_first_addr, kernel_last_addr });

    var pages = (kernel_last_addr - kernel_first_addr + 0xfff) / 0x1000;
    status = efi.bs.allocatePages(.AllocateAddress, .LoaderData, pages, @ptrCast(*[*]align(4096) u8, &kernel_first_addr));
    try efi.tryStatus(status);
    efi.printf("allocate pages for kernel:  pages=0x{x}\r\n", .{pages});

    iter = header.program_header_iterator(kernel_file);
    while (try iter.next()) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        try loadProgramSegment(kernel_file, phdr);
    }
    efi.printf("load program segment\r\n", .{});

    const entry_point = header.entry;
    efi.printf("kernel_entry_point=0x{x}\r\n", .{entry_point});

    status = efi.bs.freePool(header_buffer);
    try efi.tryStatus(status);
    status = kernel_file.close();
    try efi.tryStatus(status);
    status = root_dir.close();
    try efi.tryStatus(status);
    efi.printf("free temporary resource\r\n", .{});

    efi.printf("exit boot service\r\n", .{});
    try exitBootServices();

    var boot_info = efi.BootInfo{
        .frame_buffer_config = &frame_buffer_config,
    };

    efi.startKernel(entry_point, &boot_info);

    return uefi.Status.LoadError.err();
}

fn exitBootServices() !void {
    var mmap = efi.MemoryMap{};
    try getMemoryMap(&mmap);
    var status = efi.bs.exitBootServices(uefi.handle, mmap.map_key);
    try efi.tryStatus(status);
}

fn loadProgramSegment(kernel_file: *uefi.protocols.FileProtocol, phdr: elf.Elf64_Phdr) !void {
    if (phdr.p_type != elf.PT_LOAD) return;

    var status: uefi.Status = undefined;
    var segment: [*]u8 = @intToPtr([*]u8, phdr.p_vaddr);
    efi.printf("segment address: {*}\r\n", .{segment});

    status = kernel_file.setPosition(phdr.p_offset);
    try efi.tryStatus(status);
    efi.printf("kernel file offset: 0x{x}\r\n", .{phdr.p_offset});

    var mem_size: usize = phdr.p_memsz;
    status = kernel_file.read(&mem_size, segment);
    try efi.tryStatus(status);
    efi.printf("read kernel file: size=0x{x}\r\n", .{mem_size});

    var zero_fill_count = phdr.p_memsz - phdr.p_filesz;
    if (zero_fill_count > 0) {
        efi.bs.setMem(@intToPtr([*]u8, phdr.p_vaddr + phdr.p_filesz), zero_fill_count, 0);
    }
    efi.printf("zero fill count: 0x{x}\r\n", .{zero_fill_count});
}

fn readAndAllocate(file: *uefi.protocols.FileProtocol, size: *usize, buffer: *[*]align(8) u8) !void {
    var status: uefi.Status = undefined;
    status = efi.bs.allocatePool(uefi.tables.MemoryType.LoaderData, size.*, buffer);
    try efi.tryStatus(status);
    status = file.read(size, buffer.*);
    try efi.tryStatus(status);
}

fn getMemoryMap(mmap: *efi.MemoryMap) !void {
    while (uefi.Status.BufferTooSmall == efi.bs.getMemoryMap(
        &mmap.mem_size,
        mmap.descriptors,
        &mmap.map_key,
        &mmap.descriptor_size,
        &mmap.descriptor_version,
    )) {
        var status = efi.bs.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap.mem_size, @ptrCast(*[*]align(8) u8, &mmap.descriptors));
        try efi.tryStatus(status);
    }
}
