const BootInfo = @import("efi.zig").BootInfo;
const util = @import("util.zig");
const graphics = @import("graphics.zig");
const font = @import("font.zig");
const console = @import("console.zig");
const logger = @import("logger.zig");
const pci = @import("pci.zig");

export fn kernel_main(boot_info: *BootInfo) void {
    const frame_buffer_config = boot_info.frame_buffer_config;
    const pixel_writer = graphics.PixelWriter.init(frame_buffer_config);
    pixel_writer.clearScreen();
    var con = console.Console.init(&pixel_writer);
    logger.init(con, .Debug);
    logger.log(.Info, "start kernel\n", .{});

    pci.scanAllBuses();
    logger.log(.Info, "scan all buses\n", .{});

    util.halt();
}

test "kernel test" {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
}
