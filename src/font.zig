const graphics = @import("graphics.zig");

extern var _binary_hankaku_bin_start: u8;
extern var _binary_hankaku_bin_end: u8;
extern var _binary_hankaku_bin_size: u8;

fn getFont(c: u8) ?[]u8 {
    const index: usize = 16 * @as(usize, c);
    if (index >= @ptrToInt(&_binary_hankaku_bin_size)) return null;
    var words = @ptrCast([*]u8, &_binary_hankaku_bin_start);
    return words[index .. index + 16];
}

fn writeAscii(writer: graphics.PixelWriter, x: usize, y: usize, c: u8, color: graphics.PixelColor) void {
    const font = getFont(c) orelse return;
    {
        var dy: usize = 0;
        while (dy < 16) : (dy += 1) {
            var dx: u6 = 0;
            while (dx < 8) : (dx += 1) {
                if ((@as(usize, font[dy]) << dx) & 0x80 > 0) {
                    writer.write(x + dx, y + dy, color);
                }
            }
        }
    }
}

pub fn writeString(writer: graphics.PixelWriter, x: usize, y: usize, s: []const u8, color: graphics.PixelColor) void {
    for (s, 0..) |c, i| {
        writeAscii(writer, x + 8 * i, y, c, color);
    }
}
