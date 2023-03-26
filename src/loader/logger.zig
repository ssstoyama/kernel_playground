const fmt = @import("std").fmt;
const uefi = @import("std").os.uefi;
const efi = @import("efi.zig");

const LogLevel = enum(u8) {
    Debug,
    Info,
    Warn,
    Error,
};

var current_level: LogLevel = LogLevel.Info;

pub fn setLoevel(level: LogLevel) void {
    current_level = level;
}

pub fn log(level: LogLevel, comptime format: []const u8, args: anytype) void {
    if (@enumToInt(current_level) > @enumToInt(level)) return;
    var buf: [1024]u8 = undefined;
    const text = fmt.bufPrint(&buf, format, args) catch unreachable;
    puts(text);
}

fn putc(c: u8) void {
    _ = efi.con_out.outputString(&[2:0]u16{ c, 0 });
}

fn puts(s: []const u8) void {
    for (s) |c| {
        putc(c);
    }
}
