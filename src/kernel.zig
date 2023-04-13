const BootInfo = @import("efi.zig").BootInfo;
const util = @import("util.zig");
const graphics = @import("graphics.zig");
const font = @import("font.zig");

export fn kernel_main(boot_info: *BootInfo) void {
    const frame_buffer_config = boot_info.frame_buffer_config;
    const pixel_writer = graphics.PixelWriter.init(frame_buffer_config);

    {
        var x: usize = 0;
        while (x < 100) : (x += 1) {
            var y: usize = 0;
            while (y < 100) : (y += 1) {
                pixel_writer.write(x, y, graphics.PixelColor{ .r = 255, .b = 255 });
            }
        }
    }

    font.writeString(pixel_writer, 100, 100, "Hello World\n", graphics.PixelColor.white());

    util.halt();
}
