const buf_size = 4 * 1024;
var buffer: [buf_size]u8 = [_]u8{0} ** buf_size;

var current: usize = 0;

pub fn alloc(size: usize) [*]u8 {
    if (buf_size - current < size) {
        @panic("FixedBufferAllocator: out of memory");
    }
    var p = @ptrCast([*]u8, &buffer[current]);
    current += size;
    return p;
}

const testing = @import("std").testing;
test "alloc" {
    var b1 = alloc(4);
    var b2 = alloc(8);
    var b3 = alloc(4);
    try testing.expect(@ptrToInt(b1) + 4 == @ptrToInt(b2));
    try testing.expect(@ptrToInt(b1) + 12 == @ptrToInt(b3));
    try testing.expect(@ptrToInt(b2) + 8 == @ptrToInt(b3));
}
