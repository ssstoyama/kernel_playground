const std = @import("std");
const uefi = @import("std").os.uefi;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;
pub var bs: *uefi.tables.BootServices = undefined;
pub var fs: *uefi.protocols.SimpleFileSystemProtocol = undefined;
pub var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;

pub fn init() uefi.Status {
    var status: uefi.Status = undefined;
    const system_table = uefi.system_table;

    con_out = system_table.con_out orelse return .Unsupported;
    bs = system_table.boot_services orelse return .Unsupported;

    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    status = bs.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*anyopaque, &simple_file_system));
    if (status != .Success) return status;
    fs = simple_file_system.?;

    var graphics_output_protocol: ?*uefi.protocols.GraphicsOutputProtocol = undefined;
    status = bs.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @ptrCast(*?*anyopaque, &graphics_output_protocol));
    if (status != .Success) return status;
    gop = graphics_output_protocol.?;

    return .Success;
}

pub fn startKernel(entry_point: u64, boot_info: *BootInfo) void {
    asm volatile (
        \\ callq *%rax
        :
        : [entry_point] "{rax}" (entry_point),
          [boot_info] "{rdi}" (boot_info),
    );
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, format, args) catch unreachable;
    for (text) |c| {
        _ = con_out.outputString(&[_:0]u16{ c, 0 });
    }
}

pub fn tryStatus(status: uefi.Status) !void {
    try status.err();
}

pub const BootInfo = extern struct {
    frame_buffer_config: *const FrameBufferConfig = undefined,
    memory_map: *const MemoryMap = undefined,
};

pub const FrameBufferConfig = extern struct {
    frame_buffer: [*]u8,
    pixels_per_scan_line: u32,
    horizontal_resolution: u32,
    vertical_resolution: u32,
    pixel_format: PixelFormat,
};

pub const PixelFormat = enum(u8) {
    PixelRGBResv8BitPerColor = 1,
    PixelBGRResv8BitPerColor = 2,
};

pub const MemoryMap = struct {
    mem_size: usize = undefined,
    descriptors: [*]uefi.tables.MemoryDescriptor = undefined,
    map_key: usize = undefined,
    descriptor_size: usize = undefined,
    descriptor_version: u32 = undefined,

    const Self = @This();

    pub fn getDescriptor(self: Self, i: usize) *uefi.tables.MemoryDescriptor {
        return @intToPtr(*uefi.tables.MemoryDescriptor, @ptrToInt(self.descriptors) + (i * self.descriptor_size));
    }

    pub fn getDiscriptorCount(self: Self) usize {
        return self.mem_size / self.descriptor_size;
    }

    pub fn isAvailable(descriptor: *uefi.tables.MemoryDescriptor) bool {
        return switch (descriptor.type) {
            .BootServicesCode => true,
            .BootServicesData => true,
            .ConventionalMemory => true,
            else => false,
        };
    }
};
