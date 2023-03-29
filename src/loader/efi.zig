const std = @import("std");
const uefi = @import("std").os.uefi;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;
pub var bs: *uefi.tables.BootServices = undefined;
pub var fs: *uefi.protocols.SimpleFileSystemProtocol = undefined;

pub fn init(system_table: *uefi.tables.SystemTable) !void {
    con_out = system_table.con_out orelse return uefi.Status.Unsupported.err();
    bs = system_table.boot_services orelse return uefi.Status.Unsupported.err();

    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    try bs.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*anyopaque, &simple_file_system)).err();
    fs = simple_file_system.?;
}

pub fn string(dest: []u16, s: []const u8) void {
    for (s, 0..) |c, i| {
        dest[i] = c;
    }
}

const testing = std.testing;
test "string" {
    const expected = [5]u16{ 'a', 'b', 'c', 'd', 'e' };
    var actual: [5]u16 = undefined;
    string(&actual, "abcde");
    try testing.expect(std.mem.eql(u16, &expected, &actual));
}
