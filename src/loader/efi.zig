const std = @import("std");
const uefi = @import("std").os.uefi;
const mem = @import("mem.zig");
const logger = @import("logger.zig");

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;
pub var bs: *uefi.tables.BootServices = undefined;
pub var fs: *uefi.protocols.SimpleFileSystemProtocol = undefined;
pub var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;

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

pub fn init(system_table: *uefi.tables.SystemTable) !void {
    con_out = system_table.con_out orelse return uefi.Status.Unsupported.err();
    bs = system_table.boot_services orelse return uefi.Status.Unsupported.err();

    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    try bs.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*anyopaque, &simple_file_system)).err();
    fs = simple_file_system.?;

    var graphics_output_protocol: ?*uefi.protocols.GraphicsOutputProtocol = undefined;
    try bs.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @ptrCast(*?*anyopaque, &graphics_output_protocol)).err();
    gop = graphics_output_protocol.?;
}

pub fn startKernel(entry_point: u64, boot_info: *BootInfo) void {
    asm volatile (
        \\ callq *%rax
        :
        : [entry_point] "{rax}" (entry_point),
          [boot_info] "{rdi}" (boot_info),
    );
}

pub const BootInfo = extern struct {
    frame_buffer_config: *FrameBufferConfig,
};

pub const PixelFormat = enum(u8) {
    PixelRGBResv8BitPerColor = 1,
    PixelBGRResv8BitPerColor = 2,
};

pub const FrameBufferConfig = extern struct {
    frame_buffer: [*]u8,
    pixels_per_scan_line: u32,
    horizontal_resolution: u32,
    vertical_resolution: u32,
    pixel_format: PixelFormat,
};

pub const PixelColor = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn black() PixelColor {
        return PixelColor{};
    }
    pub fn white() PixelColor {
        return PixelColor{ .r = 255, .g = 255, .b = 255 };
    }
};

pub const PixelWriter = union(enum) {
    rgb: RGBResv8BitPerColorPixelWriter,
    bgr: BGRResv8BitPerColorPixelWriter,

    pub fn init(config: *FrameBufferConfig) PixelWriter {
        return switch (config.pixel_format) {
            .PixelRGBResv8BitPerColor => PixelWriter{ .rgb = RGBResv8BitPerColorPixelWriter.init(config) },
            .PixelBGRResv8BitPerColor => PixelWriter{ .bgr = BGRResv8BitPerColorPixelWriter.init(config) },
        };
    }

    pub fn pixelAt(config: *FrameBufferConfig, x: usize, y: usize) [*]u8 {
        return @ptrCast([*]u8, &config.frame_buffer[4 * (config.pixels_per_scan_line * y + x)]);
    }

    pub fn write(self: PixelWriter, x: usize, y: usize, c: PixelColor) void {
        switch (self) {
            inline else => |case| case.write(x, y, c),
        }
    }
};

const RGBResv8BitPerColorPixelWriter = struct {
    config: *FrameBufferConfig,

    pub fn init(config: *FrameBufferConfig) RGBResv8BitPerColorPixelWriter {
        return RGBResv8BitPerColorPixelWriter{
            .config = config,
        };
    }
    pub fn write(self: RGBResv8BitPerColorPixelWriter, x: usize, y: usize, c: PixelColor) void {
        var p = PixelWriter.pixelAt(self.config, x, y);
        p[0] = c.r;
        p[1] = c.g;
        p[2] = c.b;
    }
};

const BGRResv8BitPerColorPixelWriter = struct {
    config: *FrameBufferConfig,

    pub fn init(config: *FrameBufferConfig) BGRResv8BitPerColorPixelWriter {
        return BGRResv8BitPerColorPixelWriter{
            .config = config,
        };
    }
    pub fn write(self: BGRResv8BitPerColorPixelWriter, x: usize, y: usize, c: PixelColor) void {
        var p = PixelWriter.pixelAt(self.config, x, y);
        p[0] = c.b;
        p[1] = c.g;
        p[2] = c.r;
    }
};

pub fn string(dest: []u16, s: []const u8) void {
    for (s, 0..) |c, i| {
        dest[i] = c;
    }
}

const testing = std.testing;
test "string" {
    const expected = [5]u16{ 'a', 'b', 'c', 'd', 'e' };
    var actual: [5]u16 = undefined;
    string(&actual, "abcde");
    try testing.expect(std.mem.eql(u16, &expected, &actual));
}
