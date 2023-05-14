const registers = @import("registers.zig");
const logger = @import("../logger.zig");

pub const Port = struct {
    number: u8,
    port: *registers.PortRegisterSet,
    phase: ConfigPhase = .not_connected,

    const Self = @This();

    pub fn init(number: u8, port: *registers.PortRegisterSet) Self {
        return Self{
            .number = number,
            .port = port,
        };
    }

    pub fn isConnected(self: Self) bool {
        return self.port.portsc.current_connect_status == 1;
    }

    pub fn reset(self: *Self) void {
        if (!self.isConnected()) return;
        if (self.phase != .not_connected or self.phase != .waiting_addressed) return;
        self.phase = .resetting_port;

        if (self.port.portsc.current_connect_status != 1 and self.port.connect_status_change != 1) return;
        self.port.portsc.port_reset = 1;
        self.port.portsc.connect_status_change = 1;
        while (self.port.portsc.port_reset == 0) {}
    }
};

const ConfigPhase = enum {
    not_connected,
    waiting_addressed,
    resetting_port,
    enabling_slot,
    addressing_device,
    initializing_device,
    configuring_endpoints,
    configured,
};
