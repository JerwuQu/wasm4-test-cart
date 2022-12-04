const std = @import("std");
const w4 = @import("wasm4.zig");
const crt = @import("crt/crt.zig");

const TERM_COLOR_RESET = "\x1b[0m";
const TERM_COLOR_RED = "\x1b[31m";
const TERM_COLOR_GREEN = "\x1b[32m";
const TERM_COLOR_YELLOW = "\x1b[33m";
const TERM_COLOR_BLUE = "\x1b[34m";

// This is not actually an error, but used as a convenient way to unroll
// This gives us the ability to essentially breakpoint and visually inspect what went wrong
pub const InspectError = error {inspect};

const Test = struct {
    name: []const u8,
    func: *const fn(*TestState) InspectError!void,
};

pub const TestState = struct {
    tst: *const Test,
    passed: usize = 0,
    failed: usize = 0,
    inspecting: ?usize = null,

    pub fn assert(this: *@This(), condition: bool, ctx: []const u8) InspectError!void {
        if (condition) {
            this.passed += 1;
        } else {
            const ctxPtr = if (ctx.len == 0) "<unnamed>" else ctx.ptr;
            if (this.inspecting == null) {
                w4.tracef(TERM_COLOR_RED ++ "- Failed assertion [#%d]: %s " ++ TERM_COLOR_RESET, this.failed + 1, ctxPtr);
            } else if (this.inspecting.? == this.failed) {
                w4.tracef(TERM_COLOR_BLUE ++ "- Inspecting failed assertion [#%d]: " ++ TERM_COLOR_RESET ++ "%s", this.failed + 1, ctxPtr);
                return InspectError.inspect;
            }
            this.failed += 1;
        }
    }

    pub fn assertEqualFBs(this: *@This(), ctx: []const u8) InspectError!void {
        try this.assert(std.mem.eql(u8, w4.FRAMEBUFFER, crt.FRAMEBUFFER), ctx);
        std.mem.set(u8, w4.FRAMEBUFFER, 0);
        std.mem.set(u8, crt.FRAMEBUFFER, 0);
    }
};

var testsOK = false;

// List of all `test_` functions
const tests: []const Test = blk: {
    const testsuite = @import("testsuite.zig");
    const this: std.builtin.Type.Struct = @typeInfo(testsuite).Struct;
    var btests: []const Test = &.{};
    for (this.decls) |decl| {
        if (decl.is_pub) {
            const field = @field(testsuite, decl.name);
            btests = btests ++ [_]Test{.{
                .name = decl.name,
                .func = field,
            }};
        }
    }
    break :blk btests;
};
var testStates: [tests.len]TestState = undefined;

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

pub fn bufPrintZ(comptime fmt: []const u8, args: anytype) []u8 {
    const state = struct {
        var buf: [64:0]u8 = undefined;
    };
    return std.fmt.bufPrintZ(&state.buf, fmt, args) catch unreachable;
}

export fn start() void {
    // Cookie used to detect memory corruption - See build.zig
    const COOKIE = 0x0F1E2D3C;
    const memoryStartCookiePtr = @intToPtr(*volatile u32, 6560);
    memoryStartCookiePtr.* = COOKIE;

    w4.trace(TERM_COLOR_BLUE ++ "Test suite starting..." ++ TERM_COLOR_RESET);

    // Call each test function, logging failed assertions as we go
    var totalPassed: usize = 0;
    var totalFailed: usize = 0;
    for (tests) |*tst, i| {
        testStates[i] = TestState{.tst = tst};
        w4.tracef(TERM_COLOR_YELLOW ++ "> %s..." ++ TERM_COLOR_RESET, tst.name.ptr);
        tst.func(&testStates[i]) catch unreachable;
        totalPassed += testStates[i].passed;
        totalFailed += testStates[i].failed;
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
    const state = struct {
        var lastPad: u32 = 0;
    };
    const pad = w4.GAMEPAD1.*;
    const padPressed = (pad ^ state.lastPad) & pad;
    state.lastPad = pad;

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
                // TODO: add `isVisualTest: bool` in `Test` struct?
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
                var ok = false;
                std.mem.set(u8, w4.FRAMEBUFFER, 0);
                std.mem.set(u8, crt.FRAMEBUFFER, 0);
                tests[v.testI].func(&testState) catch {ok = true;};
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
