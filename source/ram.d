import std.stdio;

enum romSize = 1024;
enum stackSize = 1024;
enum heapSize = 4096;
/**
 * RAM
 */
class RAM(bool log = false)
{
private:
    ushort[romSize] rom; 
    ushort[stackSize] stack;
    ushort[heapSize] heap;
    ushort[128] fastMem;

    void delegate (ushort) lcdDataWrite;
    void delegate (ushort) lcdCtrlWrite;

    uint keyboardAddr, irAddr, bpAddr;
    bool keyboardEn, irEn, bp0En, bp1En, bp2En, bp3En;
    uint bp0Addr, bp1Addr, bp2Addr, bp3Addr;


public:
    this(string filename)
    {
        import std.file;
        import std.string;
        import std.conv;
        string text = readText(filename);
        auto index = text.indexOf("000:");
        foreach(line; text[index..$].splitLines) {
            auto addr = line.parse!uint(16);
            foreach(word; line[2..$].split[0..$-1])
                rom[addr++] = word.to!ushort(16);
        }
    }
    void memWrite (uint addr, ushort value) {
        import mybitconverter;
        static if (log)
            writefln("*%08X <- %04X", addr, value);
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
            case 0xFFFF0001: lcdCtrlWrite(value & 0x3); break;

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
        ushort value = 0;
        if (addr >= 0x00000000 && addr <= 0x000FFFFF) value = rom[addr%romSize]; // ROM
        else if (addr >= 0xD0000000 && addr <= 0xD000FFFF) value = stack[addr%stackSize]; // Stack
        else if (addr >= 0x10000000 && addr <= 0x8FFFFFFF) value = heap[addr%heapSize]; // Heap
        else if (addr >= 0xFFFF1000 && addr <= 0xFFFF107F) value = fastMem[addr%128]; // Fast memory

        static if (log)
            writefln("*%08X -> %04X", addr, value);

        return value;
    }
} unittest
{
    import std.format : format;
    auto ram = new RAM!false("main.mif");
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