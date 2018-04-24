module rcpu;

import alu;
import register;
import instruction;
import mybitconverter;
import ram;

import std.stdio;
/**
 * RCPU
 */
alias LogCallback = void function(string);

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
    uint ticks;

    bool irq;
    uint interruptAddr;
    ubyte interruptData;
    this (LogCallback log) pure
    {
        this.log = log;
        initialize();
    }
    void reset() pure {
        a = 0;
        b = 0;
        c = 0;
        sp = 0xFFFF;
        fp = 0xFFFF;
        pc = 0;
        f = 0;
        ticks = 0;
        irq = false;
        interruptAddr = 0;
        interruptData = 0;
    }
    void setRAM(RAM ram) pure {
        this.ram = ram;
    }

    void interrupt(uint address, ubyte data) {
        irq = true;
        interruptAddr = address;
        interruptData = data;
    }

    void executeInstruction() {
        import std.format : format;
        log(reportState);
        if (irq) {
            irq = false;
            execInterrupt(interruptAddr, interruptData);
            log(format("Interrupted to %08X with %02X", interruptAddr, interruptData));
            return;
        }
        auto opcode = memRead(pc++);
        ticks++;
        Instruction instr = decodeInstruction(opcode);
        log(format("%s -- %s", instr, ram.getComments(pc-1)));
        final switch (instr.type) {
            case InstructionType.a: executeAType(instr); break;
            case InstructionType.j: executeJType(instr); break;
            case InstructionType.jr: executeJRType(instr); break;
            case InstructionType.i: executeIType(instr); break;
            case InstructionType.si: executeSIType(instr); break;
            case InstructionType.f: executeFType(instr); break;
            case InstructionType.ls: executeLSType(instr); break;
            case InstructionType.sp: executeSPType(instr); break;
        }
        log(reportState);
    }

    string reportState() {
        import std.format : format;
        return format("PC: %08X, A: %04X, B: %04X, C: %04X, SP: %04X, FP: %04X, F: %04b",
                    pc.value, a.value, b.value, c.value, sp.value, fp.value, f.value);
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
        ticks = 0;
    }

    void execInterrupt(uint address, ubyte data) {
        memWrite(0xD0000000 | sp--, cast(ushort) (pc >> 16));
        memWrite(0xD0000000 | sp--, cast(ushort) (pc & 0xFFFF));
        memWrite(0xD0000000 | sp--, fp);
        memWrite(0xD0000000 | sp--, f);
        memWrite(0xD0000000 | sp--, data);
        memWrite(0xD0000000 | sp--, c);
        memWrite(0xD0000000 | sp--, b);
        memWrite(0xD0000000 | sp--, a);
        fp = sp;
        pc = address;
        ticks += 9;
    }

    ushort memRead (uint addr) {
        if (addr == 0xFFFF100F) return sp;
        else return ram.memRead(addr);
    }
    void memWrite (uint addr, ushort value) {
        if (addr == 0xFFFF100F) sp = value;
        else ram.memWrite(addr, value);
    }

    LogCallback log;
    RAM ram;

    ushort getValue(ushort addrMode, bool isIType = false) {
        switch (addrMode) {
            case 0: if(isIType) return sp;
                    else return 0;
            case 1: return a;
            case 2: return b;
            case 3: return c;
            case 4: ticks++; return memRead(pc++);
            case 5: {
                uint addr = memRead(pc++) << 16;
                addr |= memRead(pc++);
                ticks += 3;
                return memRead(addr);
            }
            case 6: ticks++; return memRead((ram.pageReg<<16) | a);
            case 7: {
                uint addr = 0xD0000000 | ((fp + memRead(pc++)) & 0xFFFF);
                ticks += 2;
                return memRead(addr);
            }
            default: throw new InvalidAddrModeException(addrMode, pc);
        }
    }

    void setValue(ushort addrMode, ushort value, bool isIType = false) {
        switch (addrMode) {
            case 0: if(isIType) sp = value; break;
            case 1: a = value; break;
            case 2: b = value; break;
            case 3: c = value; break;
            case 4: break;
            case 5: {
                uint addr = memRead(pc++) << 16;
                addr |= memRead(pc++);
                memWrite(addr, value);
                ticks += 3;
                break;
            }
            case 6: ticks++; memWrite((ram.pageReg<<16) | a, value); break;
            case 7: {
                uint addr = 0xD0000000 | ((fp + memRead(pc++)) & 0xFFFF);
                memWrite(addr, value);
                ticks += 2;
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
        setValue(instr.a3, cast(ushort) (result & 0xFFFF));
        ticks++;
        if (instr.opcode == 4) // MUL instruction
            a = cast(ushort) (result >> 16);
    }

    void executeJType(Instruction instr) {
        pc += cast(short) instr.a1;
        ticks++;
    }

    void executeJRType(Instruction instr) {
        short a1 = getValue(instr.a1);
        pc = (pc.value.getBits(15, 32) << 15) | (instr.a1.getBits(0, 15));
        ticks++;
    }

    void executeIType(Instruction instr) {
        ushort a1 = getValue(instr.a1, true);
        ushort a2 = instr.a2;
        ticks++;
        ubyte func = ((instr.opcode & 1) * 0b1100) | ((instr.opcode & 0b110) >> 1);
        uint result = alu.calculate(a1, a2, f, func, true, false);
        setValue(instr.a1, cast(ushort) result, true);
    }

    void executeSIType(Instruction instr) {
        ushort a1 = getValue(instr.a1);
        ushort a3 = instr.a3;
        ticks++;
        ubyte func = 0b1000 | instr.opcode;
        uint result = alu.calculate(a1, a3, f, func, true, false);
        setValue(instr.a2, cast(ushort) result);
    }

    void executeFType(Instruction instr) {
        if (f.value.getBit(instr.a1) == instr.opcode) {
            pc += cast(byte) instr.a2;
            ticks++;
        }
    }

    void executeLSType(Instruction instr) {
        ticks++;
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
            ticks += 2;
        }
        else if (instr.opcode == 1) { // POP
            ushort value = memRead(0xD0000000 | ++sp);
            setValue(instr.a1, value);
            ticks += 2;
        }
        else if (instr.opcode == 2) { // SVPC
            memWrite(0xD0000000 | sp--, cast(ushort) (pc >> 16));
            memWrite(0xD0000000 | sp--, cast(ushort) ((pc+1) & 0xFFFF));
            memWrite(0xD0000000 | sp--, fp);
            fp = sp;
            ticks += 4;
        }
        else { // RET
            fp = memRead(0xD0000000 | ++sp);
            pc = memRead(0xD0000000 | ++sp);
            pc |= memRead(0xD0000000 | ++sp) << 16;
            ticks += 3;
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
