const std = @import("std");
const uefi = @import("std").os.uefi;

export fn kernel_main(boot_info: *BootInfo) void {
    var frame_buffer_config = boot_info.frame_buffer_config;
    {
        var x: usize = 0;
        while (x < frame_buffer_config.horizontal_resolution) : (x += 1) {
            var y: usize = 0;
            while (y < frame_buffer_config.vertical_resolution) : (y += 1) {
                var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * y + x)]);
                p[0] = 255;
                p[1] = 255;
                p[2] = 255;
            }
        }
    }
    {
        var x: usize = 0;
        const y: usize = 0;
        for (words) |word| {
            for (word, 0..) |r, dy| {
                for (r, 0..) |c, dx| {
                    if (c == 0) continue;
                    var p = @ptrCast([*]u8, &frame_buffer_config.frame_buffer[4 * (frame_buffer_config.pixels_per_scan_line * (y + dy) + (x + dx))]);
                    p[0] = 0;
                    p[1] = 0;
                    p[2] = 0;
                }
            }
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

const Word = [10][8]u1;
const words = [_]Word{
    word_h,
    word_l,
    word_l,
    word_e,
    word_o,
    word_space,
    word_w,
    word_o,
    word_r,
    word_l,
    word_d,
    word_exclamation,
};

const word_h = Word{
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
};

const word_l = Word{
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
};

const word_e = Word{
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
};

const word_o = Word{
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
};

const word_space = Word{
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

const word_w = Word{
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 1, 1, 0, 1, 1, 0, 1, 1 },
    [8]u1{ 0, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 0, 1, 1, 0, 0, 1, 1, 0 },
};

const word_r = Word{
    [8]u1{ 1, 1, 1, 1, 1, 0, 0, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 1, 0, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 1, 0, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
};

const word_d = Word{
    [8]u1{ 1, 1, 1, 1, 1, 0, 0, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 1, 0, 0 },
    [8]u1{ 1, 1, 0, 0, 1, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 0, 1, 1, 0 },
    [8]u1{ 1, 1, 0, 0, 1, 1, 1, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 1, 0, 0 },
    [8]u1{ 1, 1, 1, 1, 1, 0, 0, 0 },
};

const word_exclamation = Word{
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 0, 0, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
    [8]u1{ 0, 0, 0, 1, 1, 0, 0, 0 },
};
