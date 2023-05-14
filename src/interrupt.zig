const x86 = @import("x86.zig");

const InterruptDescriptorTable = [256]InterruptDescriptor;
var idt: InterruptDescriptorTable = [_]InterruptDescriptor{undefined} ** 256;

pub const InterruptVector = enum(u8) {
    general_protection_fault = 0x0d,
    xhci = 0x40,

    pub fn value(self: InterruptVector) u8 {
        return @enumToInt(self);
    }
};

pub const InterruptDescriptor = packed struct {
    offset_low: u16,
    segment_selector: u16,
    attr: InterruptDescriptorAttribute,
    offset_middle: u16,
    offset_high: u32,
    reserved: u32 = 0,
};

pub const InterruptDescriptorAttribute = packed struct {
    interrupt_stack_table: u3,
    reserved1: u5 = 0,
    descriptor_type: DescriptorType,
    reserved2: u1 = 0,
    descriptor_privilege_level: PrivilegeLevel,
    present: u1,

    pub fn init(descriptor_type: DescriptorType, privilege_level: PrivilegeLevel) InterruptDescriptorAttribute {
        return InterruptDescriptorAttribute{
            .interrupt_stack_table = 0,
            .descriptor_type = descriptor_type,
            .descriptor_privilege_level = privilege_level,
            .present = 1,
        };
    }
};

pub const PrivilegeLevel = enum(u8) {
    ring0 = 0,
    ring1 = 1,
    ring2 = 2,
    ring3 = 3,
};

const DescriptorType = enum(u4) {
    interrupt_gate = 14,
};

pub const InterruptFrame = struct {
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

pub fn setIDTEntry(
    vec: InterruptVector,
    attr: InterruptDescriptorAttribute,
    offset: u64,
) void {
    idt[vec.value()] = InterruptDescriptor{
        .offset_low = @truncate(u16, offset),
        .segment_selector = x86.getCS(),
        .attr = attr,
        .offset_middle = @truncate(u16, offset >> 16),
        .offset_high = @truncate(u32, offset >> 32),
    };
}

pub fn loadIDT() void {
    x86.loadIDT(@sizeOf(InterruptDescriptorTable) - 1, @ptrToInt(&idt));
}
