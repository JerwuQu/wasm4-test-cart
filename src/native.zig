const fbC = @cImport({
    @cInclude("framebuffer.c");
});

var _FRAMEBUFFER: [6400]u8 = undefined;
var _DRAW_COLORS: u16 = 0;

pub const w4 = struct {
    pub const SCREEN_SIZE: u32 = 160;

    pub const BLIT_2BPP: u32 = 1;
    pub const BLIT_1BPP: u32 = 0;
    pub const BLIT_FLIP_X: u32 = 2;
    pub const BLIT_FLIP_Y: u32 = 4;
    pub const BLIT_ROTATE: u32 = 8;

    pub const FRAMEBUFFER: *[6400]u8 = &_FRAMEBUFFER;
    pub const DRAW_COLORS: *u16 = &_DRAW_COLORS;

    pub fn hline(x: i32, y: i32, len: u32) void {
        fbC.w4_framebufferHLine(x, y, len);
    }

    pub fn vline(x: i32, y: i32, len: u32) void {
        fbC.w4_framebufferVLine(x, y, len);
    }

    pub fn rect(x: i32, y: i32, width: u32, height: u32) void {
        fbC.w4_framebufferRect(x, y, width, height);
    }

    pub fn line(x1: i32, y1: i32, x2: i32, y2: i32) void {
        fbC.w4_framebufferLine(x1, y1, x2, y2);
    }

    pub fn oval(x: i32, y: i32, width: i32, height: i32) void {
        fbC.w4_framebufferOval(x, y, width, height);
    }

    pub fn text(str: []const u8, x: i32, y: i32) void {
        fbC.w4_framebufferTextUtf8(str.ptr, @intCast(c_int, str.len), x, y);
    }

    pub fn blit(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, flags: u32) void {
        w4.blitSub(sprite, x, y, width, height, 0, 0, width, flags);
    }

    pub fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, src_x: u32, src_y: u32, stride: i32, flags: u32) void {
        // https://github.com/aduros/wasm4/blob/1a8b9dedaeae3258f0c68134f9c377bb2b89682d/runtimes/native/src/runtime.c#L80
        const bpp2: bool = (flags & 1);
        const flipX: bool = (flags & 2);
        const flipY: bool = (flags & 4);
        const rotate: bool = (flags & 8);
        fbC.w4_framebufferBlit(sprite, x, y, width, height, src_x, src_y, stride, bpp2, flipX, flipY, rotate);
    }
};

pub fn init() void {
    fbC.w4_framebufferInit(@ptrCast([*c]const u8, w4.DRAW_COLORS), w4.FRAMEBUFFER);
    fbC.w4_framebufferClear();
}
