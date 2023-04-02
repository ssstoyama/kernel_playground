const std = @import("std");
const uefi = @import("std").os.uefi;

export fn kernel_main(boot_info: *BootInfo) void {
    var frame_buffer_config = boot_info.frame_buffer_config;
    {
        var x: usize = 0;
        while (x < 150) : (x += 1) {
            var y: usize = 0;
            while (y < 150) : (y += 1) {
                var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * y + x)]);
                p[0] = 0;
                p[1] = 0;
                p[2] = 255;
            }
        }
    }
    halt();
}

fn halt() void {
    while (true) asm volatile ("hlt");
}

const BootInfo = extern struct {
    frame_buffer_config: *FrameBufferConfig,
};

const FrameBufferConfig = struct {
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
