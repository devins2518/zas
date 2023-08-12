const std = @import("std");
pub const Instruction = @import("Instruction.zig");
pub const riscv = @import("riscv.zig");

test {
    _ = Instruction;
    _ = riscv;
    std.testing.refAllDeclsRecursive(@This());
}
