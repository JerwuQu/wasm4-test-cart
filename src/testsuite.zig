const std = @import("std");
const w4 = @import("wasm4.zig");
const crt = @import("crt/crt.zig");
const fb_both = @import("fb_both.zig");
const main = @import("main.zig");

// Manual imports
const InspectError = main.InspectError;
const TestState = main.TestState;
const bufPrintZ = main.bufPrintZ;

// Test initial memory state
pub fn test_initial_memory(ts: *TestState) InspectError!void {
    // PALETTE
    try ts.assert(w4.PALETTE[0] == 0xe0f8cf, "default PALETTE");
    try ts.assert(w4.PALETTE[1] == 0x86c06c, "default PALETTE");
    try ts.assert(w4.PALETTE[2] == 0x306850, "default PALETTE");
    try ts.assert(w4.PALETTE[3] == 0x071821, "default PALETTE");

    // DRAW_COLORS
    try ts.assert(w4.DRAW_COLORS.* == 0x1203, "default DRAW_COLORS");

    // SYSTEM_FLAGS
    try ts.assert(w4.SYSTEM_FLAGS.* == 0, "default SYSTEM_FLAGS");

    // FRAMEBUFFER
    try ts.assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "empty initial FRAMEBUFFER");

    // User-memory (mostly) empty
    // NOTE: We can't actually check the whole memory because this test cart will import some itself
    //       Instead, we only check the last 32 KB
    {
        const SZ = 65536;
        const START = 32768;
        try ts.assert(std.mem.allEqual(u8, @intToPtr([*]u8, START)[0..SZ - START], 0), "empty user-memory");
    }
}

// Test disk capabilities
pub fn test_disk(ts: *TestState) InspectError!void {
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
        try ts.assert(w4.diskw(&bufIn, 1) == 1, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try ts.assert(w4.diskr(&bufOut, DISK_MAX) == 1, case);
        try ts.assert(bufOut[0] == BYTE_COPIED, case);
        try ts.assert(std.mem.allEqual(u8, bufOut[1..], BYTE_UNUSED_OUT), case);
    }

    {
        const case = "disk: full size (1024)";

        std.mem.set(u8, bufIn[0..DISK_MAX], BYTE_COPIED);
        std.mem.set(u8, bufIn[DISK_MAX..], BYTE_UNUSED_IN);
        try ts.assert(w4.diskw(&bufIn, DISK_MAX) == DISK_MAX, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try ts.assert(w4.diskr(&bufOut, DISK_MAX) == DISK_MAX, case);
        try ts.assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case);
        try ts.assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case);
    }

    {
        const case = "disk: oversized (2048)";

        std.mem.set(u8, &bufIn, BYTE_COPIED);
        try ts.assert(w4.diskw(&bufIn, DISK_MAX_2) == DISK_MAX, case);

        std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
        try ts.assert(w4.diskr(&bufOut, DISK_MAX_2) == DISK_MAX, case);
        try ts.assert(std.mem.allEqual(u8, bufOut[0..DISK_MAX], BYTE_COPIED), case);
        try ts.assert(std.mem.allEqual(u8, bufOut[DISK_MAX..], BYTE_UNUSED_OUT), case);
    }
}

pub fn test_fb_init(ts: *TestState) InspectError!void {
    crt.init();

    // FRAMEBUFFER empty
    try ts.assert(std.mem.allEqual(u8, w4.FRAMEBUFFER, 0), "empty FRAMEBUFFER");

    // Manual set (aka. verify mutability)
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    try ts.assertEqualFBs("mutable FRAMEBUFFER");

    // See that FRAMEBUFFER isn't modified by DRAW_COLORS
    std.mem.set(u8, w4.FRAMEBUFFER, 0xAA);
    std.mem.set(u8, crt.FRAMEBUFFER, 0xAA);
    fb_both.DRAW_COLORS(0x1234);
    try ts.assertEqualFBs("FRAMEBUFFER modified by DRAW_COLORS");
}

