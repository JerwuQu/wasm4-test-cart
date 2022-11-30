const std = @import("std");
const w4 = @import("wasm4.zig");

var testState = struct {
    passed: usize = 0,
    failed: usize = 0,
}{};

fn assertFailed(comptime src: std.builtin.SourceLocation) void {
    w4.tracef("!!! Failed: %s (line %d)", src.fn_name.ptr, src.line);
    testState.failed += 1;
}

fn assert(comptime src: std.builtin.SourceLocation, condition: bool) void {
    if (condition) {
        testState.passed += 1;
    } else {
        assertFailed(src);
    }
}

fn assertFilled(comptime src: std.builtin.SourceLocation, buf: []const u8, value: u8) void {
    for (buf) |c| {
        if (c != value) {
            assertFailed(src);
            return;
        }
    }
    testState.passed += 1;
}

// Test initial memory state
fn test_initial_memory() void {
    // PALETTE
    assert(@src(), w4.PALETTE[0] == 0xe0f8cf);
    assert(@src(), w4.PALETTE[1] == 0x86c06c);
    assert(@src(), w4.PALETTE[2] == 0x306850);
    assert(@src(), w4.PALETTE[3] == 0x071821);

    // DRAW_COLORS
    assert(@src(), w4.DRAW_COLORS.* == 0x1203);

    // SYSTEM_FLAGS
    assert(@src(), w4.SYSTEM_FLAGS.* == 0);

    // FRAMEBUFFER
    assertFilled(@src(), w4.FRAMEBUFFER, 0);
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
    assert(@src(), w4.diskw(&bufIn, 1) == 1);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assert(@src(), w4.diskr(&bufOut, 1) == 1);
    assert(@src(), bufOut[0] == BYTE_COPIED);
    assertFilled(@src(), bufOut[1..], BYTE_UNUSED_OUT);

    // Max size disk (sz = 1024)
    std.mem.set(u8, bufIn[0..DISK_MAX], BYTE_COPIED);
    std.mem.set(u8, bufIn[DISK_MAX..], BYTE_UNUSED_IN);
    assert(@src(), w4.diskw(&bufIn, DISK_MAX) == DISK_MAX);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assert(@src(), w4.diskr(&bufOut, DISK_MAX) == DISK_MAX);
    assertFilled(@src(), bufOut[0..DISK_MAX], BYTE_COPIED);
    assertFilled(@src(), bufOut[DISK_MAX..], BYTE_UNUSED_OUT);

    // Overflowing disk (sz = 2048)
    std.mem.set(u8, &bufIn, BYTE_COPIED);
    assert(@src(), w4.diskw(&bufIn, DISK_MAX_2) == DISK_MAX);

    std.mem.set(u8, &bufOut, BYTE_UNUSED_OUT);
    assert(@src(), w4.diskr(&bufOut, DISK_MAX_2) == DISK_MAX);
    assertFilled(@src(), bufOut[0..DISK_MAX], BYTE_COPIED);
    assertFilled(@src(), bufOut[DISK_MAX..], BYTE_UNUSED_OUT);
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

    // TODO: allow for inspecting failed tests visually
}

export fn start() void {
    w4.trace("Test suite started");
    test_initial_memory();
    test_disk();
    test_update_persistance();
    test_draw_operations();

    w4.tracef("Passed: %d", testState.passed);
    w4.tracef("Failed: %d", testState.failed);
    if (testState.failed == 0) {
        w4.PALETTE[0] = 0x88ff88;
    } else {
        w4.PALETTE[0] = 0xff8888;
    }
}

export fn update() void {}
