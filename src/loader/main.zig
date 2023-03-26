const std = @import("std");
const uefi = std.os.uefi;
const efi = @import("efi.zig");
const logger = @import("logger.zig");
const mem = @import("mem.zig");

pub fn main() void {
    efi_main() catch unreachable;
}

fn efi_main() !void {
    try efi.init(uefi.system_table);

    errdefer |err| {
        logger.log(.Error, "Loader error is {s}\r\n", .{@errorName(err)});
    }
    logger.setLoevel(.Debug);
    logger.log(.Info, "Start boot loader\r\n", .{});

    const mem_size = 1024 * 1024;
    var descriptors = [_]uefi.tables.MemoryDescriptor{undefined} ** (mem_size / @sizeOf(uefi.tables.MemoryDescriptor));
    var mmap = mem.MemoryMap.init(mem_size, &descriptors);
    _ = try mem.getMemoryMap(&mmap);
    {
        var i: usize = 0;
        logger.log(.Debug, "Index, Type, PhysicalStart, NumberOfPages, Attribute\r\n", .{});
        while (i < mmap.descriptor_count) : (i += 1) {
            const descriptor: uefi.tables.MemoryDescriptor = mmap.descriptors[i];
            if (descriptor.type != uefi.tables.MemoryType.ConventionalMemory) continue;
            logger.log(
                .Debug,
                "{d}, {d}, {x}, {x}, {}\r\n",
                .{
                    i,
                    descriptor.type,
                    descriptor.physical_start,
                    descriptor.number_of_pages,
                    descriptor.attribute.memory_runtime,
                },
            );
        }
    }

    while (true) {}
}
