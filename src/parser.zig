const std = @import("std");
const errors = @import("errors.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ErrorMsg = errors.ErrorMsg;

const InnerError = error{ UnexpectedSymbol, UnexpectedOperand, ParseFail };

pub const Parser = struct {
    alloc: Allocator,
    buf: []const u8,
    pos: usize = 0,
    labels: ArrayListUnmanaged(Label) = .{},
    operands: ArrayListUnmanaged(Operand) = .{},
    instructions: ArrayListUnmanaged(Instruction) = .{},
    err_msg: ?ErrorMsg = null,

    pub fn init(buf: []const u8, allocator: Allocator) Parser {
        return Parser{ .alloc = allocator, .buf = buf, .pos = 0 };
    }

    pub fn parse(self: *Parser) !void {
        const State = enum {
            start_of_line,
            instruction_identifier,
            start_of_operand,
            end_of_operand,
            operand_identifier,
            number,
        };

        var operand_idx_list = ArrayListUnmanaged(Operand.Index){};
        defer operand_idx_list.deinit(self.alloc);
        var state: State = .start_of_line;
        var start: usize = undefined;

        while (self.pos != self.buf.len) {
            const c = self.buf[self.pos];
            switch (state) {
                .start_of_line => switch (c) {
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .instruction_identifier;
                        start = self.pos;
                    },
                    else => if (!std.ascii.isWhitespace(c)) {
                        return self.fail("Unexpected token: {}", .{c});
                    } else {
                        self.pos += 1;
                    },
                },
                .instruction_identifier => if (!std.ascii.isAlphanumeric(c) and c != '_') {
                    try self.instructions.append(self.alloc, .{
                        .op = self.buf[start..self.pos],
                        .operands = &.{},
                        .loc = .{ .start = start, .end = self.pos },
                    });
                    state = .start_of_operand;
                } else {
                    self.pos += 1;
                },
                .start_of_operand => {
                    self.untilNonWhitespace() orelse return;
                    state = if (std.ascii.isDigit(self.buf[self.pos]))
                        .number
                    else
                        .operand_identifier;
                    start = self.pos;
                    self.pos += 1;
                },
                .end_of_operand => {
                    if (c != '\n') {
                        try self.expect(',');
                        state = .start_of_operand;
                    } else {
                        if (operand_idx_list.items.len > 0)
                            self.instructions.items[self.instructions.items.len - 1].operands =
                                try operand_idx_list.toOwnedSlice(self.alloc);
                        state = .start_of_line;
                    }
                },
                .number => {
                    if (self.pos == start + 1 and !std.ascii.isDigit(c)) {
                        switch (c) {
                            'b', 'B', 'o', 'O', 'x', 'X' => {},
                            else => return self.fail("Unknown numeric prefix: '{}'", .{c}),
                        }
                        self.pos += 1;
                    } else if (!std.ascii.isDigit(c)) {
                        const number = try std.fmt.parseInt(i64, self.buf[start..self.pos], 0);
                        const operand = .{ .immediate = number };
                        try operand_idx_list.append(self.alloc, try self.appendOperand(operand));
                        state = .end_of_operand;
                    } else {
                        self.pos += 1;
                    }
                },
                .operand_identifier => if (!std.ascii.isAlphanumeric(c) and c != '_') {
                    const identfier = self.buf[start..self.pos];
                    const operand = .{ .register = identfier };
                    try operand_idx_list.append(self.alloc, try self.appendOperand(operand));
                    state = .end_of_operand;
                } else {
                    self.pos += 1;
                },
            }
        }
    }

    fn appendOperand(self: *Parser, operand: Operand) !usize {
        const pos = self.operands.items.len;
        try self.operands.append(self.alloc, operand);
        return pos;
    }

    fn untilNonWhitespace(self: *Parser) ?void {
        while (std.ascii.isWhitespace(self.buf[self.pos])) {
            self.pos += 1;
            if (self.pos == self.buf.len) return null;
        }
    }

    // Advance the parser until `c` is encountered. If `c` is encountered, the index is
    // returned. `self.pos` is also the index. If the character is not encountered,
    // then the position is not updated.
    fn until(self: *Parser, c: u8) ?usize {
        var pos = self.pos;
        while (pos < self.buf.len) {
            if (self.buf[pos] == c) {
                self.pos = pos;
                return pos;
            } else {
                pos += 1;
            }
        }
        return null;
    }

    fn expect(self: *Parser, c: u8) !void {
        if (self.buf[self.pos] != c) {
            return self.fail("Unexpected token: expected {}, found {}", .{ c, self.buf[self.pos] });
        } else {
            self.pos += 1;
        }
    }

    fn fail(self: *Parser, comptime format: []const u8, args: anytype) !void {
        @setCold(true);
        assert(self.err_msg == null);
        self.err_msg = try ErrorMsg.init(self.alloc, format, args);
        return error.ParseFail;
    }

    pub fn deinit(self: *Parser) void {
        self.operands.deinit(self.alloc);
        self.labels.deinit(self.alloc);
        for (self.instructions.items) |instr| {
            if (instr.operands.len > 0) self.alloc.free(instr.operands);
        }
        self.instructions.deinit(self.alloc);
    }
};

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

test "Parser - Single instruction" {
    var parser = Parser.init("addi x0, x0, 12\n", std.testing.allocator);
    defer parser.deinit();
    try parser.parse();

    try std.testing.expectEqualDeep(
        parser.operands.items,
        @constCast(&[_]Operand{
            .{ .register = "x0" },
            .{ .register = "x0" },
            .{ .immediate = 12 },
        }),
    );
    try std.testing.expectEqualDeep(
        parser.instructions.items,
        @constCast(&[_]Instruction{.{ .op = "addi", .operands = @constCast(&[_]usize{ 0, 1, 2 }), .loc = .{ .start = 0, .end = 4 } }}),
    );
}

test "Parser - Multiple instruction" {
    var parser = Parser.init(
        \\addi x0, x0, 12
        \\addi x0, x0, 12
        \\
    , std.testing.allocator);
    defer parser.deinit();
    try parser.parse();

    try std.testing.expectEqualDeep(
        parser.operands.items,
        @constCast(&[_]Operand{
            .{ .register = "x0" },
            .{ .register = "x0" },
            .{ .immediate = 12 },
            .{ .register = "x0" },
            .{ .register = "x0" },
            .{ .immediate = 12 },
        }),
    );
    try std.testing.expectEqualDeep(
        parser.instructions.items,
        @constCast(&[_]Instruction{
            .{ .op = "addi", .operands = @constCast(&[_]usize{ 0, 1, 2 }), .loc = .{ .start = 0, .end = 4 } },
            .{ .op = "addi", .operands = @constCast(&[_]usize{ 3, 4, 5 }), .loc = .{ .start = 16, .end = 20 } },
        }),
    );
}
