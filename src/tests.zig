const tester = @import("tester.zig");
pub fn run(w4: anytype) void {
    tester.testFramebuffer(w4, "blank");

    // First test
    w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);
    tester.testFramebuffer(w4, "hello_world");

    // Second test
    w4.DRAW_COLORS.* = 3;
    w4.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", -10, 10);
    tester.testFramebuffer(w4, "long_text");
}
