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
    {
        var pos: usize = 0;
        var x: usize = 100;
        const y: usize = 100;
        var dx: usize = 0;
        while (pos < words.len) : (pos += 1) {
            const word = words[pos];
            while (dx < 8) : (dx += 1) {
                var dy: usize = 0;
                while (dy < 10) : (dy += 1) {
                    const c = word[dy][dx];
                    if (c == 0) continue;
                    var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * (y + dy) + (x + dx))]);
                    p[0] = 0;
                    p[1] = 0;
                    p[2] = 0;
                }
                dy = 0;
            }
            dx = 0;
            x += 8;
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

const Word = [10][8]u8;
const words = [_]Word{
    word_h,
    word_l,
    word_l,
    word_e,
    word_o,
};
const word_h = Word{
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
};

const word_l = Word{
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
};

const word_e = Word{
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
};

const word_o = Word{
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u8{ 0, 1, 1, 1, 1, 1, 1, 0 },
};
