const std = @import("std");
const uefi = std.os.uefi;
const efi = @import("efi.zig");
const logger = @import("logger.zig");
const mem = @import("mem.zig");

pub fn main() void {
    efi_main() catch {
        while (true) {}
    };
}

fn efi_main() !void {
    try efi.init(uefi.system_table);

    try efi.con_out.clearScreen().err();

    errdefer |err| {
        logger.log(.Error, "Loader error is {s}\r\n", .{@errorName(err)});
    }
    logger.setLoevel(.Debug);
    logger.log(.Info, "Start boot loader\r\n", .{});

    var mmap = try mem.MemoryMap.init();
    logger.log(.Info, "map_size: 0x{x}, descriptor_size: 0x{x}, sizeOf(MemoryDescriptor): 0x{x}\r\n", .{ mmap.mem_size, mmap.descriptor_size, @sizeOf(uefi.tables.MemoryDescriptor) });

    try saveMemmap(mmap);

    while (true) {}
}

fn saveMemmap(mmap: mem.MemoryMap) !void {
    var root_file_system: *uefi.protocols.FileProtocol = undefined;
    try efi.fs.openVolume(&root_file_system).err();
    logger.log(.Info, "Opened root file system\r\n", .{});

    var mmap_file: *uefi.protocols.FileProtocol = undefined;
    var title = [_:0]u16{0} ** 10;
    efi.string(&title, "memmap.txt");
    try root_file_system.open(
        &mmap_file,
        &title,
        uefi.protocols.FileProtocol.efi_file_mode_read | uefi.protocols.FileProtocol.efi_file_mode_write | uefi.protocols.FileProtocol.efi_file_mode_create,
        0,
    ).err();
    defer {
        _ = mmap_file.flush();
        _ = mmap_file.close();
    }
    logger.log(.Info, "Opened memmap.txt\r\n", .{});

    var header = "Index, PhysicalStart, NumberOfPages, Type\n".*;
    var header_size = header.len;
    try mmap_file.write(&header_size, &header).err();

    {
        var i: usize = 0;
        var buf: [4096]u8 = undefined;
        while (i < mmap.descriptor_count) : (i += 1) {
            var descriptor = mmap.at(i);
            const text = try std.fmt.bufPrint(
                &buf,
                "{d:0>5}, 0x{x:0>11}, 0x{x:0>11}, {d}\n",
                .{
                    i,
                    descriptor.physical_start,
                    descriptor.number_of_pages,
                    descriptor.type,
                },
            );
            var buf_size = text.len;
            try mmap_file.write(&buf_size, &buf).err();
        }
    }

    logger.log(.Info, "Written MemoryMap to memmap.txt\r\n", .{});
}
