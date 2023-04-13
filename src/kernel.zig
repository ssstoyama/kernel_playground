const BootInfo = @import("efi.zig").BootInfo;
const util = @import("util.zig");
const graphics = @import("graphics.zig");
const font = @import("font.zig");
const console = @import("console.zig");

export fn kernel_main(boot_info: *BootInfo) void {
    const frame_buffer_config = boot_info.frame_buffer_config;
    const pixel_writer = graphics.PixelWriter.init(frame_buffer_config);
    pixel_writer.clearScreen();

    var con = console.Console.init(&pixel_writer);

    con.put("Hello World!\nWelcome to ZigOS!\n");

    util.halt();
}
