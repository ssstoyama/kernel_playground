const std = @import("std");
const uefi = std.os.uefi;
const efi = @import("efi.zig");
const logger = @import("logger.zig");

pub fn main() void {
    efi_main() catch unreachable;
}

fn efi_main() !void {
    try efi.init(uefi.system_table);

    logger.log(.Info, "Start boot loader\n", .{});

    while (true) {}
}
