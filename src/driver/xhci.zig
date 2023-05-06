const std = @import("std");
const pci = @import("../pci.zig");
const logger = @import("../logger.zig");
const registers = @import("./registers.zig");
const buffer = @import("./buffer.zig");

pub const Controller = struct {
    capability: *const registers.Capability,
    operational: *registers.Operational,

    pub fn init(xhc_bar: u64) Controller {
        logger.changeLevel(.Debug);
        defer logger.changeLevel(.Info);

        const cap_reg = @intToPtr(*const registers.Capability, xhc_bar);
        logger.log(.Debug, "XHC Capability Registers: caplength=0x{x}\n", .{cap_reg.caplength});

        const op_reg = @intToPtr(*registers.Operational, xhc_bar + cap_reg.caplength);
        logger.log(.Debug, "XHC Operational Registers: usbsts.hth=0x{x}, usbcmd.hcrst=0x{x}\n", .{ op_reg.usbsts.hch, op_reg.usbcmd.hcrst });
        Controller.reset(op_reg);

        logger.log(.Debug, "hcsparams1.max_slots = 0x{x}\n", .{cap_reg.hcsparams1.max_slots});
        var dev_ctx_array = buffer.alloc(cap_reg.hcsparams1.max_slots);
        logger.log(.Debug, "dcbaap = {*}\n", .{dev_ctx_array});
        op_reg.dcbaap = @ptrToInt(dev_ctx_array);

        return Controller{
            .capability = cap_reg,
            .operational = op_reg,
        };
    }

    fn reset(op_reg: *registers.Operational) void {
        op_reg.usbcmd.hcrst = 1;
        logger.log(.Debug, "usbcmd.hcrst = 1\n", .{});
        while (op_reg.usbcmd.hcrst != 0) {}
        logger.log(.Debug, "usbcmd.hcrst = 0\n", .{});
        while (op_reg.usbsts.cnr != 0) {}
        logger.log(.Debug, "usbsts.cnr = 0\n", .{});
    }
};
