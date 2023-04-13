const FrameBufferConfig = @import("efi.zig").FrameBufferConfig;
const PixelFormat = @import("efi.zig").PixelFormat;

pub const PixelColor = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn black() PixelColor {
        return PixelColor{ .r = 0, .g = 0, .b = 0 };
    }

    pub fn white() PixelColor {
        return PixelColor{ .r = 255, .g = 255, .b = 255 };
    }
};

pub const PixelWriter = union(enum) {
    RGB: RGBPixelWriter,
    BGR: BGRPixelWriter,

    var fg_color: PixelColor = PixelColor.black();
    var bg_color: PixelColor = PixelColor.white();

    pub fn init(config: *const FrameBufferConfig) PixelWriter {
        switch (config.pixel_format) {
            PixelFormat.PixelRGBResv8BitPerColor => return PixelWriter{ .RGB = RGBPixelWriter{ .config = config } },
            PixelFormat.PixelBGRResv8BitPerColor => return PixelWriter{ .BGR = BGRPixelWriter{ .config = config } },
        }
    }

    pub fn offset(config: *const FrameBufferConfig, x: usize, y: usize) usize {
        return (y * config.pixels_per_scan_line + x) * 4;
    }

    pub fn write(self: PixelWriter, x: usize, y: usize, color: PixelColor) void {
        switch (self) {
            inline else => |case| case.write(x, y, color),
        }
    }

    pub fn clearScreen(self: PixelWriter) void {
        switch (self) {
            inline else => |case| {
                var x: usize = 0;
                while (x < case.config.horizontal_resolution) : (x += 1) {
                    var y: usize = 0;
                    while (y < case.config.vertical_resolution) : (y += 1) {
                        case.write(x, y, bg_color);
                    }
                }
            },
        }
    }
};

const RGBPixelWriter = struct {
    config: *const FrameBufferConfig,

    pub fn write(self: RGBPixelWriter, x: usize, y: usize, color: PixelColor) void {
        const offset = PixelWriter.offset(self.config, x, y);
        self.config.frame_buffer[offset + 0] = color.r;
        self.config.frame_buffer[offset + 1] = color.g;
        self.config.frame_buffer[offset + 2] = color.b;
    }
};

const BGRPixelWriter = struct {
    config: *const FrameBufferConfig,

    pub fn write(self: BGRPixelWriter, x: usize, y: usize, color: PixelColor) void {
        const offset = PixelWriter.offset(self.config, x, y);
        self.config.frame_buffer[offset + 0] = color.b;
        self.config.frame_buffer[offset + 1] = color.g;
        self.config.frame_buffer[offset + 2] = color.r;
    }
};
