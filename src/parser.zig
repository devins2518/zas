const std = @import("std");
const errors = @import("errors.zig");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;
const ErrorMsg = errors.ErrorMsg;
const Tokenizer = token.Tokenizer;

const InnerError = error{ UnexpectedSymbol, UnexpectedOperand, ParseFail };

pub fn Parser(comptime instruction_set: []const type) type {
    _ = instruction_set;
    return struct {
        const Self = @This();

        alloc: Allocator,
        buf: []const u8,
        tokenizer: Tokenizer,
        err_msg: ?ErrorMsg = null,

        pub fn init(buf: []const u8, allocator: Allocator) Parser {
            return Parser{
                .buf = buf,
                .alloc = allocator,
                .tokenizer = Tokenizer.init(buf, allocator),
            };
        }

        pub fn parse(self: Self) !void {
            try self.tokenizer.tokenize();
        }
    };
}

const Loc = struct {
    start: usize,
    end: usize,
};

const Label = struct {
    instruction_start: Instruction.Index,
    loc: Loc,
};

// TODO: make generic over op enum
const Instruction = struct {
    op: []const u8,
    operands: []Operand.Index,
    loc: Loc,

    const Index = usize;
};

// TODO: make generic over register type
// TODO: add loc
const Operand = union(enum) {
    register: []const u8,
    immediate: i64,

    const Index = usize;
};
