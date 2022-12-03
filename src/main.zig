const std = @import("std");
const w4 = @import("wasm4.zig");
const crt = @import("crt/crt.zig");
const fb_both = @import("fb_both.zig");

const TERM_COLOR_RESET = "\x1b[0m";
const TERM_COLOR_RED = "\x1b[31m";
const TERM_COLOR_GREEN = "\x1b[32m";
const TERM_COLOR_YELLOW = "\x1b[33m";
const TERM_COLOR_BLUE = "\x1b[34m";

// This is not actually an error, but used as a convenient way to unroll
// This gives us the ability to essentially breakpoint and visually inspect what went wrong
const InspectError = error {inspect};

const Test = struct {
    name: []const u8,
    func: *const fn() InspectError!void,
};

const TestState = struct {
    tst: *const Test,
    passed: usize = 0,
    failed: usize = 0,
    inspecting: ?usize = null,
};

var fmtbuf: [128]u8 = undefined;
var lastPad: u32 = 0;
var testsOK = false;

// Cookie used to detect memory corruption - See build.zig
const COOKIE = 0x0F1E2D3C;
const memoryStartCookiePtr = @intToPtr(*volatile u32, 6560);

// List of all `test_` functions
const tests: []const Test = blk: {
    const this: std.builtin.Type.Struct = @typeInfo(@This()).Struct;
    var btests: []const Test = &.{};
    for (this.decls) |decl| {
        if (std.mem.startsWith(u8, decl.name, "test_")) {
            btests = btests ++ [_]Test{.{
                .name = decl.name,
                .func = @field(@This(), decl.name),
            }};
        }
    }
    break :blk btests;
};
var testStates: [tests.len]TestState = undefined;

var currentTest: *TestState = undefined;

var inspectState: union(enum) {
    testMenu: struct {
        index: usize = 0,
    },
    assertionInput: struct {
        testI: usize,
        number: usize = 0,
    },
    framebufferView: struct {
        testI: usize,
        number: usize = 0,
        swapped: bool = false,
    }
} = .{.testMenu = .{}};

fn bufPrintZ(comptime fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrintZ(&fmtbuf, fmt, args) catch unreachable;
}

fn assert(condition: bool, ctx: []const u8) InspectError!void {
    if (condition) {
        currentTest.passed += 1;
    } else {
        const ctxPtr = if (ctx.len == 0) "<unnamed>" else ctx.ptr;
        if (currentTest.inspecting == null) {
            w4.tracef(TERM_COLOR_RED ++ "- Failed assertion [#%d]: %s " ++ TERM_COLOR_RESET, currentTest.failed + 1, ctxPtr);
        } else if (currentTest.inspecting.? == currentTest.failed) {
            w4.tracef(TERM_COLOR_BLUE ++ "- Inspecting failed assertion [#%d]: " ++ TERM_COLOR_RESET ++ "%s", currentTest.failed + 1, ctxPtr);
            return InspectError.inspect;
        }
        currentTest.failed += 1;
    }
}

fn assertEqualFBs(ctx: []const u8) InspectError!void {
    try assert(std.mem.eql(u8, w4.FRAMEBUFFER, crt.FRAMEBUFFER), ctx);
    std.mem.set(u8, w4.FRAMEBUFFER, 0);
    std.mem.set(u8, crt.FRAMEBUFFER, 0);
}

// Test initial memory state
fn test_initial_memory() InspectError!void {
    // PALETTE
    try assert(w4.PALETTE[0] == 0xe0f8cf, "default PALETTE");
    try assert(w4.PALETTE[1] == 0x86c06c, "default PALETTE");
    try assert(w4.PALETTE[2] == 0x306850, "default PALETTE");
    try assert(w4.PALETTE[3] == 0x071821, "default PALETTE");

    // DRAW_COLORS
    try assert(w4.DRAW_COLORS.* == 0x1203, "default DRAW_COLORS");

    // SYSTEM_FLAGS
    try assert(w4.SYSTEM_FLAGS.* == 0, "default SYSTEM_FLAGS");

    // FRAMEBUFFER
    try assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "empty initial FRAMEBUFFER");

    // User-memory (mostly) empty
    // NOTE: We can't actually check the whole memory because this test cart will import some itself
    //       Instead, we only check the last 32 KB
    {
        const SZ = 65536;
        const START = 32768;
        try assert(std.mem.allEqual(u8, @intToPtr([*]u8, START)[0..SZ - START], 0), "empty user-memory");
    }
}

