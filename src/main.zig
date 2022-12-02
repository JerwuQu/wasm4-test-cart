const std = @import("std");
const w4 = @import("wasm4.zig");
const crt = @import("crt/crt.zig");
const fb_both = @import("fb_both.zig");

// Cookie used to detect memory corruption - See build.zig
const COOKIE = 0x0F1E2D3C;
const memoryStartCookiePtr = @intToPtr(*volatile u32, 6560);

var testState = struct {
    passed: usize = 0,
    failed: usize = 0,
}{};

var fmtbuf: [128]u8 = undefined;

fn bufPrintZ(comptime fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrintZ(&fmtbuf, fmt, args) catch unreachable;
}

fn assertFailed(ctx: []const u8, comptime src: std.builtin.SourceLocation) void {
    const ctxPtr = if (ctx.len == 0) "<unnamed>" else ctx.ptr;
    w4.tracef("!!! Failed assertion: %s (in %s, file line %d)", ctxPtr, src.fn_name.ptr, src.line);
    testState.failed += 1;
}

fn assert(condition: bool, ctx: []const u8, comptime src: std.builtin.SourceLocation) void {
    if (condition) {
        testState.passed += 1;
    } else {
        assertFailed(ctx, src);
    }
}

fn assertEqualFBs(ctx: []const u8, comptime src: std.builtin.SourceLocation) void {
    assert(std.mem.eql(u8, w4.FRAMEBUFFER, crt.FRAMEBUFFER), ctx, src);
    std.mem.set(u8, w4.FRAMEBUFFER, 0);
    std.mem.set(u8, crt.FRAMEBUFFER, 0);
}

// Test initial memory state
fn test_initial_memory() void {
    // PALETTE
    assert(w4.PALETTE[0] == 0xe0f8cf, "", @src());
    assert(w4.PALETTE[1] == 0x86c06c, "", @src());
    assert(w4.PALETTE[2] == 0x306850, "", @src());
    assert(w4.PALETTE[3] == 0x071821, "", @src());

    // DRAW_COLORS
    assert(w4.DRAW_COLORS.* == 0x1203, "", @src());

    // SYSTEM_FLAGS
    assert(w4.SYSTEM_FLAGS.* == 0, "", @src());

    // FRAMEBUFFER
    assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "", @src());
}

// Test disk capabilities
fn test_disk() void {
    const DISK_MAX = 1024;
    const DISK_MAX_2 = DISK_MAX * 2;
    const BYTE_UNUSED_IN = 0xAA;
    const BYTE_UNUSED_OUT = 0xBB;
    const BYTE_COPIED = 0xCC;

    var bufIn: [DISK_MAX_2]u8 = undefined;
    var bufOut: [DISK_MAX_2]u8 = undefined;

    {
        const case = "disk: single byte";

        std.mem.set(u8, &bufIn, BYTE_UNUSED_IN);
        bufIn[0] = BYTE_COPIED;
        assert(w4.diskw(&bufIn, 1) == 1, case, @src());

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        assert(w4.diskr(&bufOut, DISK_MAX) == 1, case, @src());
        assert(bufOut[0] == BYTE_COPIED, case, @src());
        assert(std.mem.allEqual(u8, bufOut[1..], BYTE_UNUSED_OUT), case, @src());
    }

    {
        const case = "disk: full size (1024)";

        std.mem.set(u8, bufIn[0..DISK_MAX], BYTE_COPIED);
        std.mem.set(u8, bufIn[DISK_MAX..], BYTE_UNUSED_IN);
        assert(w4.diskw(&bufIn, DISK_MAX) == DISK_MAX, case, @src());

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        assert(w4.diskr(&bufOut, DISK_MAX) == DISK_MAX, case, @src());
        assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case, @src());
        assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case, @src());
    }

    {
        const case = "disk: oversized (2048)";

        std.mem.set(u8, &bufIn, BYTE_COPIED);
        assert(w4.diskw(&bufIn, DISK_MAX_2) == DISK_MAX, case, @src());

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        assert(w4.diskr(&bufOut, DISK_MAX_2) == DISK_MAX, case, @src());
        assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case, @src());
        assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case, @src());
    }
}

