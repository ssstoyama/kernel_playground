const std = @import("std");
const uefi = std.os.uefi;
const elf = std.elf;
const efi = @import("efi.zig");

pub fn main() void {
    efi_main() catch {
        while (true) asm volatile ("hlt");
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

    var file_info_size: usize = 0;
    var file_info: uefi.protocols.FileInfo = undefined;
    if (kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info)) != .Success) {
        status = kernel_file.getInfo(&uefi.protocols.FileInfo.guid, &file_info_size, @ptrCast([*]u8, &file_info));
        try efi.tryStatus(status);
    }
    efi.printf("get kernel file info\r\n", .{});

    var kernel_buffer: [*]align(8) u8 = undefined;
    try readAndAllocate(kernel_file, &file_info.file_size, &kernel_buffer);

    const header = try elf.Header.parse(kernel_buffer[0..@sizeOf(elf.Elf64_Ehdr)]);
    efi.printf("parse header from kernel file\r\n", .{});

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
        loadProgramSegment(@ptrToInt(kernel_buffer), phdr);
    }
    efi.printf("load program segment\r\n", .{});

    const entry_point = header.entry;
    efi.printf("kernel_entry_point=0x{x}\r\n", .{entry_point});

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

fn loadProgramSegment(base: usize, phdr: elf.Elf64_Phdr) void {
    if (phdr.p_type != elf.PT_LOAD) return;
    var dest: [*]u8 = @intToPtr([*]u8, phdr.p_vaddr);
    var src: [*]u8 = @intToPtr([*]u8, base + phdr.p_offset);
    efi.bs.copyMem(dest, src, phdr.p_filesz);
    var zero_fill_count = phdr.p_memsz - phdr.p_filesz;
    if (zero_fill_count > 0) {
        efi.bs.setMem(@intToPtr([*]u8, phdr.p_vaddr + phdr.p_filesz), zero_fill_count, 0);
    }
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
