const std = @import("std");
const uefi = std.os.uefi;
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
    try exitBootServices(mmap.map_key);

    {
        var x: usize = 0;
        while (x < frame_buffer_config.horizontal_resolution) : (x += 1) {
            var y: usize = 0;
            while (y < frame_buffer_config.vertical_resolution) : (y += 1) {
                writer.write(x, y, .{ .r = 45, .g = 118, .b = 237 });
            }
        }
    }

    while (true) {}
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
