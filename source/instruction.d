module instruction;

enum InstructionType {a, j, i, si, f, ls, sp}

class InvalidInstructionException : Exception
{
    this(ushort instr) pure
    {
        import std.format;
        super(format("Invalid opcode: %016b", instr));
    }
}

struct Instruction {
    InstructionType type;
    ushort a1;
    ushort a2;
    ushort a3;
    ubyte opcode;
}

public Instruction decodeInstruction (ushort instr) pure {
    import mybitconverter;
    Instruction result;
    if (instr.getBits(12, 16) == 0b0000) {
        result.type = InstructionType.a;
        result.a1 = instr.getBits(9, 12);
        result.opcode = cast(ubyte) instr.getBits(5, 9);
        result.a2 = instr.getBits(3, 5);
        result.a3 = instr.getBits(0, 3);
    } else if (instr.getBit(15) == 1) {
        result.type = InstructionType.j;
        result.a1 = instr.getBits(0, 15);
    } else if (instr.getBits(14, 16) == 0b01) {
        result.type = InstructionType.i;
        result.opcode = cast(ubyte) ((instr.getBits(12, 14) << 1) | instr.getBits(8, 9));
        result.a1 = instr.getBits(9, 12);
        result.a2 = instr.getBits(0, 8);
    } else if (instr.getBits(12, 16) == 0b0001) {
        result.type = InstructionType.si;
        result.a1 = instr.getBits(9, 12);
        result.opcode = cast(ubyte) instr.getBits(7, 9);
        result.a2 = instr.getBits(4, 7);
        result.a3 = instr.getBits(0, 4);
    } else if (instr.getBits(12, 16) == 0b0010 && instr.getBit(8) == 0) {
        result.type = InstructionType.f;
        result.opcode = cast(ubyte) instr.getBit(11);
        result.a1 = instr.getBits(9, 11);
        result.a2 = instr.getBits(0, 8);
    } else if (instr.getBits(12, 16) == 0b0010 && instr.getBit(8) == 1) {
        result.type = InstructionType.ls;
        result.a1 = instr.getBits(9, 12);
        result.opcode = cast(ubyte) instr.getBit(7);
        result.a2 = instr.getBits(0, 7);
    } else if (instr.getBits(12, 16) == 0b0011) {
        result.type = InstructionType.ls;
        result.a1 = instr.getBits(9, 12);
        result.opcode = cast(ubyte) instr.getBits(7, 9);
    } else throw new InvalidInstructionException(instr);
    return result;
} unittest
{
    import std.stdio;
    Instruction instr;

    instr = decodeInstruction(0b0000_100_0010_01_001);
    assert(instr.type == InstructionType.a);
    assert(instr.opcode == 0b0010);
    assert(instr.a1 == 0b100);
    assert(instr.a2 == 0b01);
    assert(instr.a3 == 0b001);

    instr = decodeInstruction(0b1_000_0010_0100_1101);
    assert(instr.type == InstructionType.j);
    assert(instr.a1 == 0x024D);

    instr = decodeInstruction(0b01_00_001_1_00101001);
    assert(instr.type == InstructionType.i);
    assert(instr.opcode == 0b001);
    assert(instr.a1 == 0b001);
    assert(instr.a2 == 0x29);

    instr = decodeInstruction(0b0001_001_01_001_0100);
    assert(instr.type == InstructionType.si);
    assert(instr.opcode == 0b01);
    assert(instr.a1 == 0b001);
    assert(instr.a2 == 0b001);
    assert(instr.a3 == 0b0100);

    instr = decodeInstruction(0b0010_0_01_0_00010100);
    assert(instr.type == InstructionType.f);
    assert(instr.opcode == 0);
    assert(instr.a1 == 0b01);
    assert(instr.a2 == 0b00010100);

    instr = decodeInstruction(0b0010_101_1_1_0011100);
    assert(instr.type == InstructionType.ls);
    assert(instr.opcode == 1);
    assert(instr.a1 == 0b101);
    assert(instr.a2 == 0b00011100);

    instr = decodeInstruction(0b0011_100_00_0000000);
    assert(instr.type == InstructionType.ls);
    assert(instr.opcode == 0b00);
    assert(instr.a1 == 0b100);
}