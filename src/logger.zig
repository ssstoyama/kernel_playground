const std = @import("std");
const Console = @import("console.zig").Console;

var console: Console = undefined;

var log_level: LogLevel = undefined;

pub const LogLevel = enum(u8) {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
};

pub fn init(con: Console, level: LogLevel) void {
    console = con;
    log_level = level;
}

pub fn log(level: LogLevel, comptime fmt: []const u8, args: anytype) void {
    if (@enumToInt(log_level) > @enumToInt(level)) return;
    var buf: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    console.put(text);
}

pub fn changeLevel(level: LogLevel) void {
    log_level = level;
}
