module rcpu;

import alu;
import register;
import instruction;
import mybitconverter;

import std.stdio;
/**
 * RCPU
 */
class RCPU(bool log = false)
{
public:
    Register!16 a;
    Register!16 b;
    Register!16 c;
    Register!16 sp;
    Register!16 fp;
    Register!32 pc;
    FlagRegister f;
    ALU alu;
    this () pure
    {
        initialize();
    }
    void setMemWrite(void delegate (uint, ushort) arg) pure {
        memWrite = arg;
    }
    void setMemRead(ushort delegate (uint) arg) pure {
        memRead = arg;
    }

    void executeInstruction() {
        //static if (log)
        //    writefln("PC: %08X, A: %04X, B: %04X, C: %04X, SP: %04X, FP: %04X, F: %04b", 
        //        pc.value, a.value, b.value, c.value, sp.value, fp.value, f.value);
        auto opcode = memRead(pc++);
        Instruction instr = decodeInstruction(opcode);
            writeln(instr);
        final switch (instr.type) {
            case InstructionType.a: executeAType(instr); break;
            case InstructionType.j: executeJType(instr); break;
            case InstructionType.i: executeIType(instr); break;
            case InstructionType.si: executeSIType(instr); break;
            case InstructionType.f: executeFType(instr); break;
            case InstructionType.ls: executeLSType(instr); break;
            case InstructionType.sp: executeSPType(instr); break;
        }
    }
private:
    void initialize() pure {
        a = Register!16();
        b = Register!16();
        c = Register!16();
        sp = Register!16(0xFFFF);
        fp = Register!16(0xFFFF);
        pc = Register!32();
        f = FlagRegister();
        alu = new ALU;
    }

    void delegate (uint, ushort) memWrite;
    ushort delegate (uint) memRead;

    ushort getValue(ushort addrMode) {
        switch (addrMode) {
            case 0: return 0;
            case 1: return a;
            case 2: return b;
            case 3: return c;
            case 4: return memRead(pc++);
            case 5: {
                uint addr = memRead(pc++) << 16;
                addr |= memRead(pc++);
                return memRead(addr);
            }
            case 6: return memRead(a);
            case 7: {
                uint addr = 0xD0000000 | ((fp + memRead(pc++)) & 0xFFFF);
                return memRead(addr);
            }
            default: throw new InvalidAddrModeException(addrMode, pc);
        }
    }

    void setValue(ushort addrMode, ushort value) {
        switch (addrMode) {
            case 0: break;
            case 1: a = value; break;
            case 2: b = value; break;
            case 3: c = value; break;
            case 4: break;
            case 5: {
                uint addr = memRead(pc++) << 16;
                addr |= memRead(pc++);
                memWrite(addr, value);
                break;
            }
            case 6: memWrite(a, value); break;
            case 7: {
                uint addr = 0xD0000000 | ((fp + memRead(pc++)) & 0xFFFF);
                memWrite(addr, value);
                break;
            }
            default: throw new InvalidAddrModeException(addrMode, pc);
        }
    }

    void executeAType(Instruction instr) {
        ushort a1 = getValue(instr.a1);
        ushort a2 = getValue(instr.a2);
        bool isNOP = instr.a1 == 0 && instr.a2 == 0 && instr.a3 == 0 && instr.opcode == 0;
        uint result = alu.calculate(a1, a2, f, instr.opcode, !isNOP, false);
        //writefln("%04X - %04X = %04X", a1, a2, result);
        setValue(instr.a3, cast(ushort) (result & 0xFFFF));
        if (instr.opcode == 4) // MUL instruction
            a = cast(ushort) (result >> 16);
    }

    void executeJType(Instruction instr) {
        pc = instr.a1;
    }

    void executeIType(Instruction instr) {
        ushort a1 = getValue(instr.a1);
        ushort a2 = instr.a2;
        ubyte func = ((instr.opcode & 1) * 0b1100) | ((instr.opcode & 0b110) >> 1);
        uint result = alu.calculate(a1, a2, f, func, true, false);
        setValue(instr.a1, cast(ushort) result);
    }

    void executeSIType(Instruction instr) {
        ushort a1 = getValue(instr.a1);
        ushort a3 = instr.a3;
        ubyte func = 0b1000 | instr.opcode;
        uint result = alu.calculate(a1, a3, f, func, true, false);
        setValue(instr.a2, cast(ushort) result);
    }

    void executeFType(Instruction instr) {
        if (f.value.getBit(instr.a1) == instr.opcode)
            pc += instr.a2;
    }

    void executeLSType(Instruction instr) {
        if (instr.opcode == 0) {
            ushort value = memRead(0xFFFF1000 | instr.a2);
            setValue(instr.a1, value);
        } else {
            ushort value = getValue(instr.a1);
            memWrite(0xFFFF1000 | instr.a2, value);
        }
    }

    void executeSPType(Instruction instr) {
        if (instr.opcode == 0) { // PUSH
            ushort value = getValue(instr.a1);
            memWrite(0xD0000000 | sp--, value);
        } 
        else if (instr.opcode == 1) { // POP
            ushort value = memRead(0xD0000000 | ++sp); 
            setValue(instr.a1, value);
        }
        else if (instr.opcode == 2) { // SVPC
            memWrite(0xD0000000 | sp--, cast(ushort) (pc >> 16));
            memWrite(0xD0000000 | sp--, cast(ushort) ((pc+1) & 0xFFFF));
            memWrite(0xD0000000 | sp--, fp);
            fp = sp;
        } 
        else { // RET
            fp = memRead(0xD0000000 | ++sp);
            pc = memRead(0xD0000000 | ++sp);
            pc |= memRead(0xD0000000 | ++sp) << 16;
        } 
    }
}
unittest
{
    import ram;
    //import std.stdio;
    auto rcpu = new RCPU!true;
    auto mem = new RAM!true("sqrt.mif");
    rcpu.setMemWrite(&mem.memWrite);
    rcpu.setMemRead(&mem.memRead);
    foreach (i; 1..200)
        rcpu.executeInstruction;
    writeln(rcpu.pc);
    writeln(rcpu.a);
}


class InvalidAddrModeException : Exception {
    this(ushort addrMode, uint address) pure
    {
        import std.format;
        super(format("Invalid addrMode: %d in instruction at 0x%08X", addrMode, address));
    }
}