const uefi = @import("std").os.uefi;
// var global: u8 = undefined;

export fn kernel_main() void {
    halt();
}

fn halt() void {
    while (true) asm volatile ("hlt");
}

const FrameBufferConfig = struct {
    frame_buffer: [*]u8,
    pixels_per_scan_line: u32,
    horizontal_resolution: u32,
    vertical_resolution: u32,
    pixel_format: PixelFormat,
};

pub const PixelFormat = enum(u8) {
    PixelRGBResv8BitPerColor = 1,
    PixelBGRResv8BitPerColor = 2,
};
