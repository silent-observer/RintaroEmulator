import std.stdio;
import std.format : format;
import lcd;

enum romSize = 1024;
enum stackSize = 1024;
enum heapSize = 4096;
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
    ushort[128] fastMem;

    string[romSize] romComments; 

    void delegate (ushort) lcdDataWrite;
    void delegate (ushort) lcdCtrlWrite;

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
                rom[addr++] = word.to!ushort(16);
            }
        }
    }
    void memWrite (uint addr, ushort value) {
        import mybitconverter;
        import std.algorithm : canFind;
        log(format("*%08X <- %04X", addr, value));
        if (emulatorBP.canFind(addr)) {
            stopFlag = true;
            lastEmulatorBP = addr;
            emulatorBPRW = true;
        }
        if (addr >= 0x00000000 && addr <= 0x000FFFFF) return; // ROM
        else if (addr >= 0xD0000000 && addr <= 0xD000FFFF) { // Stack
            stack[addr%stackSize] = value;
            return;
        }
        else if (addr >= 0x10000000 && addr <= 0x8FFFFFFF) { // Heap
            heap[addr%heapSize] = value;
            return;
        }
        else if (addr >= 0xFFFF1000 && addr <= 0xFFFF107F) { // Fast memory
            fastMem[addr%128] = value;
            return;
        }
        else 
        switch (addr) {
            case 0xFFFF0000: lcdDataWrite(value & 0xFF); break;
            case 0xFFFF0001: lcdCtrlWrite(value & 0x7); break;

            case 0xFFFFFFFA: irEn = value > 0; break;
            case 0xFFFFFFFB: irAddr.setBits(0, 16, value); break;
            case 0xFFFFFFFC: irAddr.setBits(16, 32, value); break;
            case 0xFFFFFFFD: keyboardEn = value > 0; break;
            case 0xFFFFFFFE: keyboardAddr.setBits(0, 16, value); break;
            case 0xFFFFFFFF: keyboardAddr.setBits(16, 32, value); break;

            case 0xFFFFF000: bp0En = value > 0; break;
            case 0xFFFFF001: bp0Addr.setBits(0, 16, value); break;
            case 0xFFFFF002: bp0Addr.setBits(16, 32, value); break;
            case 0xFFFFF003: bp1En = value > 0; break;
            case 0xFFFFF004: bp1Addr.setBits(0, 16, value); break;
            case 0xFFFFF005: bp1Addr.setBits(16, 32, value); break;
            case 0xFFFFF006: bp2En = value > 0; break;
            case 0xFFFFF007: bp2Addr.setBits(0, 16, value); break;
            case 0xFFFFF008: bp2Addr.setBits(16, 32, value); break;
            case 0xFFFFF009: bp3En = value > 0; break;
            case 0xFFFFF00A: bp3Addr.setBits(0, 16, value); break;
            case 0xFFFFF00B: bp3Addr.setBits(16, 32, value); break;
            case 0xFFFFF00C: bpAddr.setBits(0, 16, value); break;
            case 0xFFFFF00D: bpAddr.setBits(16, 32, value); break;
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
        if (addr >= 0x00000000 && addr <= 0x000FFFFF) value = rom[addr%romSize]; // ROM
        else if (addr >= 0xD0000000 && addr <= 0xD000FFFF) value = stack[addr%stackSize]; // Stack
        else if (addr >= 0x10000000 && addr <= 0x8FFFFFFF) value = heap[addr%heapSize]; // Heap
        else if (addr >= 0xFFFF1000 && addr <= 0xFFFF107F) value = fastMem[addr%128]; // Fast memory

        log(format("*%08X -> %04X", addr, value));

        return value;
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

    uint[] emulatorBP;
    bool stopFlag;
    uint lastEmulatorBP;
    bool emulatorBPRW;


} unittest
{
    import std.format : format;
    auto ram = new RAM("main.mif", function void(string) {return;});
    assert(ram.memRead(0) == 0x0805);
    assert(ram.memRead(1) == 0x0001);
    assert(ram.memRead(2) == 0xFFFF);
    assert(ram.memRead(3) == 0xF000);
    assert(ram.memRead(4) == 0x0005);
    assert(ram.memRead(5) == 0xFFFF);
    assert(ram.memRead(6) == 0xF002);
    assert(ram.memRead(7) == 0x0000);
    assert(ram.memRead(8) == 0x0805);
    assert(ram.memRead(0xD000FFFF) == 0);
    foreach (ushort i; 0..15)
        ram.memWrite(0xD000FFFF-i, i);
    foreach (ushort i; 0..15)
        assert(ram.memRead(0xD000FFFF-i) == i);
    foreach (ushort i; 0..15)
        ram.memWrite(0xD000FFFF-i, cast(ushort) (2*i+1));
    foreach (ushort i; 0..15)
        assert(ram.memRead(0xD000FFFF-i) == 2*i+1);
}