// Test disk capabilities
fn test_disk() InspectError!void {
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
        try assert(w4.diskw(&bufIn, 1) == 1, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try assert(w4.diskr(&bufOut, DISK_MAX) == 1, case);
        try assert(bufOut[0] == BYTE_COPIED, case);
        try assert(std.mem.allEqual(u8, bufOut[1..], BYTE_UNUSED_OUT), case);
    }

    {
        const case = "disk: full size (1024)";

        std.mem.set(u8, bufIn[0..DISK_MAX], BYTE_COPIED);
        std.mem.set(u8, bufIn[DISK_MAX..], BYTE_UNUSED_IN);
        try assert(w4.diskw(&bufIn, DISK_MAX) == DISK_MAX, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try assert(w4.diskr(&bufOut, DISK_MAX) == DISK_MAX, case);
        try assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case);
        try assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case);
    }

    {
        const case = "disk: oversized (2048)";

        std.mem.set(u8, &bufIn, BYTE_COPIED);
        try assert(w4.diskw(&bufIn, DISK_MAX_2) == DISK_MAX, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try assert(w4.diskr(&bufOut, DISK_MAX_2) == DISK_MAX, case);
        try assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case);
        try assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case);
    }
}

fn test_fb_init() InspectError!void {
    crt.init();

    // FRAMEBUFFER empty
    try assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "empty FRAMEBUFFER");

    // Manual set (aka. verify mutability)
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    try assertEqualFBs("mutable FRAMEBUFFER");

    // See that FRAMEBUFFER isn't modified by DRAW_COLORS
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    fb_both.DRAW_COLORS(0x1234);
    try assertEqualFBs("FRAMEBUFFER modified by DRAW_COLORS");
}

fn test_draw_primitives() InspectError!void {
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
                    try assertEqualFBs(bufPrintZ("line: {},{} to {},{}", .{x, y, x2, y2}));
                }
            }

            // Sized
            var wi: usize = 0;
            while (wi < sizes.len) : (wi += 1) {
                const w = sizes[wi];

                fb_both.DRAW_COLORS(0x34);
                fb_both.hline(x, y, w);
                try assertEqualFBs(bufPrintZ("hline: {},{} len {}", .{x, y, w}));
                fb_both.vline(x, y, w);
                try assertEqualFBs(bufPrintZ("vline: {},{} len {}", .{x, y, w}));

                var hi: usize = 0;
                while (hi < sizes.len) : (hi += 1) {
                    const h = sizes[hi];

                    fb_both.DRAW_COLORS(0x4);
                    fb_both.rect(x, y, w, h);
                    try assertEqualFBs(bufPrintZ("rect: {},{} {}x{}", .{x, y, w, h}));
                    fb_both.oval(x, y, w, h);
                    try assertEqualFBs(bufPrintZ("oval: {},{} {}x{}", .{x, y, w, h}));

                    fb_both.DRAW_COLORS(0x34);
                    fb_both.rect(x, y, w, h);
                    try assertEqualFBs(bufPrintZ("rect (outlined): {},{} {}x{}", .{x, y, w, h}));
                    fb_both.oval(x, y, w, h);
                    try assertEqualFBs(bufPrintZ("oval (outlined): {},{} {}x{}", .{x, y, w, h}));
                }
            }
        }
    }

    // TODO: test transparency
    // TODO: test using invalid DRAW_COLORS
}

fn test_draw_text() InspectError!void {
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
            try assertEqualFBs(bufPrintZ("text: charcode {}", .{i}));
            fb_both.textUtf8(text8Buf[0..1], 10, 10);
            try assertEqualFBs(bufPrintZ("textUtf8: charcode {}", .{i}));
            fb_both.textUtf16(text16Buf[0..1], 10, 10);
            try assertEqualFBs(bufPrintZ("textUtf16: charcode {}", .{i}));
        }
    }

    // text, textUtf8, textUtf16: newline
    fb_both.text("A\nB", 10, 10);
    try assertEqualFBs("text: newline");
    fb_both.textUtf8("A\nB", 10, 10);
    try assertEqualFBs("textUtf8: newline");
    fb_both.textUtf16(&[3]u16{ 'A', '\n', 'B' }, 10, 10);
    try assertEqualFBs("textUtf16: newline");

    // text, textUtf8, textUtf16: respect null-terminator
    fb_both.text("A\x00B", 10, 10);
    try assertEqualFBs("text: respect null-terminator");
    fb_both.textUtf8("A\x00B", 10, 10);
    try assertEqualFBs("textUtf8: respect null-terminator");
    fb_both.textUtf16(&[3]u16{ 'A', 0, 'B' }, 10, 10);
    try assertEqualFBs("textUtf16: respect null-terminator");

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
        try assertEqualFBs("text: all charcodes, wrapped");
        fb_both.textUtf8(text8Buf[0..ai], 10, 10);
        try assertEqualFBs("textUtf8: all charcodes, wrapped");
        fb_both.textUtf16(text16Buf[0..ai], 10, 10);
        try assertEqualFBs("textUtf16: all charcodes, wrapped");
    }

    // text: OOB placements
    fb_both.text("@@@@@", -4, -4);
    try assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", 156, -4);
    try assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", -4, 156);
    try assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", 156, 156);
    try assertEqualFBs("text: OOB");

    // textUtf16, invalid charcodes
    {
        var i: usize = 256;
        while (i < 65536) : (i += 2251) {
            w4.textUtf16(&[2]u16{ @intCast(u16, i), 0 }, 2, 10, 10);
            try assertEqualFBs(bufPrintZ("textUtf16: invalid charcode {}", .{i}));
        }
    }
}

