const BootInfo = @import("efi.zig").BootInfo;
const util = @import("util.zig");
const graphics = @import("graphics.zig");
const font = @import("font.zig");
const console = @import("console.zig");
const logger = @import("logger.zig");
const pci = @import("pci.zig");
const xhci = @import("driver/xhci.zig");

export fn kernel_main(boot_info: *BootInfo) void {
    const frame_buffer_config = boot_info.frame_buffer_config;
    const pixel_writer = graphics.PixelWriter.init(frame_buffer_config);
    pixel_writer.clearScreen();
    var con = console.Console.init(&pixel_writer);
    logger.init(con, .Info);
    logger.log(.Info, "start kernel\n", .{});

    pci.init();
    logger.log(.Info, "initialized pci\n", .{});

    var xhc: xhci.Controller = undefined;
    var device_iter = pci.DeviceIterator.init();
    while (device_iter.next()) |device| {
        logger.log(.Info, "pci device: {x} {x} {x} {}\n", .{ device.bus, device.device, device.function, device.class_code });
        if (device.class_code.is_xhci()) {
            const bar = device.bar64(0);
            xhc = xhci.Controller.init(bar);
            logger.log(.Info, "initialized xhci controller: bar=0x{x}\n", .{bar});
        }
    }

    logger.log(.Info, "start xhc\n", .{});
    xhc.start();
    logger.log(.Info, "started xhc\n", .{});

    {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);
        var i: usize = 1;
        while (i < xhc.getMaxPorts()) : (i += 1) {
            var port = xhc.getPort(@truncate(u8, i));
            logger.log(.Debug, "port{d}: connected={}\n", .{ i, port.isConnected() });
            if (port.isConnected()) {}
        }
    }

    logger.log(.Info, "halt", .{});
    util.halt();
}

test "kernel test" {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
}
