pub const TRBType = enum(u6) {
    normal = 1,
    setup_stage = 2,
    data_stage = 3,
    status_stage = 4,
    link = 6,
    no_op = 8,
    enable_slot_command = 10,
    address_device_command = 11,
    configure_endpoint_command = 12,
    no_op_command = 23,
    transfer_event = 32,
    command_completion_event = 33,
    port_status_change_event = 34,
};

pub const TRB = union(enum) {
    Normal: NormalTRB,
    Link: LinkTRB,
    NoOp: NoOpTRB,

    pub fn getType(self: TRB) TRBType {
        return switch (self) {
            inline else => |case| case.trb_type,
        };
    }

    pub fn getCycleBit(self: TRB) u1 {
        return switch (self) {
            inline else => |case| case.cycle_bit,
        };
    }

    pub fn setCycleBit(self: *TRB, bit: u1) void {
        switch (self.*) {
            inline else => |*case| case.cycle_bit = bit,
        }
    }
};

pub const NormalTRB = packed struct {
    // Offset 00h
    data_buffer_pointer_lo: u32,
    // Offset 04h
    data_buffer_pointer_hi: u32,
    // Offset 08h
    trb_transfer_length: u17,
    td_size: u5,
    interrupter_target: u10,
    // Offset 0Ch
    cycle_bit: u1,
    evaluate_next_trb: u1,
    interrupt_on_short_packet: u1,
    no_snoop: u1,
    chain_bit: u1,
    interrupt_on_completion: u1,
    immediate_data: u1,
    rsvd1: u2 = 0,
    block_event_interrupt: u1,
    trb_type: TRBType = TRBType.normal,
    rsvd2: u16 = 0,

    const Self = @This();

    pub fn empty() Self {
        return Self{
            .data_buffer_pointer_lo = 0,
            .data_buffer_pointer_hi = 0,
            .trb_transfer_length = 0,
            .td_size = 0,
            .interrupter_target = 0,
            .cycle_bit = 0,
            .evaluate_next_trb = 0,
            .interrupt_on_short_packet = 0,
            .no_snoop = 0,
            .chain_bit = 0,
            .interrupt_on_completion = 0,
            .immediate_data = 0,
            .block_event_interrupt = 0,
        };
    }

    pub fn trb(self: NormalTRB) TRB {
        return TRB{ .Normal = self };
    }
};

pub const LinkTRB = packed struct {
    // Offset 00h
    rsvd1: u4 = 0,
    ring_segment_pointer_lo: u28,
    // Offset 04h
    ring_segment_pointer_hi: u32,
    // Offset 08h
    rsvd2: u22 = 0,
    interrupter_target: u10,
    // Offset 0Ch
    cycle_bit: u1,
    toggle_cycle: u1,
    rsvd3: u2 = 0,
    chain_bit: u1,
    interrupt_on_completion: u1,
    rsvd4: u4 = 0,
    trb_type: TRBType = TRBType.link,
    rsvd5: u16 = 0,

    const Self = @This();

    pub fn init(toggle_cycle: u1) Self {
        return .{
            .ring_segment_pointer_lo = 0,
            .ring_segment_pointer_hi = 0,
            .interrupter_target = 0,
            .cycle_bit = 0,
            .toggle_cycle = toggle_cycle,
            .chain_bit = 0,
            .interrupt_on_completion = 0,
        };
    }

    pub fn trb(self: Self) TRB {
        return TRB{ .Link = self };
    }
};

pub const NoOpTRB = packed struct {
    // Offset 00h
    rsvd1: u32 = 0,
    // Offset 04h
    rsvd2: u32 = 0,
    // Offset 08h
    rsvd3: u22 = 0,
    interrupter_target: u10,
    // Offset 0Ch
    cycle_bit: u1,
    evaluate_next_trb: u1,
    rsvd4: u2 = 0,
    chain_bit: u1,
    interrupt_on_completion: u1,
    rsvd5: u4 = 0,
    trb_type: TRBType = TRBType.no_op,
    rsvd6: u16 = 0,

    const Self = @This();

    pub fn empty() Self {
        return Self{
            .interrupter_target = 0,
            .cycle_bit = 0,
            .evaluate_next_trb = 0,
            .chain_bit = 0,
            .interrupt_on_completion = 0,
        };
    }

    pub fn trb(self: Self) TRB {
        return TRB{ .NoOp = self };
    }
};

const testing = @import("std").testing;
test "TRB" {
    var trb: TRB = undefined;

    trb = TRB{ .Normal = NormalTRB.empty() };
    try testing.expect(trb.getType() == TRBType.normal);

    trb = TRB{ .NoOp = NoOpTRB.empty() };
    try testing.expect(trb.getType() == TRBType.no_op);

    try testing.expect(trb.getCycleBit() == 0);
    trb.setCycleBit(1);
    try testing.expect(trb.getCycleBit() == 1);
}