fn test_draw_blit() InspectError!void {
    const smiley_1bpp = [8]u8{
        0b11000011,
        0b10000001,
        0b00100100,
        0b00100100,
        0b00000000,
        0b00100100,
        0b10011001,
        0b11000011,
    };

    fb_both.DRAW_COLORS(0x34);

    const blitFlagCombos = [_]u32{
        0,
        w4.BLIT_FLIP_X,
        w4.BLIT_FLIP_Y,
        w4.BLIT_FLIP_X | w4.BLIT_FLIP_Y,
        w4.BLIT_ROTATE,
        w4.BLIT_ROTATE | w4.BLIT_FLIP_X,
        w4.BLIT_ROTATE | w4.BLIT_FLIP_Y,
        w4.BLIT_ROTATE | w4.BLIT_FLIP_X | w4.BLIT_FLIP_Y,
    };

    for (blitFlagCombos) |flags| {
        fb_both.blit(&smiley_1bpp, 10, 10, 8, 8, w4.BLIT_1BPP | flags);
        try assertEqualFBs(bufPrintZ("blit: 1bpp basic, flags: {}", .{flags}));
        fb_both.blit(&smiley_1bpp, 10, 10, 3, 3, w4.BLIT_1BPP | flags);
        try assertEqualFBs(bufPrintZ("blit: 1bpp unaligned, flags: {}", .{flags}));
    }

    // TODO: blit 2bpp
    // TODO: blitSub
}

// Test persistency through `update`
fn test_update_persistance() InspectError!void {
    // TODO: FRAMEBUFFER persistance with/without SYSTEM_PRESERVE_FRAMEBUFFER
    // TODO: PALETTE persistance
    // TODO: DRAW_COLORS persistance
}

export fn start() void {
    memoryStartCookiePtr.* = COOKIE;

    w4.trace(TERM_COLOR_BLUE ++ "Test suite starting..." ++ TERM_COLOR_RESET);

    // Call each test function, logging failed assertions as we go
    var totalPassed: usize = 0;
    var totalFailed: usize = 0;
    for (tests) |*tst, i| {
        testStates[i] = TestState{.tst = tst};
        currentTest = &testStates[i];
        w4.tracef(TERM_COLOR_YELLOW ++ "> %s..." ++ TERM_COLOR_RESET, tst.name.ptr);
        tst.func() catch unreachable;
        totalPassed += currentTest.passed;
        totalFailed += currentTest.failed;
    }
    w4.trace(TERM_COLOR_BLUE ++ "Test suite finished!" ++ TERM_COLOR_RESET);

    // Check memory cookie
    if (memoryStartCookiePtr.* != COOKIE) {
        w4.trace(TERM_COLOR_RED ++ "Memory corrupted!" ++ TERM_COLOR_RESET);
        w4.PALETTE[0] = 0xff0000;
        return;
    }

    w4.tracef("Summary:");
    for (testStates) |state| {
        if (state.failed == 0) {
            w4.tracef("- %s: " ++ TERM_COLOR_GREEN ++ "OK!" ++ TERM_COLOR_RESET ++ " (%d passed)", state.tst.name.ptr, state.passed);
        } else {
            w4.tracef("- %s: " ++ TERM_COLOR_RED ++ "Failed!" ++ TERM_COLOR_RESET ++ " (%d passed, %d failed)", state.tst.name.ptr, state.passed, state.failed);
        }
    }
    if (totalFailed == 0) {
        w4.tracef(TERM_COLOR_GREEN ++ "OK!" ++ TERM_COLOR_RESET ++ " (%d passed)", totalPassed);
        testsOK = true;
    } else {
        w4.tracef(TERM_COLOR_RED ++ "Failed!" ++ TERM_COLOR_RESET ++ " (%d passed, %d failed)", totalPassed, totalFailed);
        testsOK = false;
    }
}

