const std = @import("std");
const errors = @import("errors.zig");
const assert = std.debug.assert;
const isAlphabetic = std.ascii.isAlphabetic;
const isAlphanumeric = std.ascii.isAlphanumeric;
const isDigit = std.ascii.isDigit;
const isHex = std.ascii.isHex;
const isWhitespace = std.ascii.isWhitespace;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ErrorMsg = errors.ErrorMsg;

pub const Tokenizer = struct {
    alloc: Allocator,
    buf: []const u8,
    pos: usize = 0,
    start: usize = 0,
    tokens: ArrayListUnmanaged(Token) = .{},
    err_msg: ?ErrorMsg = null,

    pub fn init(buf: []const u8, allocator: Allocator) Tokenizer {
        return Tokenizer{ .alloc = allocator, .buf = buf, .pos = 0 };
    }

    pub fn nextToken(self: *Tokenizer) !?Token {
        self.start = self.pos;
        const curr = self.currChar();
        const next = self.maybeNext() orelse 0;

        if (self.currIsComment())
            return self.parseComment()
        else {
            self.pos += 1;
            if (self.pos == self.buf.len) return null;
            return switch (curr) {
                ':' => Token{ .kind = .colon, .src = self.buf[self.start .. self.start + 1] },
                '+' => Token{ .kind = .plus, .src = self.buf[self.start .. self.start + 1] },
                '-' => if (next == '>') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .minus_greater, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .minus, .src = self.buf[self.start .. self.start + 1] },
                '~' => Token{ .kind = .tilde, .src = self.buf[self.start .. self.start + 1] },
                '/' => Token{ .kind = .slash, .src = self.buf[self.start .. self.start + 1] },
                '\\' => Token{ .kind = .backslash, .src = self.buf[self.start .. self.start + 1] },
                '(' => Token{ .kind = .l_paren, .src = self.buf[self.start .. self.start + 1] },
                ')' => Token{ .kind = .r_paren, .src = self.buf[self.start .. self.start + 1] },
                '{' => Token{ .kind = .l_brace, .src = self.buf[self.start .. self.start + 1] },
                '}' => Token{ .kind = .r_brace, .src = self.buf[self.start .. self.start + 1] },
                '[' => Token{ .kind = .l_bracket, .src = self.buf[self.start .. self.start + 1] },
                ']' => Token{ .kind = .r_bracket, .src = self.buf[self.start .. self.start + 1] },
                '?' => Token{ .kind = .question, .src = self.buf[self.start .. self.start + 1] },
                '*' => Token{ .kind = .star, .src = self.buf[self.start .. self.start + 1] },
                '.' => Token{ .kind = .period, .src = self.buf[self.start .. self.start + 1] },
                ',' => Token{ .kind = .comma, .src = self.buf[self.start .. self.start + 1] },
                '$' => Token{ .kind = .dollar, .src = self.buf[self.start .. self.start + 1] },
                '=' => if (next == '=') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .equal_eq, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .equal, .src = self.buf[self.start .. self.start + 1] },
                '|' => if (next == '|') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .pipe_pipe, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .pipe, .src = self.buf[self.start .. self.start + 1] },
                '^' => Token{ .kind = .caret, .src = self.buf[self.start .. self.start + 1] },
                '&' => if (next == '&') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .amp_amp, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .amp, .src = self.buf[self.start .. self.start + 1] },
                '!' => if (next == '=') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .exclamation_eq, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .exclamation, .src = self.buf[self.start .. self.start + 1] },
                '%' => Token{ .kind = .percent, .src = self.buf[self.start .. self.start + 1] },
                '#' => Token{ .kind = .hash, .src = self.buf[self.start .. self.start + 1] },
                '<' => if (next == '<') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .less_less, .src = self.buf[self.start .. self.start + 2] };
                } else if (next == '=') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .less_than_eq, .src = self.buf[self.start .. self.start + 2] };
                } else if (next == '>') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .less_greater, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .less_than, .src = self.buf[self.start .. self.start + 1] },
                '>' => if (next == '=') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .greater_than_eq, .src = self.buf[self.start .. self.start + 2] };
                } else if (next == '>') blk: {
                    self.pos += 1;
                    break :blk Token{ .kind = .greater_greater, .src = self.buf[self.start .. self.start + 2] };
                } else Token{ .kind = .greater_than, .src = self.buf[self.start .. self.start + 1] },
                '@' => Token{ .kind = .at, .src = self.buf[self.start .. self.start + 1] },
                ' ', '\t' => blk: {
                    break :blk if (self.untilNonWhitespace()) |_|
                        self.nextToken()
                    else
                        null;
                },
                '0'...'9' => self.parseDigit(),
                else => |c| if (isWhitespace(c))
                    if (self.untilNonWhitespace()) |_| self.nextToken() else null
                else if (isAlphabetic(c) or c == '_' or c == '.')
                    self.parseIdent()
                else {
                    try self.fail("Unexpected start to identifier: {c}", .{c});
                    return Token{ .kind = .err, .src = self.buf[self.start..self.pos] };
                },
            };
        }
    }

    pub fn tokenize(self: *Tokenizer) !void {
        while (try self.nextToken()) |t| {
            try self.tokens.append(self.alloc, t);
        }
    }

    fn currChar(self: *const Tokenizer) u8 {
        return self.buf[self.pos];
    }

    fn maybeNext(self: *const Tokenizer) ?u8 {
        const idx = self.pos + 1;
        return if (idx + 1 < self.buf.len) self.buf[idx] else null;
    }

    fn parseComment(self: *Tokenizer) Token {
        assert(self.currIsComment());
        const end = std.mem.indexOfScalar(u8, self.buf[self.pos..], '\n') orelse self.buf.len - 1;
        self.pos = end;
        return Token{ .kind = .comment, .src = self.buf[self.start..end] };
    }

    fn isIdentChar(self: *Tokenizer) bool {
        const c = self.currChar();
        return isAlphanumeric(c) or c == '_' or c == '.';
    }

    fn parseIdent(self: *Tokenizer) Token {
        while (self.isIdentChar()) self.pos += 1;

        return Token{ .kind = .ident, .src = self.buf[self.start..self.pos] };
    }

    // Can be:
    //  label: [0-9]*:
    //  forward/backward label: [0-9]*[fb]:
    //  decimal literal: [1-9][0-9]*
    //  binary literal: 0b[01]+
    //  octal literal: 0o[0-7]+
    //  hex literal: 0x[0-F]+
    fn parseDigit(self: *Tokenizer) !?Token {
        const c = self.currChar();
        if (self.buf[self.pos - 1] != '0') { // decimal literal
            while (isDigit(self.currChar())) {
                self.pos += 1;
            }
            return Token{ .kind = .integer, .src = self.buf[self.start..self.pos] };
        } else if (c == 'b' or c == 'B') { // binary literal
            self.pos += 1;
            // Handle `jmp 0b` case
            if (!isDigit(self.currChar())) {
                self.pos -= 1;
                return Token{ .kind = .label, .src = self.buf[self.start..self.pos] };
            }
            const start = self.pos;
            while (self.currChar() == '0' or self.currChar() == '1') {
                self.pos += 1;
            }

            return if (self.pos == start) blk: {
                try self.fail("Binary literal must have at least one digit!", .{});
                break :blk Token{ .kind = .err, .src = self.buf[self.start..self.pos] };
            } else Token{ .kind = .integer, .src = self.buf[self.start..self.pos] };
        } else if (c == 'x' or c == 'X') { // hex literal
            const start = self.pos;
            while (isHex(self.currChar())) {
                self.pos += 1;
            }
            return if (self.pos == start) blk: {
                try self.fail("Hex literal must have at least one digit!", .{});
                break :blk Token{ .kind = .err, .src = self.buf[self.start..self.pos] };
            } else Token{ .kind = .integer, .src = self.buf[self.start..self.pos] };
        } else if (c == 'o' or c == 'O') {
            const start = self.pos;
            while (isOctal(self.currChar())) {
                self.pos += 1;
            }
            return if (self.pos == start) blk: {
                try self.fail("Octal literal must have at least one digit!", .{});
                break :blk Token{ .kind = .err, .src = self.buf[self.start..self.pos] };
            } else Token{ .kind = .integer, .src = self.buf[self.start..self.pos] };
        }
        return Token{ .kind = .err, .src = self.buf[self.start..self.pos] };
    }

    fn currIsComment(self: *const Tokenizer) bool {
        return self.buf[self.pos] == ';';
    }

    fn untilNonWhitespace(self: *Tokenizer) ?void {
        while (std.ascii.isWhitespace(self.buf[self.pos])) {
            self.pos += 1;
            if (self.pos == self.buf.len) return null;
        }
    }

    // Advance the parser until `c` is encountered. If `c` is encountered, the index is
    // returned. `self.pos` is also the index. If the character is not encountered,
    // then the position is not updated.
    fn until(self: *Tokenizer, c: u8) ?usize {
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

    fn expect(self: *Tokenizer, c: u8) !void {
        if (self.buf[self.pos] != c) {
            return self.fail("Unexpected token: expected {}, found {}", .{ c, self.buf[self.pos] });
        } else {
            self.pos += 1;
        }
    }

    fn fail(self: *Tokenizer, comptime format: []const u8, args: anytype) !void {
        @setCold(true);
        assert(self.err_msg == null);
        self.err_msg = try ErrorMsg.init(self.alloc, format, args);
        return error.ParseFail;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokens.deinit(self.alloc);
        if (self.err_msg) |err| err.destroy(self.alloc);
    }
};

