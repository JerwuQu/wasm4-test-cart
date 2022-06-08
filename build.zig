const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const lib = b.addSharedLibrary("cart", "src/main.zig", .unversioned);
    lib.linkLibC();
    lib.addIncludePath("./wasm4-native");
    lib.setBuildMode(.ReleaseSmall);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;
    lib.strip = true;
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };
    lib.install();
}
