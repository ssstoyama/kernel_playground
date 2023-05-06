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
    usbcmd: USBCMD,
    usbsts: USBSTS,
    pagesize: u32,
    rsvd1: u64,
    dnctrl: u32,
    crcr: u16,
    rsvd2: u40,
    dcbaap: u64,
    config: u32,
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

const PortRegisterSet = struct {
    portsc: u32,
    portpmsc: u32,
    portli: u32,
    porthlpmc: u32,
};
