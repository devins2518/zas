const std = @import("std");
const Allocator = std.mem.Allocator;

// Taken from Zig compiler internals
pub const ErrorMsg = struct {
    msg: []const u8,

    pub fn init(gpa: Allocator, comptime format: []const u8, args: anytype) !ErrorMsg {
        return ErrorMsg{ .msg = try std.fmt.allocPrint(gpa, format, args) };
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with `gpa`,
    /// as well as all notes.
    pub fn destroy(err_msg: *const ErrorMsg, gpa: Allocator) void {
        gpa.free(err_msg.msg);
    }
};
