const std = @import("std");
const assert = std.debug.assert;
const errors = @import("errors.zig");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;
const ComptimeStringMap = std.ComptimeStringMap;
const ErrorMsg = errors.ErrorMsg;
const Instruction = @import("Instruction.zig");
const Tokenizer = token.Tokenizer;
const TokenKind = token.TokenKind;

const InnerError = ErrorMsg.Error || error{ UnexpectedSymbol, UnexpectedOperand, ParseFail };

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

                var instruction_found = false;
                // TODO: set up comptime string map with function pointer payload for runtime call
                inline for (instruction_set) |Instr| {
                    var i: Instr = undefined;
                    if (std.mem.eql(u8, i.name, instruction_mneumonic)) {
                        instruction_found = true;
                        const style = i.parse_style;
                        comptime var style_idx = 0;
                        inline while (style_idx < style.len) {
                            switch (style[style_idx]) {
                                ' ' => {
                                    style_idx += 1;
                                },
                                ',' => {
                                    _ = try self.expectToken(&token_idx, .comma);
                                    style_idx += 1;
                                },
                                '{' => if (style[style_idx + 1] == '{') {
                                    _ = try self.expectToken(&token_idx, .l_brace);
                                    style_idx += 1;
                                } else {
                                    const end = comptime std.mem.indexOfScalarPos(u8, style, style_idx, '}') orelse
                                        @compileError("Expected closing '}' in: " ++ style[style_idx]);

                                    const field_name = style[style_idx + 1 .. end];
                                    const FieldType = @TypeOf(@field(i, field_name));
                                    const field_type_info = @typeInfo(FieldType);

                                    switch (field_type_info) {
                                        .Enum => {
                                            const variant = try self.expectToken(&token_idx, .ident);
                                            if (std.meta.stringToEnum(FieldType, variant)) |e|
                                                @field(i, field_name) = e
                                            else
                                                return self.fail("Unknown {s} variant: {s}", .{ field_name, variant });
                                        },
                                        .Pointer => |ptr_info| {
                                            if (ptr_info.size != .Many and ptr_info.child != u8)
                                                @compileError("Unable to parse pointer type " ++ @typeName(FieldType));

                                            const ident = try self.expectToken(&token_idx, .ident);
                                            if (!std.mem.eql(u8, ident, @field(i, field_name)))
                                                return self.fail("Expected \"{s}\", found \"{s}\"!", .{ @field(i, field_name), ident });
                                        },
                                        .Int => |int_info| {
                                            const int_string = try self.expectToken(&token_idx, .integer);
                                            const int = std.fmt.parseInt(FieldType, int_string, 0) catch |e| switch (e) {
                                                error.Overflow => return self.fail(
                                                    "{s} does not fit into a {} width integer (range [{}..{}])",
                                                    .{ int_string, int_info.bits, std.math.minInt(FieldType), std.math.maxInt(FieldType) },
                                                ),
                                                error.InvalidCharacter => return self.fail(
                                                    "Unexpected character in integer, this is a bug in the assembly tokenizer! Source: \"{s}\"",
                                                    .{int_string},
                                                ),
                                            };
                                            @field(i, field_name) = int;
                                        },
                                        else => unreachable,
                                    }

                                    style_idx = end + 1;
                                },
                                else => unreachable,
                            }
                        }

                        try self.binary.append(self.alloc, Instruction.toBytes(Instr, i));
                    }
                }
                if (!instruction_found) return self.fail("Unknown instruction: {s}", .{instruction_mneumonic});
            }
        }

        pub fn report(self: *Self) void {
            assert(self.err_msg != null);
            std.debug.print("{s}\n", .{self.err_msg.?.msg});
        }

        fn expectToken(self: *Self, token_idx: *usize, kind: TokenKind) ![]const u8 {
            const t = self.tokenizer.tokens.items[token_idx.*];
            if (t.kind == kind) {
                token_idx.* += 1;
                return t.src;
            } else return self.fail("Unexpected parser token of kind {s}: {s}. Expected {s}.", .{ @tagName(t.kind), t.src, @tagName(kind) });
        }

        fn fail(self: *Self, comptime format: []const u8, args: anytype) InnerError {
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