pub const TokenKind = enum {
    err,
    ident,
    string,
    integer,
    big_integer,
    comment,
    directive,
    label,
    end_of_statement,
    colon, // :
    space, // ' '
    plus, // +
    minus, // -
    tilde, // ~
    slash, // /
    backslash, // \
    l_paren, // (
    r_paren, // )
    l_brace, // {
    r_brace, // }
    l_bracket, // [
    r_bracket, // ]
    question, // ?
    star, // *
    period, // .
    comma, // ,
    dollar, // $
    equal, // =
    equal_eq, // ==
    pipe, // |
    pipe_pipe, // ||
    caret, // ^
    amp, // &
    amp_amp, // &&
    exclamation, // !
    exclamation_eq, // !=
    percent, // %
    hash, // #
    less_than, // <
    less_than_eq, // <=
    less_less, // <<
    less_greater, // <>
    greater_than, // >
    greater_than_eq, // >=
    greater_greater, // >>
    at, // @
    minus_greater, // ->
};

fn isOctal(c: u8) bool {
    return switch (c) {
        '0'...'7' => true,
        else => false,
    };
}

pub const Token = struct {
    kind: TokenKind,
    src: []const u8,
};

test "Tokenizer - Single instruction" {
    var tokenizer = Tokenizer.init("addi x0, x0, 12\n", std.testing.allocator);
    defer tokenizer.deinit();
    try tokenizer.tokenize();

    try std.testing.expectEqualDeep(
        tokenizer.tokens.items,
        @constCast(&[_]Token{
            .{ .kind = .ident, .src = "addi" },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .integer, .src = "12" },
        }),
    );
}

test "Tokenizer - Multiple instruction" {
    var tokenizer = Tokenizer.init(
        \\addi x0, x0, 12
        \\addi x0, x0, 12
        \\
    , std.testing.allocator);
    defer tokenizer.deinit();
    try tokenizer.tokenize();

    try std.testing.expectEqualDeep(
        tokenizer.tokens.items,
        @constCast(&[_]Token{
            .{ .kind = .ident, .src = "addi" },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .integer, .src = "12" },
            .{ .kind = .ident, .src = "addi" },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .ident, .src = "x0" },
            .{ .kind = .comma, .src = "," },
            .{ .kind = .integer, .src = "12" },
        }),
    );
}
