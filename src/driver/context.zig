pub const DeviceContext = struct {
    slot_context: SlotContext,
    endpoint_context: [31]EndpointContext align(1),
};

pub const SlotContext = packed struct {
    // Offset 00h
    route_string: u20,
    speed: u4,
    rsvd1: u1 = 0,
    mtt: u1,
    hub: u1,
    context_entries: u5,
    // Offset 04h
    max_exit_latency: u16,
    root_hub_port_number: u8,
    number_of_ports: u8,
    // Offset 08h
    parent_hub_slot_id: u8,
    parent_port_number: u8,
    ttt: u2,
    rsvd2: u4 = 0,
    interrupter_target: u10,
    // Offset 0Ch
    usb_device_address: u8,
    rsvd3: u19 = 0,
    slot_state: u5,
    // Offset 10h
    rsvdo1: u32 = 0,
    // Offset 14h
    rsvdo2: u32 = 0,
    // Offset 18h
    rsvdo3: u32 = 0,
    // Offset 1Ch
    rsvdo4: u32 = 0,
};

pub const EndpointContext = packed struct {
    // Offset 00h
    ep_state: u3,
    rsvd1: u5 = 0,
    mult: u2,
    max_primary_streams: u5,
    lsa: u1,
    interval: u8,
    max_esit_payload_hi: u8,
    // Offset 04h
    rsvd2: u1 = 0,
    cerr: u2,
    ep_type: u3,
    rsvd3: u1 = 0,
    hid: u1,
    max_burst_size: u8,
    max_packet_size: u16,
    // Offset 08h
    dcs: u1,
    rsvd4: u3 = 0,
    tr_dequeue_pointer: u60,
    // Offset 10h
    average_trb_length: u16,
    max_esit_payload_lo: u16,
    // Offset 14h
    rsvdo1: u32 = 0,
    // Offset 18h
    rsvdo2: u32 = 0,
    // Offset 1Ch
    rsvdo3: u32 = 0,
};
