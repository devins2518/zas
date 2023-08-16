const std = @import("std");
pub const ConstBigInt = std.math.big.int.Const;

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

pub const Token = struct {
    kind: TokenKind,
    src: []const u8,
};