fn test_draw_init() void {
    crt.init();

    // FRAMEBUFFER empty
    assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "", @src());

    // Manual set (aka. verify mutability)
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    assertEqualFBs("FRAMEBUFFER empty on init", @src());

    // See that FRAMEBUFFER isn't modified by DRAW_COLORS
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    fb_both.DRAW_COLORS(0x1234);
    assertEqualFBs("FRAMEBUFFER modified by DRAW_COLORS", @src());
}

fn test_draw_primitives() void {
    const positions = [_]i32{-160, -159, -1, 0, 1, 159, 160};
    const sizes = [_]u32{0, 1, 2, 80, 158, 159, 160, 161};

    // line, hline, vline, rect, oval
    var xi: usize = 0;
    while (xi < positions.len) : (xi += 1) {
        const x = positions[xi];
        var yi: usize = 0;
        while (yi < positions.len) : (yi += 1) {
            const y = positions[yi];

            // Positioned
            var x2i: usize = 0;
            while (x2i < positions.len) : (x2i += 1) {
                const x2 = positions[x2i];
                var y2i: usize = 0;
                while (y2i < positions.len) : (y2i += 1) {
                    const y2 = positions[y2i];
                    fb_both.DRAW_COLORS(0x34);
                    fb_both.line(x, y, x2, y2);
                    assertEqualFBs(bufPrintZ("line: {},{} to {},{}", .{x, y, x2, y2}), @src());
                }
            }

            // Sized
            var wi: usize = 0;
            while (wi < sizes.len) : (wi += 1) {
                const w = sizes[wi];

                fb_both.DRAW_COLORS(0x34);
                fb_both.hline(x, y, w);
                assertEqualFBs(bufPrintZ("hline: {},{} len {}", .{x, y, w}), @src());
                fb_both.vline(x, y, w);
                assertEqualFBs(bufPrintZ("vline: {},{} len {}", .{x, y, w}), @src());

                var hi: usize = 0;
                while (hi < sizes.len) : (hi += 1) {
                    const h = sizes[hi];

                    fb_both.DRAW_COLORS(0x4);
                    fb_both.rect(x, y, w, h);
                    assertEqualFBs(bufPrintZ("rect: {},{} {}x{}", .{x, y, w, h}), @src());
                    fb_both.oval(x, y, w, h);
                    assertEqualFBs(bufPrintZ("oval: {},{} {}x{}", .{x, y, w, h}), @src());

                    fb_both.DRAW_COLORS(0x34);
                    fb_both.rect(x, y, w, h);
                    assertEqualFBs(bufPrintZ("rect (outlined): {},{} {}x{}", .{x, y, w, h}), @src());
                    fb_both.oval(x, y, w, h);
                    assertEqualFBs(bufPrintZ("oval (outlined): {},{} {}x{}", .{x, y, w, h}), @src());
                }
            }
        }
    }

    // TODO: test transparency
    // TODO: test using invalid DRAW_COLORS
}

