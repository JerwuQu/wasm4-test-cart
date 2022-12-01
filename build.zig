const std = @import("std");
const WasmOptStep = @import("wasmoptstep.zig");

pub fn build(b: *std.build.Builder) !void {
    const lib = b.addSharedLibrary("cart", "src/main.zig", .unversioned);
    lib.linkLibC();
    lib.addIncludePath("./src");
    lib.setBuildMode(.ReleaseSmall);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;

    // NOTE: We place stack at end of memory
    // We also offset global_base by 4 so that we can put a u32 cookie between WASM-4 memory and user memory
    // See https://wasm4.org/docs/reference/memory
    lib.stack_size = 8192;
    lib.global_base = 6560 + 4;

    lib.strip = true;
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };
    lib.install();

    // Optimize
    const wasmOptStep = WasmOptStep.create(b, lib.getOutputSource());
    wasmOptStep.step.dependOn(&lib.install_step.?.step);
    b.default_step = &wasmOptStep.step;
}
