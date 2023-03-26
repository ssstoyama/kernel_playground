const uefi = @import("std").os.uefi;
const efi = @import("efi.zig");
const logger = @import("logger.zig");
const MemoryDescriptor = uefi.tables.MemoryDescriptor;

pub const MemoryMap = struct {
    mem_size: usize,
    descriptors: [*]MemoryDescriptor,
    map_key: usize = 0,
    descriptor_size: usize = 0,
    descriptor_version: u32 = 0,
    descriptor_count: usize = 0,

    pub fn init(comptime mem_size: usize, descriptors: [*]MemoryDescriptor) MemoryMap {
        return .{
            .mem_size = mem_size,
            .descriptors = descriptors,
        };
    }
};

pub fn getMemoryMap(memmap: *MemoryMap) !void {
    var status = efi.bs.getMemoryMap(&memmap.mem_size, memmap.descriptors, &memmap.map_key, &memmap.descriptor_size, &memmap.descriptor_version);
    memmap.descriptor_count = memmap.mem_size / memmap.descriptor_size;

    logger.log(.Debug, "getMemoryMap: status={d}\r\n", .{status});
    logger.log(.Debug, "MemoryMap:\r\n", .{});
    logger.log(.Debug, "  mem_size=0x{x}\r\n", .{memmap.mem_size});
    logger.log(.Debug, "  map_key=0x{x}\r\n", .{memmap.map_key});
    logger.log(.Debug, "  descriptor_size=0x{x}\r\n", .{memmap.descriptor_size});
    logger.log(.Debug, "  descriptor_version=0x{x}\r\n", .{memmap.descriptor_version});
    logger.log(.Debug, "  descriptor_count={d}\r\n", .{memmap.descriptor_count});

    return status.err();
}
