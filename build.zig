const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("generator", "src/generator.zig");
    exe.setBuildMode(mode);
    exe.setTarget(b.standardTargetOptions(.{}));
    exe.linkLibC();
    exe.addIncludePath("./wasm4-native");
    const exeRun = exe.run();

    const lib = b.addSharedLibrary("cart", "src/cart.zig", .unversioned);
    lib.step.dependOn(&exeRun.step);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;
    lib.strip = true;
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };
    lib.install();
}
