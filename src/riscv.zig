const std = @import("std");
const parser = @import("parser.zig");
const Instruction = @import("Instruction.zig");
const Operand = Instruction.Operand;
const ComptimeStringMap = std.ComptimeStringMap;

const Register = enum(u5) {
    // zig fmt: off
    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,  x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31,
    // zig fmt: on

    pub fn alias(s: []const u8) ?Register {
        const csm = ComptimeStringMap(Register, [33]struct { []const u8, Register }{
            .{ "zero", .x0 },
            .{ "ra", .x1 },
            .{ "sp", .x2 },
            .{ "gp", .x3 },
            .{ "tp", .x4 },
            .{ "t0", .x5 },
            .{ "t1", .x6 },
            .{ "t2", .x7 },
            .{ "s0", .x8 },
            .{ "fp", .x8 },
            .{ "s1", .x9 },
            .{ "a0", .x10 },
            .{ "a1", .x11 },
            .{ "a2", .x12 },
            .{ "a3", .x13 },
            .{ "a4", .x14 },
            .{ "a5", .x15 },
            .{ "a6", .x16 },
            .{ "a7", .x17 },
            .{ "s2", .x18 },
            .{ "s3", .x19 },
            .{ "s4", .x20 },
            .{ "s5", .x21 },
            .{ "s6", .x22 },
            .{ "s7", .x23 },
            .{ "s8", .x24 },
            .{ "s9", .x25 },
            .{ "s10", .x26 },
            .{ "s11", .x27 },
            .{ "t3", .x28 },
            .{ "t4", .x29 },
            .{ "t5", .x30 },
            .{ "t6", .x31 },
        });
        return csm.get(s);
    }
};

pub const InstructionSet: []const type = &.{
    Addi,
    Slti,
    Sltiu,
    Xori,
    Ori,
    Andi,
};
pub const RiscvParser = parser.Parser(InstructionSet);

const RiscvInstruction = Instruction.Class(Instruction, struct {
    comptime bit_size: usize = 32,
});

// I Type Instructions
const IType = Instruction.Class(RiscvInstruction, struct {
    comptime opcode: u7 = 0b0010011,
});

