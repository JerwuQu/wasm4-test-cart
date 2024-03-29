const w4 = @import("../wasm4.zig");
const fbC = @cImport({
    @cInclude("crt/memset.c");
    @cInclude("crt/util.c");
    @cInclude("crt/framebuffer.c");
});

var _FRAMEBUFFER: [6400]u8 = undefined;
var _DRAW_COLORS: u16 = 0;

pub const FRAMEBUFFER: *[6400]u8 = &_FRAMEBUFFER;
pub const DRAW_COLORS: *u16 = &_DRAW_COLORS;

pub fn init() void {
    fbC.w4_framebufferInit(@ptrCast(*u8, DRAW_COLORS), FRAMEBUFFER);
    fbC.w4_framebufferClear();
}

pub fn hline(x: i32, y: i32, len: u32) void {
    fbC.w4_framebufferHLine(x, y, @intCast(c_int, len));
}

pub fn vline(x: i32, y: i32, len: u32) void {
    fbC.w4_framebufferVLine(x, y, @intCast(c_int, len));
}

pub fn rect(x: i32, y: i32, width: u32, height: u32) void {
    fbC.w4_framebufferRect(x, y, @intCast(c_int, width), @intCast(c_int, height));
}

pub fn line(x1: i32, y1: i32, x2: i32, y2: i32) void {
    fbC.w4_framebufferLine(x1, y1, x2, y2);
}

pub fn oval(x: i32, y: i32, width: u32, height: u32) void {
    fbC.w4_framebufferOval(x, y, @intCast(c_int, width), @intCast(c_int, height));
}

pub fn text(str: [*]const u8, x: i32, y: i32) void {
    fbC.w4_framebufferText(str, x, y);
}

pub fn textUtf8(strPtr: [*]const u8, strLen: usize, x: i32, y: i32) void {
    fbC.w4_framebufferTextUtf8(strPtr, @intCast(c_int, strLen), x, y);
}

pub fn textUtf16(strPtr: [*]const u16, strLen: usize, x: i32, y: i32) void {
    fbC.w4_framebufferTextUtf16(strPtr, @intCast(c_int, strLen), x, y);
}

pub fn blit(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, flags: u32) void {
    blitSub(sprite, x, y, width, height, 0, 0, width, flags);
}

pub fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, src_x: u32, src_y: u32, stride: u32, flags: u32) void {
    // https://github.com/aduros/wasm4/blob/1a8b9dedaeae3258f0c68134f9c377bb2b89682d/runtimes/native/src/runtime.c#L80
    const bpp2: bool = (flags & w4.BLIT_2BPP) != 0;
    const flipX: bool = (flags & w4.BLIT_FLIP_X) != 0;
    const flipY: bool = (flags & w4.BLIT_FLIP_Y) != 0;
    const rotate: bool = (flags & w4.BLIT_ROTATE) != 0;
    fbC.w4_framebufferBlit(sprite, x, y, @intCast(c_int, width), @intCast(c_int, height), @intCast(c_int, src_x), @intCast(c_int, src_y), @intCast(c_int, stride), bpp2, flipX, flipY, rotate);
}
