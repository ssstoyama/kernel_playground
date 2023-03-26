const std = @import("std");
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe,
    });

    const loader = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = .{ .path = "main.zig" },
        .target = CrossTarget{
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
            .abi = .msvc,
        },
        .optimize = optimize,
        .linkage = .static,
    });
    loader.setOutputDir("fs/efi/boot");
    loader.install();

    const qemu = b.step("run", "run in qemu");
    const run_qemu = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-m",
        "1G",
        "-bios",
        "/usr/share/ovmf/OVMF.fd",
        "-hdd",
        "fat:rw:fs",
        "-device",
        "qemu-xhci,id=xhci",
        "-monitor",
        "stdio",
    });
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&loader.step);

    const test_step = b.step("test", "testing");
    test_step.dependOn(b.getInstallStep());

    const loader_test = b.addTest(.{
        .name = "loader",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = .Debug,
    });

    const test_filter = b.option(
        []const u8,
        "test-filter",
        "Skip tests that do not match filter",
    );
    loader_test.setFilter(test_filter);

    test_step.dependOn(&loader_test.step);
}
