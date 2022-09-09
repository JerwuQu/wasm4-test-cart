const std = @import("std");
const w4 = @import("wasm4.zig");
const nativeW4 = @import("native.zig");

pub var passed: u8 = 0;
pub var failed: u8 = 0;
pub var suspendOnFail = false;
pub var suspendFrame: ?anyframe = undefined;

pub fn init() void {
    passed = 0;
    failed = 0;
    nativeW4.init();
    clear();
}

pub fn clear() void {
    std.mem.set(u8, w4.FRAMEBUFFER, 0);
    std.mem.set(u8, nativeW4.FRAMEBUFFER, 0);
}

pub fn assert(src: std.builtin.SourceLocation, extra: usize) void {
    const match = std.mem.eql(u8, w4.FRAMEBUFFER, nativeW4.FRAMEBUFFER);
    if (suspendOnFail) {
        if (!match) {
            w4.tracef("Inspecting failed test: %s:%d (%d)", src.fn_name.ptr, src.line, extra);
            w4.trace("- Showing WASM-4 API result");
            suspend {
                suspendFrame = @frame();
            }
            w4.trace("- Showing native WASM-4 runtime result");
            std.mem.copy(u8, w4.FRAMEBUFFER, nativeW4.FRAMEBUFFER);
            suspend {
                suspendFrame = @frame();
            }
            w4.trace("Moving on...");
            suspendFrame = null;
        }
    } else {
        if (match) {
            passed += 1;
        } else {
            w4.tracef("!!! Failed: %s:%d (%d)", src.fn_name.ptr, src.line, extra);
            failed += 1;
        }
    }
    clear();
}

pub fn setDrawColors(colors: u16) void {
    w4.DRAW_COLORS.* = colors;
    nativeW4.DRAW_COLORS.* = colors;
}

pub fn hline(x: i32, y: i32, len: u32) void {
    w4.hline(x, y, len);
    nativeW4.hline(x, y, len);
}

pub fn vline(x: i32, y: i32, len: u32) void {
    w4.vline(x, y, len);
    nativeW4.vline(x, y, len);
}

pub fn rect(x: i32, y: i32, width: u32, height: u32) void {
    w4.rect(x, y, width, height);
    nativeW4.rect(x, y, width, height);
}

pub fn line(x1: i32, y1: i32, x2: i32, y2: i32) void {
    w4.line(x1, y1, x2, y2);
    nativeW4.linw(x1, y1, x2, y2);
}

pub fn oval(x: i32, y: i32, width: i32, height: i32) void {
    w4.oval(x, y, width, height);
    nativeW4.oval(x, y, width, height);
}

pub fn text(str: []const u8, x: i32, y: i32) void {
    w4.text(str, x, y);
    nativeW4.text(str, x, y);
}

pub fn blit(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, flags: u32) void {
    w4.blit(sprite, x, y, width, height, flags);
    nativeW4.blit(sprite, x, y, width, height, flags);
}

pub fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, src_x: u32, src_y: u32, stride: i32, flags: u32) void {
    w4.blitSub(sprite, x, y, width, height, src_x, src_y, stride, flags);
    nativeW4.blitSub(sprite, x, y, width, height, src_x, src_y, stride, flags);
}