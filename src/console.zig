const std = @import("std");
const graphics = @import("graphics.zig");
const font = @import("font.zig");

pub const Console = struct {
    writer: *const graphics.PixelWriter,
    fg_color: graphics.PixelColor = graphics.PixelColor{ .r = 116, .g = 255, .b = 56 },
    bg_color: graphics.PixelColor = graphics.PixelColor.black(),
    cursor_row: usize = 0,
    cursor_col: usize = 0,
    history: [Rows][Cols]u8 = [_][Console.Cols]u8{[_]u8{0} ** Console.Cols} ** Console.Rows,

    const Self = @This();
    const Rows: usize = 25;
    const Cols: usize = 80;

    pub fn init(writer: *const graphics.PixelWriter) Console {
        var console = Console{
            .writer = writer,
        };
        console.clear();
        return console;
    }

    pub fn put(self: *Self, s: []const u8) void {
        for (s) |c| {
            if (c == '\n') {
                self.newLine();
                continue;
            }
            font.writeAscii(
                self.writer,
                self.cursor_col * font.FontWidth,
                self.cursor_row * font.FontHeight,
                c,
                self.fg_color,
            );
            self.history[self.cursor_row][self.cursor_col] = c;
            self.cursor_col += 1;
        }
    }

    fn newLine(self: *Self) void {
        self.cursor_col = 0;
        if (self.cursor_row < Rows - 1) {
            self.cursor_row += 1;
            return;
        }
        self.clear();
        {
            var row: usize = 0;
            while (row < Rows - 1) : (row += 1) {
                std.mem.copy(u8, &self.history[row], &self.history[row + 1]);
                font.writeString(
                    self.writer,
                    0,
                    row * font.FontHeight,
                    &self.history[row],
                    self.fg_color,
                );
            }
        }
        self.history[Rows - 1] = [_]u8{0} ** Cols;
    }

    fn clear(self: *Self) void {
        var x: usize = 0;
        while (x < Cols * font.FontWidth) : (x += 1) {
            var y: usize = 0;
            while (y < Rows * font.FontHeight) : (y += 1) {
                self.writer.write(x, y, self.bg_color);
            }
        }
    }
};