export fn update() void {
    const pad = w4.GAMEPAD1.*;
    const padPressed = (pad ^ lastPad) & pad;
    lastPad = pad;

    w4.PALETTE[1] = 0x000000;
    w4.PALETTE[2] = 0xffffff;

    if (testsOK) {
        w4.PALETTE[0] = 0x88ff88;
        w4.DRAW_COLORS.* = 0x0004;
        w4.text("OK!", 10, 10);
        return;
    }

    w4.PALETTE[0] = 0xff8888;

    switch (inspectState) {
        .testMenu => |*v| {
            w4.DRAW_COLORS.* = 0x0004;
            w4.text("Inspect failed test", 2, 2);
            var di: usize = 0;
            for (tests) |*tst, i| {
                const failed = testStates[i].failed;
                if (std.mem.startsWith(u8, tst.name, "test_draw_") and failed > 0) {
                    const shortName = tst.name[("test_draw_".len)..];
                    if (di == v.index) {
                        w4.DRAW_COLORS.* = 0x0034;
                        if (padPressed & w4.BUTTON_1 != 0) {
                            inspectState = .{.assertionInput = .{.testI = i}};
                        }
                    } else {
                        w4.DRAW_COLORS.* = 0x0004;
                    }
                    w4.textUtf8Wrap(bufPrintZ("{s} ({})", .{shortName, failed}), 5, @intCast(i32, 15 + 10 * di));
                    di += 1;
                }
            }
            if (padPressed & w4.BUTTON_UP != 0) {
                v.index = (v.index + di - 1) % di;
            }
            if (padPressed & w4.BUTTON_DOWN != 0) {
                v.index = (v.index + 1) % di;
            }
        },
        .assertionInput => |*v| {
            const failed = testStates[v.testI].failed;
            w4.DRAW_COLORS.* = 0x0004;
            w4.text("Choose fail #", 2, 2);
            w4.text("It will first show\nyour LOCAL version.\nPress \x84/\x85 to swap.", 2, 40);
            w4.DRAW_COLORS.* = 0x0034;
            w4.textUtf8Wrap(bufPrintZ("< {} > / {}", .{v.number + 1, failed}), 8, 16);
            if (padPressed & w4.BUTTON_LEFT != 0) {
                v.number = (v.number + failed - 1) % failed;
            }
            if (padPressed & w4.BUTTON_RIGHT != 0) {
                v.number = (v.number + 1) % failed;
            }
            var skip: usize = if (failed > 500) 5 else 1;
            if (pad & w4.BUTTON_DOWN != 0) {
                v.number = (v.number + failed - skip) % failed;
            }
            if (pad & w4.BUTTON_UP != 0) {
                v.number = (v.number + skip) % failed;
            }
            if (padPressed & w4.BUTTON_1 != 0) {
                var testState = TestState{
                    .tst = &tests[v.testI],
                    .inspecting = v.number,
                };
                currentTest = &testState;
                var ok = false;
                std.mem.set(u8, w4.FRAMEBUFFER, 0);
                std.mem.set(u8, crt.FRAMEBUFFER, 0);
                tests[v.testI].func() catch {ok = true;};
                if (!ok) unreachable;
                w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;
                inspectState = .{.framebufferView = .{
                    .testI = v.testI,
                    .number = v.number,
                }};
            }
            if (padPressed & w4.BUTTON_2 != 0) {
                inspectState = .{.testMenu = .{}};
            }
        },
        .framebufferView => |*v| {
            w4.PALETTE[0] = if (v.swapped) 0xe0f8cf else 0xf8e0cf;
            w4.PALETTE[1] = 0x86c06c;
            w4.PALETTE[2] = 0x306850;
            w4.PALETTE[3] = 0x071821;

            if (padPressed & (w4.BUTTON_LEFT | w4.BUTTON_RIGHT) != 0) {
                var i: usize = 0;
                while (i < 6400) : (i += 1) {
                    const swap = w4.FRAMEBUFFER[i];
                    w4.FRAMEBUFFER[i] = crt.FRAMEBUFFER[i];
                    crt.FRAMEBUFFER[i] = swap;
                }
                v.swapped = !v.swapped;
            }
            if (padPressed & w4.BUTTON_2 != 0) {
                w4.SYSTEM_FLAGS.* = 0;
                inspectState = .{.assertionInput = .{
                    .testI = v.testI,
                    .number = v.number,
                }};
            }
        },
    }
}
