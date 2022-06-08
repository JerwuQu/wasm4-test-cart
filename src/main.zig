const wasmW4 = @import("wasm4.zig");
const nativeW4 = @import("native.zig");
const std = @import("std");
const tests = @import("tests.zig");

var passed: u8 = 0;
var failed: u8 = 0;

fn displayResults(w4: anytype) void {
    w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;
    w4.PALETTE[0] = if (failed == 0) 0xaaffaa else 0xffaaaa;
    w4.PALETTE[1] = 0x222222;
    w4.DRAW_COLORS.* = 1;
    w4.rect(0, 0, 160, 160);
    w4.DRAW_COLORS.* = 2;
    var buf: [64]u8 = undefined;
    w4.text(std.fmt.bufPrintZ(&buf, "Tests passed: {}", .{passed}) catch unreachable, 10, 10);
    w4.text(std.fmt.bufPrintZ(&buf, "Tests failed: {}", .{failed}) catch unreachable, 10, 25);
}

pub fn addTest(func: anytype, comptime name: []const u8) void {
    wasmW4.trace("- " ++ name ++ "");
    std.mem.set(u8, wasmW4.FRAMEBUFFER, 0);
    std.mem.set(u8, nativeW4.w4.FRAMEBUFFER, 0);
    func(wasmW4);
    func(nativeW4.w4);
    if (std.mem.eql(u8, wasmW4.FRAMEBUFFER, nativeW4.w4.FRAMEBUFFER)) {
        passed += 1;
    } else {
        wasmW4.trace("  !!! Failed !!!");
        failed += 1;
    }
}

export fn start() void {
    wasmW4.trace("Starting test runner...");
    nativeW4.init();
    tests.run();
    displayResults(wasmW4);
}
