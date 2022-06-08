const std = @import("std");
const tests = @import("tests.zig");

var passed: u8 = 0;
var failed: u8 = 0;

fn hashFramebuffer(fb: *[6400]u8) [4]u8 {
    var buf: [4]u8 = undefined;
    std.mem.writeIntLittle(u32, &buf, std.hash.CityHash32.hash(fb));
    return buf;
}

/// Hashes the current FRAMEBUFER
/// If this is ran from the generator, the hash stored as a temporary file
/// If this is ran from the cart, the hash is compared and evaluated
pub fn testFramebuffer(w4: anytype, comptime name: []const u8) void {
    comptime {
        for (name) |char| {
            if ((char < 'a' or char > 'z') and char != '_') {
                @compileError("Invalid step name: " ++ name);
            }
        }
    }

    const hash = hashFramebuffer(w4.FRAMEBUFFER);
    const isGenerator = @typeInfo(@TypeOf(w4)) == .Struct;
    if (isGenerator) {
        std.fs.cwd().writeFile("test-cache/" ++ name, &hash) catch {
            std.log.err("Failed to save test hash: {s}", .{name});
        };
        w4.trace("Saved step '" ++ name ++ "'...");
    } else {
        w4.trace("Running step '" ++ name ++ "'...");
        const compareHash = @embedFile("../test-cache/" ++ name);
        if (std.mem.eql(u8, &hash, compareHash)) {
            passed += 1;
        } else {
            w4.trace("- !!! Failed !!!");
            failed += 1;
        }
    }

    // Clean framebuffer after each test
    std.mem.set(u8, w4.FRAMEBUFFER, 0);
}

fn displayResults(w4: anytype) void {
    w4.PALETTE[0] = if (failed == 0) 0xaaffaa else 0xffaaaa;
    w4.PALETTE[1] = 0x222222;
    w4.DRAW_COLORS.* = 1;
    w4.rect(0, 0, 160, 160);
    w4.DRAW_COLORS.* = 2;
    var buf: [64]u8 = undefined;
    w4.text(std.fmt.bufPrintZ(&buf, "Tests passed: {}", .{passed}) catch unreachable, 10, 10);
    w4.text(std.fmt.bufPrintZ(&buf, "Tests failed: {}", .{failed}) catch unreachable, 10, 25);
}

pub fn run(w4: anytype) void {
    const isGenerator = @typeInfo(@TypeOf(w4)) == .Struct;
    if (isGenerator) {
        std.fs.cwd().makeDir("test-cache") catch {};
    } else {
        w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;
    }
    tests.run(w4);
    if (!isGenerator) {
        displayResults(w4);
    }
}
