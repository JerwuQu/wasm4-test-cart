const w4 = @import("wasm4.zig");
const tests = @import("tests.zig");
const tester = @import("tester.zig");

export fn start() void {
    w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;
    w4.trace("Starting test runner...");
    tester.init();
    tests.run();
    w4.trace("Done!");
    w4.tracef("Passed: %d", tester.passed);
    w4.tracef("Failed: %d", tester.failed);
}
