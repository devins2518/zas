const std = @import("std");
const assert = std.debug.assert;
const errors = @import("errors.zig");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;
const ComptimeStringMap = std.ComptimeStringMap;
const ErrorMsg = errors.ErrorMsg;
const Instruction = @import("Instruction.zig");
const Tokenizer = token.Tokenizer;

const InnerError = error{ UnexpectedSymbol, UnexpectedOperand, ParseFail };

pub fn Parser(comptime instruction_set: []const type) type {
    for (instruction_set) |instruction| assert(Instruction.instructionHasProperForm(instruction));
    return struct {
        const Self = @This();
        // Mapping of instruction name to parse_style
        const instruction_names = blk: {
            const CSMType = struct { []const u8, []const u8 };
            var names: []const CSMType = &.{};
            for (instruction_set) |Instr| {
                const instr: Instr = undefined;
                names = names ++ &[_]CSMType{.{ instr.name, instr.parse_style }};
            }
            break :blk ComptimeStringMap([]const u8, names);
        };

        alloc: Allocator,
        buf: []const u8,
        tokenizer: Tokenizer,
        err_msg: ?ErrorMsg = null,
        binary: std.ArrayListUnmanaged(u32) = .{},

        pub fn init(buf: []const u8, allocator: Allocator) Self {
            return Self{
                .buf = buf,
                .alloc = allocator,
                .tokenizer = Tokenizer.init(buf, allocator),
            };
        }

        pub fn parse(self: *Self) !void {
            try self.tokenizer.tokenize();

            const tokens = self.tokenizer.tokens.items;
            var token_idx: usize = 0;
            while (token_idx < tokens.len) {
                // Starting statement
                const first_token = tokens[token_idx];
                const instruction_mneumonic = if (first_token.kind == .ident)
                    first_token.src
                else
                    return self.fail("Unexpected token: {s}", .{first_token.src});
                token_idx += 1;

                if (instruction_names.get(instruction_mneumonic)) |style| {
                    // TODO: style is parsed at runtime
                    const style_idx = (std.mem.indexOfScalar(u8, style, '}') orelse
                        return self.fail("Could not parse parse_style: {s}", .{style})) + 1;

                    while (style_idx < style.len) {
                        const kind = switch (style[style_idx]) {
                            ' ' => .space,
                            else => {},
                        };
                        _ = kind;
                    }
                } else try self.fail("Unknown instruction: {s}", .{instruction_mneumonic});
            }
        }

        fn fail(self: *Self, comptime format: []const u8, args: anytype) !void {
            @setCold(true);
            assert(self.err_msg == null);
            self.err_msg = try ErrorMsg.init(self.alloc, format, args);
            return error.ParseFail;
        }

        pub fn deinit(self: *Self) void {
            self.tokenizer.deinit();
            self.binary.deinit(self.alloc);
            if (self.err_msg) |e| e.destroy(self.alloc);
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
