const w4 = @import("wasm4.zig");
const crt = @import("crt/crt.zig");

pub fn DRAW_COLORS(colors: u16) void {
    w4.DRAW_COLORS.* = colors;
    crt.DRAW_COLORS.* = colors;
}

pub fn hline(x: i32, y: i32, len: u32) void {
    w4.hline(x, y, len);
    crt.hline(x, y, len);
}

pub fn vline(x: i32, y: i32, len: u32) void {
    w4.vline(x, y, len);
    crt.vline(x, y, len);
}

pub fn rect(x: i32, y: i32, width: u32, height: u32) void {
    w4.rect(x, y, width, height);
    crt.rect(x, y, width, height);
}

pub fn line(x1: i32, y1: i32, x2: i32, y2: i32) void {
    w4.line(x1, y1, x2, y2);
    crt.line(x1, y1, x2, y2);
}

pub fn oval(x: i32, y: i32, width: u32, height: u32) void {
    w4.oval(x, y, width, height);
    crt.oval(x, y, width, height);
}

pub fn text(str: [*]const u8, x: i32, y: i32) void {
    w4.text(str, x, y);
    crt.text(str, x, y);
}

pub fn textUtf8(str: []const u8, x: i32, y: i32) void {
    w4.textUtf8(str.ptr, str.len, x, y);
    crt.textUtf8(str, x, y);
}

pub fn textUtf16(str: []const u16, x: i32, y: i32) void {
    w4.textUtf16(str.ptr, str.len, x, y);
    crt.textUtf16(str, x, y);
}

pub fn blit(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, flags: u32) void {
    w4.blit(sprite, x, y, width, height, flags);
    crt.blit(sprite, x, y, width, height, flags);
}

pub fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, src_x: u32, src_y: u32, stride: u32, flags: u32) void {
    w4.blitSub(sprite, x, y, width, height, src_x, src_y, stride, flags);
    crt.blitSub(sprite, x, y, width, height, src_x, src_y, stride, flags);
}
