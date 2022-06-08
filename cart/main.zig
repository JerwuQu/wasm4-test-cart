const w4 = @import("wasm4.zig");
const tester = @import("tester");

export fn start() void {
    tester.run(w4);
}
