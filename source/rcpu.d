module rcpu;

import alu;
import register;
import instruction;
import mybitconverter;
/**
 * RCPU
 */
class RCPU
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
    this() pure
    {
        initialize();
    }
    void setMemWrite(void delegate (uint, ushort) pure const arg) pure {
        memWrite = arg;
    }
    void setMemRead(ushort delegate (uint) pure const arg) pure {
        memRead = arg;
    }

    void executeInstruction() {
        auto opcode = memRead(pc++);
        Instruction instr = decodeInstruction(opcode);
        final switch (instr.type) {
            case InstructionType.a: executeAType(instr); break;
            case InstructionType.j: break;
            case InstructionType.i: break;
            case InstructionType.si: break;
            case InstructionType.f: break;
            case InstructionType.ls: break;
            case InstructionType.sp: break;
        }
    }
private:
    void initialize() pure {
        a = new Register!16;
        b = new Register!16;
        c = new Register!16;
        sp = new Register!16(0xFFFF);
        fp = new Register!16(0xFFFF);
        pc = new Register!32;
        f = new FlagRegister;
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
                uint addr = 0xD0000000 | (fp + memRead(pc++));
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
                uint addr = 0xD0000000 | (fp + memRead(pc++));
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
        uint result = alu.calculate(a1, a2, f, !isNOP, false);
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
        } 
        else { // RET
            fp = cast(ushort) (memRead(0xD0000000 | ++sp) << 16);
            pc = memRead(0xD0000000 | ++sp) << 16;
            pc |= memRead(0xD0000000 | ++sp) << 16;
        } 
    }
}

class InvalidAddrModeException : Exception {
    this(ushort addrMode, uint address) pure
    {
        import std.format;
        super(format("Invalid addrMode: %d in instruction at 0x%08X", addrMode, address));
    }
}