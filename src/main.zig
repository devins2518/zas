const std = @import("std");
pub const Parser = @import("parser.zig").Parser;

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
    try parser.parse();

    for (parser.instructions.items) |i| {
        std.debug.print("{s} ", .{i.op});
        for (i.operands) |op| {
            switch (parser.operands.items[op]) {
                .register => |reg| std.debug.print("{s}, ", .{reg}),
                .immediate => |imm| std.debug.print("{}, ", .{imm}),
            }
        }
        std.debug.print("\n", .{});
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
