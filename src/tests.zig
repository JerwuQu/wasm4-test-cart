const w4 = @import("wasm4.zig");
const tester = @import("tester.zig");

fn testTexts() void {
    tester.setDrawColors(0x34);

    tester.text("Hello from Zig!", 10, 10);
    tester.text("Hello from Zig!", w4.SCREEN_SIZE - 10, 30);
    tester.text("Hello from Zig!", 10, w4.SCREEN_SIZE - 60);
    tester.assert(@src(), 0);

    tester.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", -10, 10);
    tester.text("A VERY VERY VERY VERY VERY\nVERY VERY VERY LONG TEXT", -10, 50);
    tester.assert(@src(), 0);

    var buf: [1]u8 = undefined;
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        buf[0] = @intCast(u8, i);
        tester.text(&buf, 10, 10);
        tester.assert(@src(), buf[0]);
    }
}

pub fn run() void {
    testTexts();
}
