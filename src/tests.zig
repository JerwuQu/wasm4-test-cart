const w4 = @import("wasm4.zig");
const tester = @import("tester.zig");

fn testTexts() void {
    tester.setDrawColors(4);

    tester.text("Hello from Zig!", 10, 10);
    tester.text("Hello from Zig!", w4.SCREEN_SIZE, 10);
    tester.assertClear(@src(), 0);

    tester.text("A VERY VERY VERY VERY VERY\nVERY VERY VERY LONG TEXT", -10, 10);
    tester.assertClear(@src(), 0);

    var buf: [1]u8 = undefined;
    buf[0] = 0;
    while (buf[0] < 255) : (buf[0] += 1) {
        tester.text(&buf, 10, 10);
        tester.assertClear(@src(), buf[0]);
    }
}

pub fn run() void {
    testTexts();
}
