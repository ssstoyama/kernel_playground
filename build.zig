const std = @import("std");
const CrossTarget = std.zig.CrossTarget;

const LoaderPath = "src/loader/main.zig";
const KernelPath = "src/kernel/main.zig";

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe,
    });

    const loader = try buildLoader(b, optimize);
    const kernel = try buildKernel(b, optimize);

    const qemu = qemuCommand(b);
    qemu.step.dependOn(&loader.step);
    qemu.step.dependOn(&kernel.step);

    const run_qemu = b.step("run", "run in qemu");
    run_qemu.dependOn(&qemu.step);

    const test_step = b.step("test", "testing loader");
    test_step.dependOn(b.getInstallStep());

    const loader_test = b.addTest(.{
        .name = "loader_test",
        .root_source_file = .{ .path = LoaderPath },
        .optimize = .Debug,
    });
    const kernel_test = b.addTest(.{
        .name = "kernel_test",
        .root_source_file = .{ .path = KernelPath },
        .optimize = .Debug,
    });

    const test_filter = b.option(
        []const u8,
        "test-filter",
        "Skip tests that do not match filter",
    );
    loader_test.setFilter(test_filter);
    kernel_test.setFilter(test_filter);

    test_step.dependOn(&loader_test.step);
    test_step.dependOn(&kernel_test.step);
}

fn buildKernel(b: *std.Build, optimize: std.builtin.Mode) !*std.Build.CompileStep {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .freestanding,
            .ofmt = .elf,
            .abi = .none,
        },
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = .{ .path = KernelPath },
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    kernel.image_base = 0x100000;
    kernel.entry_symbol_name = "kernel_main";
    kernel.link_z_relro = false;
    kernel.red_zone = false;
    kernel.is_linking_libc = false;
    kernel.is_linking_libcpp = false;
    kernel.setOutputDir("fs");
    kernel.install();
    return kernel;
}

fn buildLoader(b: *std.Build, optimize: std.builtin.Mode) !*std.Build.CompileStep {
    const loader = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = .{ .path = LoaderPath },
        .target = CrossTarget{
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
            .ofmt = .coff,
            .abi = .msvc,
        },
        .optimize = optimize,
        .linkage = .static,
    });
    loader.setOutputDir("fs/efi/boot");
    loader.install();
    return loader;
}

fn qemuCommand(b: *std.Build) *std.Build.RunStep {
    const is_debug = b.option(bool, "debug", "debugging in qemu") orelse false;

    const args = [_][]const u8{
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
    };
    if (is_debug) {
        const debug_args = args ++ [_][]const u8{ "-s", "-S" };
        return b.addSystemCommand(&debug_args);
    }
    return b.addSystemCommand(&args);
}
