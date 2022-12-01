const std = @import("std");

const WasmOptStep = @This();

step: std.build.Step,
builder: *std.build.Builder,
source: std.build.FileSource,
output_file: std.build.GeneratedFile,

pub fn create(builder: *std.build.Builder, source: std.build.FileSource) *WasmOptStep {
    const self = builder.allocator.create(WasmOptStep) catch unreachable;
    self.* = WasmOptStep{
        .step = std.build.Step.init(.custom, "WasmOptStep", builder.allocator, make),
        .builder = builder,
        .source = source,
        .output_file = std.build.GeneratedFile{ .step = &self.step },
    };
    return self;
}

pub fn getOutputFile(self: *WasmOptStep) std.build.FileSource {
    return std.build.FileSource{ .generated = &self.output_file };
}

pub fn make(step: *std.build.Step) !void {
    const self = @fieldParentPtr(WasmOptStep, "step", step);

    const infile = self.source.getPath(self.builder);
    const infileExt = std.fs.path.extension(infile);
    const infileNoExt = infile[0..infile.len - infileExt.len];
    const outfile = std.fs.path.join(self.builder.allocator, &[_][]const u8{
        "zig-out",
        std.fmt.allocPrint(self.builder.allocator, "{s}.opt.wasm", .{
            std.fs.path.basename(infileNoExt),
        }) catch unreachable
    }) catch unreachable;

    _ = try self.builder.execFromStep(&[_][]const u8{
        "wasm-opt",
        "-Oz",
        "--zero-filled-memory",
        "--dce", "--converge", "--coalesce-locals-learning",
        "--strip-producers", "--strip-debug", "--strip-dwarf",
        infile, "-o", outfile
    }, &self.step);

    self.output_file.path = outfile;
}