fn test_draw_text() void {
    fb_both.DRAW_COLORS(0x34);

    // text, textUtf8, textUtf16: all sequentially charcodes
    {
        var i: usize = 0;
        var text8Buf: [2]u8 = .{ 0 } ** 2;
        var text16Buf: [2]u16 = .{ 0 } ** 2;
        while (i < 256) : (i += 1) {
            text8Buf[0] = @intCast(u8, i);
            text16Buf[0] = @intCast(u16, i);
            fb_both.text(&text8Buf, 10, 10);
            assertEqualFBs(bufPrintZ("text: charcode {}", .{i}), @src());
            fb_both.textUtf8(text8Buf[0..1], 10, 10);
            assertEqualFBs(bufPrintZ("textUtf8: charcode {}", .{i}), @src());
            fb_both.textUtf16(text16Buf[0..1], 10, 10);
            assertEqualFBs(bufPrintZ("textUtf16: charcode {}", .{i}), @src());
        }
    }

    // text, textUtf8, textUtf16: newline
    fb_both.text("A\nB", 10, 10);
    assertEqualFBs("text: newline", @src());
    fb_both.textUtf8("A\nB", 10, 10);
    assertEqualFBs("textUtf8: newline", @src());
    fb_both.textUtf16(&[3]u16{ 'A', '\n', 'B' }, 10, 10);
    assertEqualFBs("textUtf16: newline", @src());

    // text, textUtf8, textUtf16: respect null-terminator
    fb_both.text("A\x00B", 10, 10);
    assertEqualFBs("text: respect null-terminator", @src());
    fb_both.textUtf8("A\x00B", 10, 10);
    assertEqualFBs("textUtf8: respect null-terminator", @src());
    fb_both.textUtf16(&[3]u16{ 'A', 0, 'B' }, 10, 10);
    assertEqualFBs("textUtf16: respect null-terminator", @src());

    // text, textUtf8, textUtf16: all charcodes, \n wrapping
    {
        var text8Buf: [512]u8 = .{ 0 } ** 512;
        var text16Buf: [512]u16 = .{ 0 } ** 512;
        var i: usize = 1;
        var ai: usize = 0;
        while (i < 256) : (i += 1) {
            text8Buf[ai] = @intCast(u8, i);
            text16Buf[ai] = @intCast(u16, i);
            ai += 1;
            if (i % 16 == 0) {
                text8Buf[ai] = '\n';
                text16Buf[ai] = '\n';
                ai += 1;
            }
        }
        fb_both.text(&text8Buf, 10, 10);
        assertEqualFBs("text: all charcodes, wrapped", @src());
        fb_both.textUtf8(text8Buf[0..ai], 10, 10);
        assertEqualFBs("textUtf8: all charcodes, wrapped", @src());
        fb_both.textUtf16(text16Buf[0..ai], 10, 10);
        assertEqualFBs("textUtf16: all charcodes, wrapped", @src());
    }

    // text: OOB placements
    fb_both.text("@@@@@", -4, -4);
    assertEqualFBs("text: OOB", @src());
    fb_both.text("@@@@@", 156, -4);
    assertEqualFBs("text: OOB", @src());
    fb_both.text("@@@@@", -4, 156);
    assertEqualFBs("text: OOB", @src());
    fb_both.text("@@@@@", 156, 156);
    assertEqualFBs("text: OOB", @src());

    // textUtf16, invalid charcodes
    {
        var i: usize = 256;
        while (i < 65536) : (i += 2251) {
            w4.textUtf16(&[2]u16{ @intCast(u16, i), 0 }, 2, 10, 10);
            assertEqualFBs(bufPrintZ("textUtf16: invalid charcode {}", .{i}), @src());
        }
    }
}

fn test_draw_blit() void {
    // TODO: blit
    // TODO: blitSub
}

// Test persistency through `update`
fn test_update_persistance() void {
    // TODO: FRAMEBUFFER persistance with/without SYSTEM_PRESERVE_FRAMEBUFFER
    // TODO: PALETTE persistance
    // TODO: DRAW_COLORS persistance
}

export fn start() void {
    memoryStartCookiePtr.* = COOKIE;

    w4.trace("Test suite started");

    test_initial_memory();
    test_disk();
    test_draw_init();
    test_draw_primitives();
    test_draw_text();
    test_draw_blit();
    test_update_persistance();

    w4.trace("Test suite finished!");
    if (memoryStartCookiePtr.* == COOKIE) {
        w4.tracef("Passed: %d", testState.passed);
        w4.tracef("Failed: %d", testState.failed);

        if (testState.failed == 0) {
            w4.PALETTE[0] = 0x88ff88;
        } else {
            w4.PALETTE[0] = 0xff8888;
        }
    } else {
        w4.trace("Memory corrupted!");
        w4.PALETTE[0] = 0xff0000;
    }
}

export fn update() void {}
