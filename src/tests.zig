const tester = @import("main.zig");

fn testHelloWorld(w4: anytype) void {
    w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);
    w4.text("Hello from Zig!", w4.SCREEN_SIZE, 10);
}

fn testLongString(w4: anytype) void {
    w4.DRAW_COLORS.* = 3;
    w4.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", -10, 10);
}

pub fn run() void {
    tester.addTest(testHelloWorld, "Hello World");
    tester.addTest(testLongString, "Long String");
}
