const std = @import("std");
const pci = @import("../pci.zig");
const logger = @import("../logger.zig");
const registers = @import("./registers.zig");
const context = @import("./context.zig");

var device_context_base_address_array: [256]*context.DeviceContext align(64) = [_]*context.DeviceContext{undefined} ** 256;

pub const Controller = struct {
    capability: *const registers.Capability,
    operational: *registers.Operational,

    const Self = @This();

    pub fn init(xhc_bar: u64) Self {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);

        const cap_reg = @intToPtr(*const registers.Capability, xhc_bar);
        logger.log(.Debug, "XHC Capability Registers: caplength=0x{x}\n", .{cap_reg.caplength});

        const op_reg = @intToPtr(*registers.Operational, xhc_bar + cap_reg.caplength);
        logger.log(.Debug, "XHC Operational Registers: usbsts.hth=0x{x}, usbcmd.hcrst=0x{x}\n", .{ op_reg.usbsts.hch, op_reg.usbcmd.hcrst });

        return Self{
            .capability = cap_reg,
            .operational = op_reg,
        };
    }

    pub fn start(self: *Self) void {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);

        self.reset();

        logger.log(.Debug, "hcsparams1.max_slots = 0x{x}\n", .{self.capability.hcsparams1.max_slots});
        logger.log(.Debug, "dcbaap = {*}\n", .{&device_context_base_address_array});
        self.operational.dcbaap = @ptrToInt(&device_context_base_address_array);
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
