const std = @import("std");
pub const Parser = @import("riscv.zig").RiscvParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var allocator = gpa.allocator();

    var arg_iter = try std.process.argsWithAllocator(allocator);
    defer arg_iter.deinit();

    _ = arg_iter.skip();
    const file_name = arg_iter.next().?;
    const file = try std.fs.cwd().openFile(file_name, .{});
    const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    var parser = Parser.init(file_contents, allocator);
    defer parser.deinit();
    parser.parse() catch |e| {
        parser.report();
        return e;
    };

    for (parser.tokenizer.tokens.items) |i| {
        std.debug.print("{} ", .{i});
    }
}

test {
    _ = @import("Instruction.zig");
    _ = @import("riscv.zig");
    std.testing.refAllDeclsRecursive(@This());
}
