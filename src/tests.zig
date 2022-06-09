const tester = @import("main.zig");

fn texts(w4: anytype) void {
    var i: i32 = -160;
    while (i < 320) : (i += 1) {
        w4.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", i, 30);
        w4.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", 30, i);
        w4.text("A VERY VERY VERY VERY VERY VERY VERY VERY LONG TEXT", i, i);
        suspend {}
        tester.testTrace("Ayo", .{});
    }
}

fn rects(w4: anytype) void {
    var i: i32 = -160;
    while (i < 320) : (i += 1) {
        w4.rect(i, i, 10, 10);
        w4.rect(i, i, 32, 32);
        w4.rect(i, i, 1000, 3);
        w4.rect(i, i, 3, 1000);
        suspend {}
    }
}

fn ovals(w4: anytype) void {
    var i: i32 = -160;
    while (i < 320) : (i += 1) {
        w4.oval(i, i, 10, 10);
        w4.oval(i, i, 32, 32);
        w4.oval(i, i, 1000, 3);
        w4.oval(i, i, 3, 1000);
        suspend {}
    }
}

pub fn run() void {
    tester.addTest(texts, "Texts");
    tester.addTest(ovals, "Rects");
    tester.addTest(ovals, "Ovals");
}
