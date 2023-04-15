const std = @import("std");
const logger = @import("logger.zig");

const Bus = u8;
const Device = u5;
const Function = u3;
const ConfigSpaceAddress = packed struct {
    offset: u8 = 0,
    function: Function = 0,
    device: Device = 0,
    bus: Bus = 0,
    reserved: u7 = 0,
    enable: u1 = 0,

    pub fn init(bus: Bus, device: Device, function: Function, offset: u8) ConfigSpaceAddress {
        return ConfigSpaceAddress{
            .offset = offset & 0xfc,
            .function = function,
            .device = device,
            .bus = bus,
            .reserved = 0,
            .enable = 1,
        };
    }

    pub fn address(self: ConfigSpaceAddress) u32 {
        return @bitCast(u32, self);
    }
};
const ConfigAddress: u12 = 0xcf8;
const ConfigData: u12 = 0xcfc;

pub fn scanAllBuses() void {
    var bus: usize = 0;
    while (bus < 256) : (bus += 1) {
        var device: usize = 0;
        while (device < 32) : (device += 1) {
            scanDevice(@intCast(Bus, bus), @intCast(Device, device));
        }
    }
}

fn scanDevice(bus: Bus, device: Device) void {
    var function: Function = 0;

    const vendorID = readVendorID(bus, device, function);
    if (vendorID == 0xffff) {
        return;
    }
    logger.log(.Debug, "Vendor ID: 0x{x}\n", .{vendorID});
}

fn readVendorID(bus: Bus, device: Device, function: Function) u16 {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0).address();
    writeAddress(addr);
    return @truncate(u16, readData());
}

fn writeAddress(addr: u32) void {
    ioOut32(ConfigAddress, addr);
}

fn writeData(data: u32) void {
    ioOut32(ConfigData, data);
}

fn readData() u32 {
    return ioIn32(ConfigData);
}

fn ioIn32(addr: u16) u32 {
    return asm volatile (
        \\ inl %dx, %eax
        : [ret] "={eax}" (-> u32),
        : [addr] "{dx}" (addr),
    );
}

fn ioOut32(addr: u16, data: u32) void {
    asm volatile (
        \\ outl %eax, %dx
        :
        : [addr] "{dx}" (addr),
          [data] "{eax}" (data),
    );
}

const testing = std.testing;
test "ConfigSpaceAddress" {
    const addr = ConfigSpaceAddress.init(1, 2, 4, 7);
    try testing.expect(0b1000_0000_0000_0001_0001_0100_0000_0100 == addr.address());
}
