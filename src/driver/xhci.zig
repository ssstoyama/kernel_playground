const std = @import("std");
const pci = @import("../pci.zig");
const logger = @import("../logger.zig");
const registers = @import("./registers.zig");
const context = @import("./context.zig");
const trb = @import("./trb.zig");
const ring = @import("./ring.zig");

var device_context_base_address_array: [256]*context.DeviceContext align(64) = [_]*context.DeviceContext{undefined} ** 256;
var command_ring_buf: [32]trb.TRB align(64) = [_]trb.TRB{undefined} ** 32;
var event_ring_segment_1: [32]trb.TRB align(64) = [_]trb.TRB{undefined} ** 32;
var event_ring_segment_table: [1]ring.EventRingSegmentTableEntry = [_]ring.EventRingSegmentTableEntry{undefined} ** 1;

pub const Controller = struct {
    capability: *const registers.Capability,
    operational: *registers.Operational,
    runtime: *registers.Runtime,
    doorbell: *registers.Doorbell,

    command_ring: ring.TRBRing = undefined,

    const Self = @This();

    pub fn init(xhc_bar: u64) Self {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);

        const cap_reg = @intToPtr(*const registers.Capability, xhc_bar);
        logger.log(.Debug, "XHC Capability Registers: caplength=0x{x}\n", .{cap_reg.caplength});

        const op_reg = @intToPtr(*registers.Operational, xhc_bar + cap_reg.caplength);
        logger.log(.Debug, "XHC Operational Registers: usbsts.hth=0x{x}, usbcmd.hcrst=0x{x}\n", .{ op_reg.usbsts.hch, op_reg.usbcmd.hcrst });

        const run_reg = @intToPtr(*registers.Runtime, xhc_bar + cap_reg.rtsoff);
        logger.log(.Debug, "XHC Runtime Register: {*}\n", .{run_reg});

        const door_reg = @intToPtr(*registers.Doorbell, xhc_bar + cap_reg.dboff);
        logger.log(.Debug, "XHC Doorbell Register: {*}\n", .{door_reg});

        return Self{
            .capability = cap_reg,
            .operational = op_reg,
            .runtime = run_reg,
            .doorbell = door_reg,
        };
    }

    pub fn start(self: *Self) void {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);

        self.reset();

        // Device Context 設定
        logger.log(.Debug, "hcsparams1.max_slots = 0x{x}\n", .{self.capability.hcsparams1.max_slots});
        self.operational.dcbaap = @ptrToInt(&device_context_base_address_array);
        logger.log(.Debug, "dcbaap = {*}\n", .{&device_context_base_address_array});

        // Command Ring 設定
        self.command_ring = ring.TRBRing.init(&command_ring_buf, command_ring_buf.len);
        logger.log(.Debug, "comaind_ring.pointer = 0x{x}, buf = {*}\n", .{ self.command_ring.pointer(), &command_ring_buf });
        self.operational.setCRCR(self.command_ring.pointer());
        logger.log(.Debug, "operational.crcr.cycle_state = {d}, pointer = 0x{x}\n", .{ self.operational.crcr.ring_cycle_state, self.operational.crcr.pointer() });

        // Event Ring 設定
        event_ring_segment_table[0] = ring.EventRingSegmentTableEntry{
            .ring_segment_base_address = ring.calcEventRingSegmentAddress(&event_ring_segment_1, 32),
            .ring_segment_size = 32,
        };
    }

    fn reset(self: *Self) void {
        self.operational.usbcmd.hcrst = 1;
        logger.log(.Debug, "usbcmd.hcrst = 1\n", .{});
        while (self.operational.usbcmd.hcrst != 0) {}
        logger.log(.Debug, "usbcmd.hcrst = 0\n", .{});
        while (self.operational.usbsts.cnr != 0) {}
        logger.log(.Debug, "usbsts.cnr = 0\n", .{});
    }
};
