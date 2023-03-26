const uefi = @import("std").os.uefi;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;
pub var bs: *uefi.tables.BootServices = undefined;

pub fn init(system_table: *uefi.tables.SystemTable) !void {
    con_out = system_table.con_out orelse return uefi.Status.Unsupported.err();
    bs = system_table.boot_services orelse return uefi.Status.Unsupported.err();

    _ = con_out.clearScreen();
}
