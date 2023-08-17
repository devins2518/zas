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
