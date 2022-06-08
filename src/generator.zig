const w4Native = @cImport({
    @cInclude("framebuffer.c");
});
const tester = @import("tester.zig");
const std = @import("std");

var _FRAMEBUFFER: [6400]u8 = undefined;
var _DRAW_COLORS: u8 = 0;

var w4 = struct {
    FRAMEBUFFER: *[6400]u8 = &_FRAMEBUFFER,
    DRAW_COLORS: *u8 = &_DRAW_COLORS,

    pub fn text(_: anytype, str: []const u8, x: i32, y: i32) void {
        w4Native.w4_framebufferText(str.ptr, x, y);
    }

    pub fn trace(_: anytype, str: []const u8) void {
        std.log.info("{s}", .{str});
    }

    // TODO: rest of API surface
}{};

fn init() void {
    w4Native.w4_framebufferInit(w4.DRAW_COLORS, w4.FRAMEBUFFER);
    w4Native.w4_framebufferClear();
}

pub fn main() anyerror!void {
    init();
    tester.run(w4);
}
