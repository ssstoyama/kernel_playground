const fmt = @import("std").fmt;
const uefi = @import("std").os.uefi;
const efi = @import("efi.zig");

const LogLevel = enum(u8) {
    Debug,
    Info,
    Warn,
    Error,

    pub fn compare(self: LogLevel, other: LogLevel) isize {
        return @enumToInt(self) - @enumToInt(other);
    }
};

var current_level: LogLevel = LogLevel.Info;

pub fn setLoevel(level: LogLevel) void {
    current_level = level;
}

pub fn log(level: LogLevel, comptime format: []const u8, args: anytype) void {
    if (current_level.compare(level) > 0) return;
    var buf: [1024]u8 = undefined;
    const text = fmt.bufPrint(&buf, format, args) catch unreachable;
    if (uefi.Status.Success != puts(text)) unreachable;
}

fn putc(c: u8) uefi.Status {
    return efi.con_out.outputString(&[2:0]u16{ c, 0 });
}

fn puts(s: []const u8) uefi.Status {
    for (s) |c| {
        const status = putc(c);
        if (status != uefi.Status.Success) return status;
    }
    return uefi.Status.Success;
}
