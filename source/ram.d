import std.stdio;
import std.format : format;
import lcd;

enum romSize = 1024;
enum stackSize = 1024;
enum heapSize = 16384;
/**
 * RAM
 */

alias LogCallback = void function(string);

class RAM
{
private:
    ushort[romSize] rom;
    ushort[stackSize] stack;
    ushort[heapSize] heap;
    ushort[16] fastMem;

    string[romSize] romComments;

    void delegate (ushort) lcdDataWrite;
    void delegate (ushort) lcdCtrlWrite;
    void delegate (uint, ubyte) interrupt;

    uint keyboardAddr, irAddr, bpAddr;
    bool keyboardEn, irEn, bp0En, bp1En, bp2En, bp3En;
    uint bp0Addr, bp1Addr, bp2Addr, bp3Addr;

    LogCallback log;

public:
    this(string filename, LogCallback log)
    {
        import std.file;
        import std.string;
        import std.conv;
        this.log = log;
        this.emulatorBP = [];
        this.stopFlag = false;
        this.lastEmulatorBP = 0;
        this.emulatorBPRW = false;
        string text = readText(filename);
        auto index = text.indexOf("000:");
        foreach(line; text[index..$].splitLines) {
            if (line[0..2] == "--") continue;
            auto addr = line.parse!uint(16);
            auto spl = line[2..$].split("--");
            auto comments = spl[1..$].join("--");
            foreach(word; spl[0].split[0..$-1]) {
                romComments[addr] = comments;
                rom[addr] = word.to!ushort(16);
                addr++;
            }
        }
    }
    void memWrite (uint addr, ushort value, ubyte inMask = 0x3, ubyte outMask = 0x3) {
        import mybitconverter;
        import std.algorithm : canFind;
        if (inMask != 0x3 || outMask != 0x3)
            log(format("*%08X[%02b] <- %04X[%02b]", addr, outMask, value, inMask));
        else
            log(format("*%08X <- %04X", addr, value));
        if (inMask == 0x1)
            value = value & 0x00FF;
        else if (inMask == 0x2)
            value = value >> 8;
        if (emulatorBP.canFind(addr)) {
            stopFlag = true;
            lastEmulatorBP = addr;
            emulatorBPRW = true;
        }
        if ((addr & 0x1) == 0x1) {
            addr ^= 0x1;
            outMask ^= 0x3;
        }
        uint realAddr = addr >> 1;
        if (addr >= 0x00000000 && addr <= 0x000FFFFF) return; // ROM
        else if (addr >= 0xD0000000 && addr <= 0xD000FFFF) { // Stack
            stack[realAddr%stackSize].maskWithRef(value, outMask);
            return;
        }
        else if (addr >= 0x10000000 && addr <= 0x8FFFFFFF) { // Heap
            heap[realAddr%heapSize].maskWithRef(value, outMask);
            return;
        }
        else if (addr >= 0xFFFF1000 && addr <= 0xFFFF101F) { // Fast memory
            fastMem[realAddr%16].maskWithRef(value, outMask);
            return;
        }
        else
        switch (addr) {
            case 0xFFFF0000:
                if (outMask == 0x1)
                    lcdDataWrite(value & 0xFF);
                else if (outMask == 0x2)
                    lcdCtrlWrite(value & 0x7);
                else {
                    lcdDataWrite(value & 0xFF);
                    lcdCtrlWrite((value >> 8) & 0x7);
                }
                break;

            case 0xFFFFFFF6:
                if (outMask == 0x1)
                    irEn = value != 0;
                else if (outMask == 0x2)
                    keyboardEn = value != 0;
                else {
                    irEn = (value && 0x00FF) != 0;
                    keyboardEn = (value && 0xFF00) != 0;
                }
                break;
            case 0xFFFFFFF8: {
                ushort bits = cast(ushort) irAddr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                irAddr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFFFFA: {
                ushort bits = cast(ushort) irAddr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                irAddr.setBits(16, 32, bits);
                break;
            }
            case 0xFFFFFFFC: {
                ushort bits = cast(ushort) keyboardAddr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                keyboardAddr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFFFFE: {
                ushort bits = cast(ushort) keyboardAddr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                keyboardAddr.setBits(16, 32, bits);
                break;
            }

            case 0xFFFFF000:
                if (outMask != 0x10) {
                    bp0En = (value & 0x1) != 0;
                    bp1En = (value & 0x2) != 0;
                    bp2En = (value & 0x4) != 0;
                    bp3En = (value & 0x8) != 0;
                }
                break;
            case 0xFFFFF002: {
                ushort bits = cast(ushort) bp0Addr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                bp0Addr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFF004: {
                ushort bits = cast(ushort) bp0Addr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                bp0Addr.setBits(16, 32, bits);
                break;
            }
            case 0xFFFFF006: {
                ushort bits = cast(ushort) bp1Addr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                bp1Addr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFF008: {
                ushort bits = cast(ushort) bp1Addr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                bp1Addr.setBits(16, 32, bits);
                break;
            }
            case 0xFFFFF00A: {
                ushort bits = cast(ushort) bp2Addr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                bp2Addr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFF00C: {
                ushort bits = cast(ushort) bp2Addr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                bp2Addr.setBits(16, 32, bits);
                break;
            }
            case 0xFFFFF00E: {
                ushort bits = cast(ushort) bp3Addr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                bp3Addr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFF010: {
                ushort bits = cast(ushort) bp3Addr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                bp3Addr.setBits(16, 32, bits);
                break;
            }
            case 0xFFFFF012: {
                ushort bits = cast(ushort) bpAddr.getBits(0, 16);
                bits.maskWithRef(value, outMask);
                bpAddr.setBits(0, 16, bits);
                break;
            }
            case 0xFFFFF014: {
                ushort bits = cast(ushort) bpAddr.getBits(16, 32);
                bits.maskWithRef(value, outMask);
                bpAddr.setBits(16, 32, bits);
                break;
            }
            default: break;
        }
    }

    ushort memRead (uint addr) {
        import std.algorithm : canFind;
        if (emulatorBP.canFind(addr)) {
            stopFlag = true;
            lastEmulatorBP = addr;
            emulatorBPRW = false;
        }

        ushort value = 0;
        uint realAddr = addr >> 1;
        if (addr >= 0x00000000 && addr <= 0x000FFFFF) value = rom[realAddr%romSize]; // ROM
        else if (addr >= 0xD0000000 && addr <= 0xD000FFFF) value = stack[realAddr%stackSize]; // Stack
        else if (addr >= 0x10000000 && addr <= 0x8FFFFFFF) value = heap[realAddr%heapSize]; // Heap
        else if (addr >= 0xFFFF1000 && addr <= 0xFFFF101F) value = fastMem[realAddr%16]; // Fast memory

        log(format("*%08X -> %04X", addr, value));

        if ((addr & 0x1) == 0x1)
            value = ((value & 0x00FF) << 8) | ((value & 0xFF00) >> 8);

        return value;
    }
    void reset() {
        stack[] = 0;
        heap[] = 0;
        fastMem[] = 0;

        keyboardAddr = 0;
        irAddr = 0;
        bpAddr = 0;

        keyboardEn = false;
        irEn = false;
        bp0En = false;
        bp1En = false;
        bp2En = false;
        bp3En = false;

        bp0Addr = 0;
        bp1Addr = 0;
        bp2Addr = 0;
        bp3Addr = 0;
    }

    string getComments(uint addr) pure const{
        return romComments[addr%romSize];
    }

    ushort pageReg() pure const @property {
        return fastMem[0];
    }

    void setLCD(LCD lcd) {
        lcdDataWrite = &lcd.writeData;
        lcdCtrlWrite = &lcd.writeCtrl;
    }

    void setInterruptCallback(void delegate (uint, ubyte) interrupt) {
        this.interrupt = interrupt;
    }

    void irInterrupt(ubyte number) {
        if (irEn)
            interrupt(irAddr, number);
    }
    void keyInterrupt(ubyte code) {
        if (keyboardEn)
            interrupt(keyboardAddr, code);
    }

    uint[] emulatorBP;
    bool stopFlag;
    uint lastEmulatorBP;
    bool emulatorBPRW;
}
