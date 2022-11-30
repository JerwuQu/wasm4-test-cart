const std = @import("std");
const w4 = @import("wasm4.zig");

fn assertEqual(a: anytype, b: @TypeOf(a)) void {
    if (a != b) {
        //var buf: [512]u8 = undefined;
        //w4.trace(std.fmt.bufPrint(&buf, "Oh no... 0x{x} 0x{x}", .{a, b}) catch unreachable);
        w4.trace("Failed");
    }
}

fn assertFilledWith(buf: []const u8, value: u8) void {
    for (buf) |c| {
        if (c != value) {
            w4.trace("Failed");
            return;
        }
    }
}

// Test initial memory state
fn test_initial_memory() void {
    // PALETTE
    assertEqual(w4.PALETTE[0], 0xe0f8cf);
    assertEqual(w4.PALETTE[1], 0x86c06c);
    assertEqual(w4.PALETTE[2], 0x306850);
    assertEqual(w4.PALETTE[3], 0x071821);

    // DRAW_COLORS
    assertEqual(w4.DRAW_COLORS.*, 0x1203);

    // SYSTEM_FLAGS
    assertEqual(w4.SYSTEM_FLAGS.*, 0);

    // FRAMEBUFFER
    assertFilledWith(w4.FRAMEBUFFER, 0);
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

    // Single byte (sz = 1)
    std.mem.set(u8, &bufIn, BYTE_UNUSED_IN);
    bufIn[0] = BYTE_COPIED;
    assertEqual(w4.diskw(&bufIn, 1), 1);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assertEqual(w4.diskr(&bufOut, 1), 1);
    assertEqual(bufOut[0], BYTE_COPIED);
    assertFilledWith(bufOut[1..], BYTE_UNUSED_OUT);

    // Max size disk (sz = 1024)
    std.mem.set(u8, bufIn[0..DISK_MAX], BYTE_COPIED);
    std.mem.set(u8, bufIn[DISK_MAX..], BYTE_UNUSED_IN);
    assertEqual(w4.diskw(&bufIn, DISK_MAX), DISK_MAX);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assertEqual(w4.diskr(&bufOut, DISK_MAX), DISK_MAX);
    assertFilledWith(bufOut[0..DISK_MAX], BYTE_COPIED);
    assertFilledWith(bufOut[DISK_MAX..], BYTE_UNUSED_OUT);

    // Overflowing disk (sz = 2048)
    std.mem.set(u8, &bufIn, BYTE_COPIED);
    assertEqual(w4.diskw(&bufIn, DISK_MAX_2), DISK_MAX);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assertEqual(w4.diskr(&bufOut, DISK_MAX_2), DISK_MAX);
    assertFilledWith(bufOut[0..DISK_MAX], BYTE_COPIED);
    assertFilledWith(bufOut[DISK_MAX..], BYTE_UNUSED_OUT);
}

// Test persistency through `update`
fn test_update_persistance() void {
    // TODO: Framebuffer persistance with/without SYSTEM_PRESERVE_FRAMEBUFFER
    // TODO: PALETTE persistance
    // TODO: DRAW_COLORS persistance
}

// Test framebuffer manipulation
fn test_draw_operations() void {
    // TODO: everything
    // - blit
    // - blitSub
    // - text
    // etc...
}

export fn start() void {
    w4.trace("gfx-test-cart started");
    test_initial_memory();
    test_disk();
    test_update_persistance();
    test_draw_operations();
    w4.trace("gfx-test-cart finished");
}

export fn update() void {}
