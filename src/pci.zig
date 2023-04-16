const std = @import("std");
const logger = @import("logger.zig");

const BusNum = u8;
const DeviceNum = u5;
const FuncNum = u3;

const ConfigSpaceAddress = packed struct {
    offset: u8 = 0,
    function: FuncNum = 0,
    device: DeviceNum = 0,
    bus: BusNum = 0,
    reserved: u7 = 0,
    enable: u1 = 0,

    pub fn init(bus: BusNum, device: DeviceNum, function: FuncNum, offset: u8) ConfigSpaceAddress {
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

const ClassCode = struct {
    class: u8,
    sub: u8,
    progIF: u8,

    const Self = @This();

    pub fn isPCI2PCI(self: Self) bool {
        return self.class == 0x6 and self.sub == 0x4;
    }
};

const ConfigAddress: u12 = 0xcf8;
const ConfigData: u12 = 0xcfc;

pub fn scanAllBuses() void {
    const header_type = readHeaderType(0, 0, 0);
    if (!isMultiFunction(header_type)) {
        logger.log(.Info, "is single function device\n", .{});
        scanBus(0);
        return;
    }
    logger.log(.Debug, "is multi function device: bus=0x{x}, device=0x{x}, function=0x{x}\n", .{ 0, 0, 0 });
    var function: usize = 0;
    while (function < 8) : (function += 1) {
        if (readVendorID(0, 0, @intCast(FuncNum, function)) == 0xffff) continue;
        scanBus(@truncate(BusNum, function));
    }
}

fn scanBus(bus: BusNum) void {
    var device: DeviceNum = 0;
    while (device < 32) : (device += 1) {
        scanDevice(bus, device);
    }
}

fn scanDevice(bus: BusNum, device: DeviceNum) void {
    const vendorID = readVendorID(bus, device, 0);
    if (vendorID == 0xffff) {
        return;
    }
    logger.log(.Debug, "vendor id: 0x{x}\n", .{vendorID});
    scanFunction(bus, device, 0);
    const header_type = readHeaderType(bus, device, 0);
    logger.log(.Debug, "header type: 0x{x}\n", .{header_type});
    if (isMultiFunction(header_type)) {
        logger.log(.Debug, "is multi function device: bus=0x{x}, device=0x{x}, function=0x{x}\n", .{ bus, device, 0 });
        var function: usize = 1;
        while (function < 8) : (function += 1) {
            if (readVendorID(bus, device, @intCast(FuncNum, function)) == 0xffff) continue;
            logger.log(.Debug, "vendor id: 0x{x}\n", .{readVendorID(bus, device, @intCast(FuncNum, function))});
            scanFunction(bus, device, @intCast(FuncNum, function));
        }
    }
}

fn scanFunction(bus: BusNum, device: DeviceNum, function: FuncNum) void {
    const class_code = readClassCode(bus, device, function);
    logger.log(.Info, "class code={}\n", .{class_code});
    if (!class_code.isPCI2PCI()) return;
    const secondary = readSecondaryBus(bus, device, function);
    logger.log(.Debug, "secondary bus: 0x{x}\n", .{secondary});
    scanBus(secondary);
}

fn readVendorID(bus: BusNum, device: DeviceNum, function: FuncNum) u16 {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0x0).address();
    writeAddress(addr);
    return @truncate(u16, readData());
}

fn readDeviceID(bus: BusNum, device: DeviceNum, function: FuncNum) u16 {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0x0).address();
    writeAddress(addr);
    return @truncate(u16, readData() >> 16);
}

fn readClassCode(bus: BusNum, device: DeviceNum, function: FuncNum) ClassCode {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0x8).address();
    writeAddress(addr);
    const data = readData();
    return ClassCode{
        .class = @truncate(u8, data >> 24),
        .sub = @truncate(u8, data >> 16),
        .progIF = @truncate(u8, data >> 8),
    };
}

fn readHeaderType(bus: BusNum, device: DeviceNum, function: FuncNum) u8 {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0xc).address();
    writeAddress(addr);
    return @truncate(u8, readData() >> 16);
}

fn readSecondaryBus(bus: BusNum, device: DeviceNum, function: FuncNum) BusNum {
    const addr = ConfigSpaceAddress.init(bus, device, function, 0x18).address();
    writeAddress(addr);
    return @truncate(BusNum, readData() >> 8);
}

fn isMultiFunction(header_type: u8) bool {
    return header_type & 0x80 != 0;
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
