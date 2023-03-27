const uefi = @import("std").os.uefi;
const efi = @import("efi.zig");
const logger = @import("logger.zig");
const MemoryDescriptor = uefi.tables.MemoryDescriptor;
const BootServicesData = uefi.tables.MemoryType.BootServicesData;

pub const MemoryMap = struct {
    mem_size: usize = undefined,
    descriptors: [*]MemoryDescriptor = undefined,
    map_key: usize = undefined,
    descriptor_size: usize = undefined,
    descriptor_version: u32 = undefined,
    descriptor_count: usize = undefined,

    const Self = @This();

    pub fn init() !MemoryMap {
        var mmap = MemoryMap{};
        while (uefi.Status.BufferTooSmall == efi.bs.getMemoryMap(
            &mmap.mem_size,
            mmap.descriptors,
            &mmap.map_key,
            &mmap.descriptor_size,
            &mmap.descriptor_version,
        )) {
            const status = efi.bs.allocatePool(BootServicesData, mmap.mem_size, @ptrCast(*[*]align(8) u8, &mmap.descriptors));
            try status.err();
        }
        mmap.descriptor_count = mmap.mem_size / mmap.descriptor_size;
        return mmap;
    }

    pub fn at(self: Self, i: usize) *MemoryDescriptor {
        return @intToPtr(*MemoryDescriptor, @ptrToInt(self.descriptors) + (i * self.descriptor_size));
    }

    pub fn isAvailable(descriptor: *MemoryDescriptor) bool {
        return switch (descriptor.type) {
            .BootServicesCode => true,
            .BootServicesData => true,
            .ConventionalMemory => true,
            else => false,
        };
    }
};