pub fn test_draw_primitives(ts: *TestState) InspectError!void {
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
                    try ts.assertEqualFBs(bufPrintZ("line: {},{} to {},{}", .{x, y, x2, y2}));
                }
            }

            // Sized
            var wi: usize = 0;
            while (wi < sizes.len) : (wi += 1) {
                const w = sizes[wi];

                fb_both.DRAW_COLORS(0x34);
                fb_both.hline(x, y, w);
                try ts.assertEqualFBs(bufPrintZ("hline: {},{} len {}", .{x, y, w}));
                fb_both.vline(x, y, w);
                try ts.assertEqualFBs(bufPrintZ("vline: {},{} len {}", .{x, y, w}));

                var hi: usize = 0;
                while (hi < sizes.len) : (hi += 1) {
                    const h = sizes[hi];

                    fb_both.DRAW_COLORS(0x4);
                    fb_both.rect(x, y, w, h);
                    try ts.assertEqualFBs(bufPrintZ("rect: {},{} {}x{}", .{x, y, w, h}));
                    fb_both.oval(x, y, w, h);
                    try ts.assertEqualFBs(bufPrintZ("oval: {},{} {}x{}", .{x, y, w, h}));

                    fb_both.DRAW_COLORS(0x34);
                    fb_both.rect(x, y, w, h);
                    try ts.assertEqualFBs(bufPrintZ("rect (outlined): {},{} {}x{}", .{x, y, w, h}));
                    fb_both.oval(x, y, w, h);
                    try ts.assertEqualFBs(bufPrintZ("oval (outlined): {},{} {}x{}", .{x, y, w, h}));
                }
            }
        }
    }

    // TODO: test transparency
    // TODO: test using invalid DRAW_COLORS
}

pub fn test_draw_text(ts: *TestState) InspectError!void {
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
            try ts.assertEqualFBs(bufPrintZ("text: charcode {}", .{i}));
            fb_both.textUtf8(text8Buf[0..1], 10, 10);
            try ts.assertEqualFBs(bufPrintZ("textUtf8: charcode {}", .{i}));
            fb_both.textUtf16(text16Buf[0..1], 10, 10);
            try ts.assertEqualFBs(bufPrintZ("textUtf16: charcode {}", .{i}));
        }
    }

    // text, textUtf8, textUtf16: newline
    fb_both.text("A\nB", 10, 10);
    try ts.assertEqualFBs("text: newline");
    fb_both.textUtf8("A\nB", 10, 10);
    try ts.assertEqualFBs("textUtf8: newline");
    fb_both.textUtf16(&[3]u16{ 'A', '\n', 'B' }, 10, 10);
    try ts.assertEqualFBs("textUtf16: newline");

    // text, textUtf8, textUtf16: respect null-terminator
    fb_both.text("A\x00B", 10, 10);
    try ts.assertEqualFBs("text: respect null-terminator");
    fb_both.textUtf8("A\x00B", 10, 10);
    try ts.assertEqualFBs("textUtf8: respect null-terminator");
    fb_both.textUtf16(&[3]u16{ 'A', 0, 'B' }, 10, 10);
    try ts.assertEqualFBs("textUtf16: respect null-terminator");

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
        try ts.assertEqualFBs("text: all charcodes, wrapped");
        fb_both.textUtf8(text8Buf[0..ai], 10, 10);
        try ts.assertEqualFBs("textUtf8: all charcodes, wrapped");
        fb_both.textUtf16(text16Buf[0..ai], 10, 10);
        try ts.assertEqualFBs("textUtf16: all charcodes, wrapped");
    }

    // text: OOB placements
    fb_both.text("@@@@@", -4, -4);
    try ts.assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", 156, -4);
    try ts.assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", -4, 156);
    try ts.assertEqualFBs("text: OOB");
    fb_both.text("@@@@@", 156, 156);
    try ts.assertEqualFBs("text: OOB");

    // textUtf16, invalid charcodes
    {
        var i: usize = 256;
        while (i < 65536) : (i += 2251) {
            w4.textUtf16(&[2]u16{ @intCast(u16, i), 0 }, 2, 10, 10);
            try ts.assertEqualFBs(bufPrintZ("textUtf16: invalid charcode {}", .{i}));
        }
    }
}

pub fn test_draw_blit(ts: *TestState) InspectError!void {
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
        try ts.assertEqualFBs(bufPrintZ("blit: 1bpp basic, flags: {}", .{flags}));
        fb_both.blit(&smiley_1bpp, 10, 10, 3, 3, w4.BLIT_1BPP | flags);
        try ts.assertEqualFBs(bufPrintZ("blit: 1bpp unaligned, flags: {}", .{flags}));
    }

    // TODO: blit 2bpp
    // TODO: blitSub
}

// Test persistency through `update`
pub fn test_update_persistance(ts: *TestState) InspectError!void {
    _ = ts;
    // TODO: FRAMEBUFFER persistance with/without SYSTEM_PRESERVE_FRAMEBUFFER
    // TODO: PALETTE persistance
    // TODO: DRAW_COLORS persistance
}
