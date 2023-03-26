const uefi = @import("std").os.uefi;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;

pub fn init(system_table: *uefi.tables.SystemTable) !void {
    con_out = system_table.con_out orelse return uefi.Status.Unsupported.err();

    _ = con_out.clearScreen();
}
