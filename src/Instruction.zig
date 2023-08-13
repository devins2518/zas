const std = @import("std");
const StructField = std.builtin.Type.StructField;
const Instruction = @This();
const Int = std.meta.Int;
const Parser = std.fmt.Parser;
comptime name: []const u8 = "",
comptime pseudo: bool = false,
/// Total size of the instruction in bits.
comptime bit_size: usize = 0,
/// The layout of the fields using the names of the fields of this struct.
/// The total size of each field much match the bit_size field.
/// TODO: support bit literals
comptime layout: []const []const u8 = &.{},
comptime read_operands: []const []const u8 = &.{},
comptime write_operands: []const []const u8 = &.{},
/// A format string showing how the instruction can be displayed.
/// TODO: format docs
comptime parse_style: []const u8 = "",

pub fn parse(
    comptime InstructionSet: type,
    buf: []const u8,
    allocator: std.mem.Allocator,
) ![]InstructionSet {
    const ISInfo = @typeInfo(InstructionSet);
    // Assert that the instruction set is valid
    comptime {
        if (ISInfo != .Union or ISInfo.Union.tag_type == null)
            @compileError(@typeName(InstructionSet) ++ " must be a tagged union!");
        for (ISInfo.Union.fields) |field| {
            _ = instructionHasProperForm(field.type);
        }
    }
    const instruction_names = comptime blk: {
        const CSMType = struct { []const u8 };
        var names: []const CSMType = &.{};
        for (ISInfo.Union.fields) |field| {
            names = names ++ &[_]CSMType{.{field.name}};
        }
        break :blk std.ComptimeStringMap(void, names){};
    };
    _ = instruction_names;

    var parser = Parser{ .buf = buf };
    var list = std.ArrayList(InstructionSet).init(allocator);

    while (parser.pos < buf.len) {
        var could_parse = false;
        inline for (ISInfo.Union.fields) |instruction| {
            if (GenParse(instruction.type).parse(parser)) |t| {
                try list.append(@unionInit(InstructionSet, instruction.name, t));
                could_parse = true;
                break;
            } else |_| {}
        }
        if (!could_parse) {
            return error.CouldNotParse;
        }
    }
    return list.items;
}

fn GenParse(comptime T: type) type {
    const type_fields = @typeInfo(T).Struct.fields;
    const parse_style: []const u8 = @as(T, undefined).parse_style;
    const ParseState = enum {
        waiting_for_open,
        parsing_field,
    };
    _ = ParseState;
    _ = type_fields;

    return struct {
        pub fn parse(parser: Parser) !T {
            comptime var style_parser = Parser{ .buf = parse_style };
            while (style_parser.char()) |c| {
                if (std.ascii.isWhitespace(c)) {
                    if (!std.ascii.isWhitespace(parser.buf[parser.pos]))
                        return error.UnexpectedToken;

                    while (std.ascii.isWhitespace(parser.buf[parser.pos])) {
                        parser.pos += 1;
                    }
                } else if (c == '{') {
                    const field_name = style_parser.until('}');
                    _ = field_name;
                } else if (!parser.maybe(c))
                    return error.UnexpectedToken;
            }
            return undefined;
        }
    };
}

pub fn toBytes(comptime T: type, instruction: T) Int(.unsigned, instruction.bit_size) {
    comptime std.debug.assert(instructionHasProperForm(T));

    const bit_size = instruction.bit_size;
    const BinaryType = Int(.unsigned, bit_size);
    var bits: BinaryType = 0;

    comptime var bit_offset = bit_size;

    inline for (instruction.layout) |field| {
        const FieldType = @TypeOf(@field(instruction, field));
        const FieldIntType = Int(.unsigned, @bitSizeOf(FieldType));
        bit_offset -= @bitSizeOf(FieldType);

        // Extract field value as bits
        const field_bits: FieldIntType = switch (@typeInfo(FieldType)) {
            .Int => @bitCast(@field(instruction, field)),
            .Enum => @intFromEnum(@field(instruction, field)),
            else => @compileError("Unsupported field type " ++ @typeName(FieldType) ++ "!"),
        };

        bits |= @as(BinaryType, @as(FieldIntType, @bitCast(field_bits))) << bit_offset;
    }

    return bits;
}

pub fn instructionHasProperForm(comptime T: type) bool {
    const self: T = undefined;

    if (@typeInfo(T) != .Struct)
        @compileError(@typeName(T) ++ " must be a struct!");

    if (self.bit_size == 0)
        @compileError(@typeName(T) ++ " bit_size must be greater than 0!");

    if (comptime std.mem.eql(u8, self.name, ""))
        @compileError(@typeName(T) ++ " name cannot be empty!");

    if (comptime self.layout.len < 1)
        @compileError(@typeName(T) ++ " layout must be properly initialized!");

    comptime var layout_size = 0;
    inline for (self.layout) |field| {
        layout_size += @bitSizeOf(@TypeOf(@field(self, field)));
    }
    if (comptime layout_size != self.bit_size) {
        @compileLog(layout_size);
        @compileLog(self.bit_size);
        @compileError(@typeName(T) ++ " layout does not match bit_size!");
    }

    if (comptime std.mem.eql(u8, self.parse_style, ""))
        @compileError(@typeName(T) ++ " parse style cannot be empty!");

    if (self.read_operands.len < 1)
        @compileError(@typeName(T) ++ " read_operands must be properly initialized!");
    if (self.write_operands.len < 1)
        @compileError(@typeName(T) ++ " write_operands must be properly initialized!");

    return true;
}

// TODO: aliasing
pub fn Class(comptime Base: type, comptime Child: type) type {
    const ChildInfo = @typeInfo(Child);
    if (ChildInfo != .Struct) {
        @compileError("Instruction.Class can only derive from a struct!");
    }
    var BaseInfo = @typeInfo(Base).Struct;
    var fields: []const StructField = &.{};
    for (BaseInfo.fields) |field| {
        if (!@hasField(Child, field.name))
            fields = fields ++ &[_]StructField{field};
    }

    for (ChildInfo.Struct.fields) |field| {
        fields = fields ++ &[_]StructField{field};
    }

    BaseInfo.decls = &.{};
    BaseInfo.fields = fields;

    return @Type(.{ .Struct = BaseInfo });
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
