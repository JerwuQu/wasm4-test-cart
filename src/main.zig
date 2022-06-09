const wasmW4 = @import("wasm4.zig");
const nativeW4Base = @import("native.zig");
const nativeW4 = nativeW4Base.w4;
const std = @import("std");
const tests = @import("tests.zig");

var passed: u8 = 0;
var failed: u8 = 0;
var inNative = false;

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

pub fn testTrace(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    var strBuf = std.fmt.bufPrintZ(&buf, fmt, args) catch unreachable;
    if (inNative) {
        wasmW4.trace("From native:");
    } else {
        wasmW4.trace("From wasm:");
    }
    wasmW4.trace(strBuf);
}


fn check() void {
    if (std.mem.eql(u8, wasmW4.FRAMEBUFFER, nativeW4.FRAMEBUFFER)) {
        passed += 1;
    } else {
        wasmW4.trace("  !!! Failed !!!");
        failed += 1;
    }
}

// TODO: workaround for https://github.com/ziglang/zig/issues/3164
var done: u8 = 0;
fn wrapTest(w4: anytype, func: anytype) void {
    func(w4);
    done += 1;
}

pub fn addTest(func: anytype, comptime name: []const u8) void {
    wasmW4.trace("- " ++ name ++ "");

    std.mem.set(u8, wasmW4.FRAMEBUFFER, 0);
    wasmW4.DRAW_COLORS.* = 0x1234;

    std.mem.set(u8, nativeW4.FRAMEBUFFER, 0);
    nativeW4.DRAW_COLORS.* = 0x1234;

    done = 0;
    inNative = false;
    var wasm4Frame = async wrapTest(wasmW4, func);
    inNative = true;
    var nativeFrame = async wrapTest(nativeW4, func);
    while (done != 2) {
        check();
        inNative = false;
        resume wasm4Frame;
        inNative = true;
        resume nativeFrame;
    }
    check();
}

export fn start() void {
    wasmW4.trace("Starting test runner...");
    nativeW4Base.init();
    tests.run();
    displayResults(wasmW4);
}
