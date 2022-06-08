const w4 = @import("wasm4.zig");
const tester = @import("tester.zig");

export fn start() void {
    tester.run(w4);
}
