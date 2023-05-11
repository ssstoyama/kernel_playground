const std = @import("std");
const trb = @import("./trb.zig");

pub const TRBRing = struct {
    ring: [*]trb.TRB,
    length: usize,
    cycle_state: u1,
    index: usize = 0,

    const Self = @This();

    pub fn init(ring: [*]trb.TRB, length: usize) Self {
        return Self{
            .ring = ring,
            .length = length,
            .cycle_state = 1,
        };
    }

    pub fn push(self: *Self, entry: *trb.TRB) void {
        entry.setCycleBit(self.cycle_state);
        self.ring[self.index] = entry.*;
        self.index += 1;

        if (self.index == self.length - 1) {
            self.ring[self.index] = trb.LinkTRB.init(self.cycle_state).trb();
            self.index = 0;
            self.toggleCycleState();
        }
    }

    pub fn pointer(self: Self) u64 {
        return @ptrToInt(self.ring) | self.cycle_state;
    }

    pub fn getCycleState(self: Self) u1 {
        return self.cycle_state;
    }

    fn toggleCycleState(self: *Self) void {
        self.cycle_state = switch (self.cycle_state) {
            0 => 1,
            1 => 0,
        };
    }
};

const testing = std.testing;
test "TRBRing" {
    var ring: [3]trb.TRB align(64) = [_]trb.TRB{undefined} ** 3;
    var trb_ring = TRBRing.init(&ring, ring.len);

    var trb1 = trb.NoOpTRB.empty().trb();
    var trb2 = trb.NoOpTRB.empty().trb();
    var trb3 = trb.NoOpTRB.empty().trb();
    var trb4 = trb.NoOpTRB.empty().trb();

    trb_ring.push(&trb1);
    try testing.expect(trb1.getCycleBit() == 1);
    try testing.expect(trb_ring.getCycleState() == 1);

    trb_ring.push(&trb2);
    try testing.expect(trb2.getCycleBit() == 1);
    try testing.expect(trb_ring.getCycleState() == 0);

    trb_ring.push(&trb3);
    try testing.expect(trb3.getCycleBit() == 0);
    try testing.expect(trb_ring.getCycleState() == 0);

    trb_ring.push(&trb4);
    try testing.expect(trb4.getCycleBit() == 0);
    try testing.expect(trb_ring.getCycleState() == 1);

    try testing.expect(trb_ring.pointer() == (@ptrToInt(&ring) | 1));
}
