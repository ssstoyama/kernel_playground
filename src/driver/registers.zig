const std = @import("std");
const logger = @import("../logger.zig");

pub const Capability = packed struct {
    caplength: u8,
    rsvd: u8 = 0,
    hciversion: u16,
    hcsparams1: HCSPARAMS1,
    hcsparams2: u32,
    hcsparams3: u32,
    hccparams1: u32,
    dboff: u32,
    rtsoff: u32,
    hccparams2: u32,
    // rsvd = cap_length - 20h
};

const HCSPARAMS1 = packed struct {
    max_slots: u8,
    max_intrs: u11,
    rsvd1: u5 = 0,
    max_ports: u8,
};

pub const Operational = packed struct {
    // Offset 00h
    usbcmd: USBCMD,
    // Offset 04h
    usbsts: USBSTS,
    // Offset 08h
    pagesize: u32,
    rsvd1: u64,
    // Offset 14h
    dnctrl: u32,
    // Offset 18h
    crcr: CRCR,
    rsvdz1: u64,
    rsvdz2: u64,
    // Offset 30h
    dcbaap: u64,
    // Offset 38h
    config: u32,

    pub fn setCRCR(self: *Operational, ptr: u64) void {
        self.crcr = CRCR{
            .ring_cycle_state = @truncate(u1, ptr),
            .command_stop = @truncate(u1, ptr >> 1),
            .command_abort = @truncate(u1, ptr >> 2),
            .command_ring_running = @truncate(u1, ptr >> 3),
            .command_ring_pointer = @truncate(u58, ptr >> 5),
        };
    }

    pub fn getPortRegisterSet(self: *Operational) [*]PortRegisterSet {
        return @intToPtr([*]PortRegisterSet, @ptrToInt(self) + 0x400);
    }
};

const USBCMD = packed struct {
    rs: u1,
    hcrst: u1,
    inte: u1,
    hsee: u1,
    rsvd1: u3 = 0,
    lhcrst: u1,
    css: u1,
    crs: u1,
    ewe: u1,
    eu3s: u1,
    rsvd2: u1 = 0,
    cme: u1,
    ete: u1,
    tscen: u1,
    vtioen: u1,
    rsvd3: u15 = 0,
};

const USBSTS = packed struct {
    hch: u1,
    rsvd: u1 = 0,
    hse: u1,
    ent: u1,
    pcd: u1,
    rsvd1: u3 = 0,
    sss: u1,
    rss: u1,
    sre: u1,
    cnr: u1,
    hce: u1,
    rsvd2: u19 = 0,
};

const CRCR = packed struct {
    ring_cycle_state: u1,
    command_stop: u1,
    command_abort: u1,
    command_ring_running: u1,
    rsvd1: u2 = 0,
    command_ring_pointer: u58,

    pub fn pointer(self: CRCR) u64 {
        return self.command_ring_pointer << 5;
    }
};

pub const PortRegisterSet = packed struct {
    portsc: PORTSC,
    portpmsc: u32,
    portli: u32,
    porthlpmc: u32,
};

const PORTSC = packed struct {
    current_connect_status: u1,
    port_enabled_disabled: u1,
    rsvd1: u1 = 0,
    over_current_active: u1,
    port_reset: u1,
    port_link_state: u4,
    port_power: u1,
    port_speed: u4,
    port_indictor_control: u2,
    port_link_state_write_strobe: u1,
    connect_status_change: u1,
    port_enabeld_disabled_change: u1,
    warm_port_reset_change: u1,
    over_current_change: u1,
    port_reset_change: u1,
    port_link_state_change: u1,
    port_config_error_change: u1,
    cold_attach_status: u1,
    wake_on_connect_enable: u1,
    wake_on_disconnect_enable: u1,
    wake_on_over_current_enable: u1,
    rsvd2: u2 = 0,
    device_removable: u1,
    warm_port_reset: u1,
};

pub const Runtime = packed struct {
    MFINDEX: MFINDEX,

    pub fn getInterrupterRegisterSet(self: *Runtime) [*]InterrupterRegisterSet {
        return @intToPtr([*]InterrupterRegisterSet, @ptrToInt(self) + 0x20);
    }
};

const MFINDEX = packed struct {
    microframe_index: u14,
    rsvd: u18 = 0,
};

pub const InterrupterRegisterSet = packed struct {
    iman: IMAN,
    imod: IMOD,
    erstsz: u32,
    rsvd1: u32 = 0,
    erstba: ERSTBA,
    erdp: ERDP,
};

const IMAN = packed struct {
    interrupt_pending: u1,
    interrupt_enable: u1,
    rsvd: u30 = 0,
};

const IMOD = packed struct {
    interrupt_moderation_interval: u16,
    interrupt_moderation_counter: u16,
};

const ERSTBA = packed struct {
    event_ring_segment_table_base_address_register: u64,
};

const ERDP = packed struct {
    dequeue_erst_segment_index: u3,
    event_handler_busy: u1,
    event_ring_dequeue_pointer: u60,
};

pub const Doorbell = struct {};

const testing = std.testing;
test "Runtime" {
    var runtime: Runtime align(64) = Runtime{
        .MFINDEX = MFINDEX{
            .microframe_index = 0,
        },
    };

    var ptr = runtime.getInterrupterRegisterSet();

    try testing.expect(@ptrToInt(&runtime) + 0x20 == @ptrToInt(ptr));
}
