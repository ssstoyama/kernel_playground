const BootInfo = @import("efi.zig").BootInfo;
const util = @import("util.zig");
const hello = @import("hello.zig");

export fn kernel_main(boot_info: *BootInfo) void {
    const frame_buffer_config = boot_info.frame_buffer_config;
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

    hello.draw(boot_info.frame_buffer_config, 100, 100);

    util.halt();
}