const AluIType = Instruction.Class(IType, struct {
    comptime layout: []const []const u8 = &.{ "imm12", "rs1", "funct3", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{"rs1"},
    comptime write_operands: []const []const u8 = &.{"rd"},
    comptime parse_style: []const u8 = "{name} {rd}, {rs1}, {imm12}",
    rd: Register,
    rs1: Register,
    imm12: i12,
});

fn CreateAluIType(comptime name: []const u8, comptime funct3: u3) type {
    return Instruction.Class(AluIType, struct {
        comptime name: []const u8 = name,
        comptime funct3: u3 = funct3,
    });
}

const Addi = CreateAluIType("addi", 0b000);
const Slti = CreateAluIType("slti", 0b010);
const Sltiu = CreateAluIType("sltiu", 0b011);
const Xori = CreateAluIType("xori", 0b100);
const Ori = CreateAluIType("ori", 0b110);
const Andi = CreateAluIType("andi", 0b111);

const ShiftIType = Instruction.Class(IType, struct {
    comptime layout: []const []const u8 = &.{ "imm7", "shamt", "rs1", "funct3", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{"rs1"},
    comptime write_operands: []const []const u8 = &.{"rd"},
    comptime parse_style: []const u8 = "{name} {rd}, {rs1}, {shamt}",
    rd: Register,
    rs1: Register,
    shamt: u5,
});

fn CreateShiftIType(comptime name: []const u8, comptime funct3: u3, comptime imm7: u7) type {
    return Instruction.Class(ShiftIType, struct {
        comptime name: []const u8 = name,
        comptime funct3: u3 = funct3,
        comptime imm7: u7 = imm7,
    });
}

const Slli = CreateShiftIType("slli", 0b001, 0b0000000);
const Srli = CreateShiftIType("srli", 0b101, 0b0000000);
const Srai = CreateShiftIType("srai", 0b101, 0b0100000);

// U Type Instructions
const UType = Instruction.Class(RiscvInstruction, struct {
    comptime layout: []const []const u8 = &.{ "imm20", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{},
    comptime write_operands: []const []const u8 = &.{"rd"},
    comptime parse_style: []const u8 = "{name} {rd} {shamt}",
    rd: Register,
    imm20: u20,
});

fn CreateUType(comptime name: []const u8, comptime opcode: u7) type {
    return Instruction.Class(UType, struct {
        comptime name: []const u8 = name,
        comptime opcode: u7 = opcode,
    });
}

const Lui = CreateUType("lui", 0b0110111);
const Auipc = CreateUType("auipc", 0b0010111);

// R Type Instructions
const RType = Instruction.Class(RiscvInstruction, struct {
    comptime opcode: u7 = 0b0110011,
    comptime layout: []const []const u8 = &.{ "imm7", "rs2", "rs1", "funct3", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{ "rs1", "rs2" },
    comptime write_operands: []const []const u8 = &.{"rd"},
    comptime parse_style: []const u8 = "{name} {rd}, {rs1}, {rs2}",
    rd: Register,
    rs1: Register,
    rs2: Register,
});

fn CreateRType(comptime name: []const u8, comptime funct3: u3, comptime imm7: u7) type {
    return Instruction.Class(RType, struct {
        comptime name: []const u8 = name,
        comptime funct3: u3 = funct3,
        comptime imm7: u7 = imm7,
    });
}

const Add = CreateRType("add", 0b000, 0b0000000);
const Sub = CreateRType("sub", 0b000, 0b0100000);
const Sll = CreateRType("sll", 0b001, 0b0000000);
const Slt = CreateRType("slt", 0b010, 0b0000000);
const Sltu = CreateRType("sltu", 0b011, 0b0000000);
const Xor = CreateRType("xor", 0b100, 0b0000000);
const Srl = CreateRType("srl", 0b101, 0b0000000);
const Sra = CreateRType("sra", 0b101, 0b0100000);
const Or = CreateRType("or", 0b110, 0b0000000);
const And = CreateRType("and", 0b111, 0b0000000);

// J Type Instructions
const Jal = Instruction.Class(RiscvInstruction, struct {
    comptime opcode: u7 = 0b1101111,
    comptime layout: []const []const u8 = &.{ "imm20[20]", "imm20[10:1]", "imm20[11]", "imm20[19:12]", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{},
    comptime write_operands: []const []const u8 = &.{"rd"},
    comptime parse_style: []const u8 = "{name} {rd}, {imm20}",
    rd: Register,
});
const Jalr = Instruction.Class(RiscvInstruction, struct {
    comptime opcode: u7 = 0b1100111,
    comptime layout: []const []const u8 = &.{ "imm12", "rs1", "funct3", "rd", "opcode" },
    comptime read_operands: []const []const u8 = &.{"rs1"},
    comptime write_operands: []const []const u8 = &.{},
    comptime parse_style: []const u8 = "{name} {rd}, {rs1}, {imm12}",
    rd: Register,
    rs1: Register,
    imm12: i12,
});

// B Type Instructions
const BType = Instruction.Class(RiscvInstruction, struct {
    comptime opcode: u7 = 0b1100011,
    comptime layout: []const []const u8 = &.{ "imm12[12]", "imm12[10:5]", "rs2", "rs1", "funct3", "imm12[11]", "imm12[4:1]", "opcode" },
    comptime read_operands: []const []const u8 = &.{ "rs1", "rs2" },
    comptime write_operands: []const []const u8 = &.{},
    comptime parse_style: []const u8 = "{name} {rs1}, {rs2}, {imm12}",
    rs1: Register,
    rs2: Register,
    imm12: i12,
});

fn CreateBType(comptime name: []const u8, comptime funct3: u3) type {
    Instruction.Class(BType, struct {
        comptime name: []const u8 = name,
        comptime funct3: u3 = funct3,
    });
}

const Beq = CreateBType("beq", 0b000);
const Bne = CreateBType("bne", 0b001);
const Blt = CreateBType("blt", 0b000);
const Bge = CreateBType("bge", 0b101);
const Bltu = CreateBType("bltu", 0b110);
const Bgeu = CreateBType("bgeu", 0b111);

test AluIType {
    try std.testing.expect(Instruction.instructionHasProperForm(Addi));
    const i = Addi{ .rd = .x0, .rs1 = .x0, .imm12 = 12 };
    try std.testing.expect(Instruction.toBytes(Addi, i) == 0b00000000110000000000000000010011);
}

test RiscvParser {
    {
        var p = RiscvParser.init(
            \\addi x1, x0, 1
            \\
        , std.testing.allocator);
        defer p.deinit();
        try p.parse();
        try std.testing.expectEqualSlices(
            u8,
            p.binary.items,
            &[_]u8{ 0b10010011, 0b00000000, 0b00010000, 0b00000000 },
        );
    }
    {
        var p = RiscvParser.init(
            \\addi ra, zero, 1
            \\
        , std.testing.allocator);
        defer p.deinit();
        try p.parse();
        try std.testing.expectEqualSlices(
            u8,
            p.binary.items,
            &[_]u8{ 0b10010011, 0b00000000, 0b00010000, 0b00000000 },
        );
    }
}
