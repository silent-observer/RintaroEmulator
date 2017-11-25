module alu;

import register;
import std.conv;

class ALU {
public:
    this () pure {

    }
    uint calculate( in uint a, 
                    in uint b, 
                    ref FlagRegister flags, 
                    in uint functionCode,
                    in bool setFlags = true,
                    in bool use32bits = false) const pure
    in {
        assert(a >= 0);
        if (use32bits)
            assert(a <= uint.max, ": a = " ~ a.to!string);
        else 
            assert(a <= ushort.max, ": a = " ~ a.to!string);
        assert(b >= 0 && b <= ushort.max, ": b = " ~ b.to!string);
        assert(flags !is null, ": flags is null");
        assert(functionCode >= 0 && functionCode <= 15, ": functionCode = " ~ functionCode.to!string);
    } out (result) {
        assert (result >= 0 && result <= uint.max, ": res = " ~ result.to!string);
    } body {
        uint result = 0;
        FlagRegister newFlags = new FlagRegister;
        newFlags.value = 0;
        switch (functionCode) {
            case 0: result = a + b; 
                    if (use32bits) {
                        newFlags.c = ((a >> 31) || (b >> 31)) && !(result >> 31);
                        result &= uint.max;
                    } else {
                        newFlags.c = cast(bool) (result >> 15);
                        result &= ushort.max;
                    } 
                    newFlags.v = ((a >> 15) == (b >> 15)) && ((a >> 15) != (result >> 15)); 
                    break;
            case 1: result = a + b + flags.c;
                    if (use32bits) {
                        newFlags.c = ((a >> 31) || (b >> 31)) && !(result >> 31);
                        result &= uint.max;
                    } else {
                        newFlags.c = cast(bool) (result >> 15);
                        result &= ushort.max;
                    } 
                    newFlags.v = ((a >> 15) == (b >> 15)) && ((a >> 15) != (result >> 15)); 
                    break;
            case 2: result = a - b;
                    if (use32bits) {
                        newFlags.c = !(((a >> 31) || (b >> 31)) && !(result >> 31));
                        result &= uint.max;
                    } else {
                        newFlags.c = !(result >> 15);
                        result &= ushort.max;
                    } 
                    newFlags.v = ((a >> 15) == (-b >> 15)) && ((a >> 15) != (result >> 15)); 
                    break;
            case 3: result = a - b - flags.c;
                    if (use32bits) {
                        newFlags.c = !(((a >> 31) || (b >> 31)) && !(result >> 31));
                        result &= uint.max;
                    } else {
                        newFlags.c = !(result >> 15);
                        result &= ushort.max;
                    } 
                    newFlags.v = ((a >> 15) == (-b >> 15)) && ((a >> 15) != (result >> 15)); 
                    break;
            case 4:
            case 5: result = (cast(short)a * cast(short)b) & uint.max; break;
            case 6: result = (a & 0xFFFF8000) | (b & 0x00007FFF); break;
            case 7: result = (cast(short)a >> (b & 0xF)) & ushort.max;
                    newFlags.c = (cast(short)a >> ((b-1) & 0xF)) & 1;
                    break;
            case 8: result = (cast(ushort)a << (b & 0xF)) & ushort.max;
                    newFlags.c = (cast(short)a >> ((16-b) & 0xF)) & 1;
                    break;
            case 9: result = (cast(ushort)a >>> (b & 0xF)) & ushort.max; 
                    newFlags.c = (cast(short)a >> ((b-1) & 0xF)) & 1;
                    break;
            case 10: result = (cast(ushort)a << (b & 0xF) | cast(ushort)a >>> ((16-b) & 0xF)) & ushort.max; break;
            case 11: result = (cast(ushort)a >>> (b & 0xF) | cast(ushort)a << ((16-b) & 0xF)) & ushort.max; break;
            case 12: result = a & b; break;
            case 13: result = a | b; break;
            case 14: result = a ^ b; break;
            case 15: result = ~(cast(ushort)a); break;
            default: assert(0);
        }
        newFlags.z = result == 0;
        newFlags.n = cast(bool) (((result >> 16) == 0) ? result >> 15 : result >> 31);
        if (setFlags) flags.value = newFlags.value;
        return result;
    }
} 

unittest
{
    ALU alu = new ALU;
    auto flags = new FlagRegister;
    assert(alu.calculate(1, 2, flags, 0) == 3 && flags.value == 0);
    flags.value = 8;
    assert(alu.calculate(1, 2, flags, 1) == 4 && flags.value == 0);
    assert(alu.calculate(1, 2, flags, 2) == ((~1 + 1) & ushort.max) && flags.value == 4);
    flags.value = 8;
    assert(alu.calculate(1, 2, flags, 3) == ((~2 + 1) & ushort.max) && flags.value == 4);
    assert(alu.calculate(1, 2, flags, 4) == 2 && flags.value == 0);
    assert(alu.calculate(1, 2, flags, 5) == 2 && flags.value == 0);
    assert(alu.calculate((~1+1)&ushort.max, 2, flags, 4) == ((~2+1)&uint.max) && flags.value == 4);
    assert(alu.calculate(1, (~2+1)&ushort.max, flags, 5) == ((~2+1)&uint.max) && flags.value == 4);
    assert(alu.calculate(0b1001_0100_1001_0100, 0b0000_0101, flags, 6) == 0b1000_0000_0000_0101 && flags.value == 4);
    assert(alu.calculate(0b1001_0100_1001_0100, 2, flags, 7) == 0b1110_0101_0010_0101 && flags.value == 4);
    assert(alu.calculate(0b1001_0100_1001_0100, 2, flags, 8) == 0b0101_0010_0101_0000 && flags.value == 0);
    assert(alu.calculate(0b1001_0100_1001_0100, 2, flags, 9) == 0b0010_0101_0010_0101 && flags.value == 0);
    assert(alu.calculate(0b1001_0100_1001_0100, 2, flags, 10) == 0b0101_0010_0101_0010 && flags.value == 0);
    assert(alu.calculate(0b1001_0100_1001_0100, 2, flags, 11) == 0b0010_0101_0010_0101 && flags.value == 0);
    assert(alu.calculate(0b1001_0100_1001_0100, 0b0001_0110_1000_0110, flags, 12) == 0b0001_0100_1000_0100 && flags.value == 0);
    assert(alu.calculate(0b1001_0100_1001_0100, 0b0001_0110_1000_0110, flags, 13) == 0b1001_0110_1001_0110 && flags.value == 4);
    assert(alu.calculate(0b1001_0100_1001_0100, 0b0001_0110_1000_0110, flags, 14) == 0b1000_0010_0001_0010 && flags.value == 4);
    assert(alu.calculate(0b1001_0100_1001_0100, 0b0001_0110_1000_0110, flags, 15) == 0b0110_1011_0110_1011 && flags.value == 0);
}