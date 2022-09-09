const w4 = @import("wasm4.zig");
const tests = @import("tests.zig");
const tester = @import("tester.zig");

export fn start() void {
    w4.PALETTE[0] = 0xffffff;
    w4.PALETTE[1] = 0xcccccc;
    w4.PALETTE[2] = 0x888888;
    w4.PALETTE[3] = 0x111111;
    w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;

    w4.trace("Starting test runner...");
    tester.init();
    _ = async tests.run();
    w4.trace("Done!");
    w4.tracef("Passed: %d", tester.passed);
    w4.tracef("Failed: %d", tester.failed);

    if (tester.failed > 0) {
        w4.PALETTE[0] = 0xffcccc;
        tester.init();
        tester.suspendOnFail = true;
        _ = async tests.run();
    } else {
        w4.PALETTE[0] = 0xccffcc;
    }
}

var didPress = false;
export fn update() void {
    if (w4.GAMEPAD1.* & w4.BUTTON_1 > 0) {
        if (!didPress and tester.suspendFrame != null) {
            resume tester.suspendFrame.?;
            if (tester.suspendFrame == null) {
                w4.trace("Done!");
                w4.PALETTE[0] = 0xffffcc;
            }
        }
        didPress = true;
    } else {
        didPress = false;
    }
}
