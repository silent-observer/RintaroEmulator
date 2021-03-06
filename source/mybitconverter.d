module mybitconverter;
import std.traits;


public bool getBit(T)(T value, int bitNumber)
if (isIntegral!T) {
    return cast(T) ((value >> bitNumber) & 1);
} unittest
{
    assert((0x1234).getBit(0) == 0);
    assert((0x1234).getBit(1) == 0);
    assert((0x1234).getBit(2) == 1);
    assert((0x1234).getBit(3) == 0);

    assert((0x1234).getBit(4) == 1);
    assert((0x1234).getBit(5) == 1);
    assert((0x1234).getBit(6) == 0);
    assert((0x1234).getBit(7) == 0);

    assert((0x1234).getBit(8) == 0);
    assert((0x1234).getBit(9) == 1);
    assert((0x1234).getBit(10) == 0);
    assert((0x1234).getBit(11) == 0);

    assert((0x1234).getBit(12) == 1);
    assert((0x1234).getBit(13) == 0);
    assert((0x1234).getBit(14) == 0);
    assert((0x1234).getBit(15) == 0);
}

public T getBits(T)(T value, int bitStart, int bitEnd)
if (isIntegral!T){
    return cast(T) ((value >> bitStart) & ((1 << (bitEnd - bitStart)) - 1));
} unittest
{
    assert((0x1234).getBits(0, 4) == 0x4);
    assert((0x1234).getBits(4, 8) == 0x3);
    assert((0x1234).getBits(8, 12) == 0x2);
    assert((0x1234).getBits(12, 16) == 0x1);

    assert((0x1234).getBits(0, 8) == 0x34);
    assert((0x1234).getBits(4, 12) == 0x23);
    assert((0x1234).getBits(8, 16) == 0x12);

    assert((0x1234).getBits(0, 12) == 0x234);
    assert((0x1234).getBits(4, 16) == 0x123);

    assert((0x1234).getBits(0, 16) == 0x1234);
}

public void setBit(T)(ref T value, int bitNumber, bool bitValue)
if (isIntegral!T){
    value = (value & ~(1 << bitNumber)) | (bitValue << bitNumber);
} unittest
{
    uint value = 0;
    value.setBit(0, 1);
    assert (value.getBit(0) == 1);
    value.setBit(7, 1);
    assert (value.getBit(7) == 1);
    value.setBit(0, 0);
    assert (value.getBit(0) == 0);
    value.setBit(3, 0);
    assert (value.getBit(3) == 0);
    value.setBit(0, 1);
    assert (value.getBit(0) == 1);
}

public void setBits(T)(ref T value, int bitStart, int bitEnd, T bitValues)
if (isIntegral!T){
    T bitMask = (T.max << bitStart) & ~(T.max << bitEnd);
    value = (value & ~bitMask) | ((bitValues << bitStart) & bitMask);
} unittest
{
    uint value = 0;
    value.setBits(0, 4, 0x4);
    assert (value.getBits(0, 4) == 0x4);
    value.setBits(3, 11, 0x5C);
    assert (value.getBits(3, 11) == 0x5C);
}

public T setBitNoRef(T)(T value, int bitNumber, bool bitValue)
if (isIntegral!T){
    return cast(T) ((value & ~(1 << bitNumber)) | (bitValue << bitNumber));
}
unittest
{
    uint value = 0;
    value = value.setBitNoRef(0, 1);
    assert (value.getBit(0) == 1);
    value = value.setBitNoRef(7, 1);
    assert (value.getBit(7) == 1);
    value = value.setBitNoRef(0, 0);
    assert (value.getBit(0) == 0);
    value = value.setBitNoRef(3, 0);
    assert (value.getBit(3) == 0);
    value = value.setBitNoRef(0, 1);
    assert (value.getBit(0) == 1);
}

public T setBitsNoRef(T)(T value, int bitStart, int bitEnd, T bitValues)
if (isIntegral!T){
    T bitMask = cast(T) ((T.max << bitStart) & ~(T.max << bitEnd));
    return cast(T) ((value & ~bitMask) | ((bitValues << bitStart) & bitMask));
} unittest
{
    uint value = 0;
    value = value.setBitsNoRef(0, 4, 0x4);
    assert (value.getBits(0, 4) == 0x4);
    value = value.setBitsNoRef(3, 11, 0x5C);
    assert (value.getBits(3, 11) == 0x5C);
}

public T signedExtend(T)(T value, int bitCount)
if (isIntegral!T) {
    if (value.getBit(bitCount-1))
        return cast(T) ((-1 << bitCount) | value);
    else
        return value;
} unittest
{
    assert((0x0034).signedExtend(ushort)(8) == 0x0034);
    assert((0x00A4).signedExtend(ushort)(8) == 0xFFA4);

    assert((0x0734).signedExtend(ushort)(12) == 0x0734);
    assert((0x0834).signedExtend(ushort)(12) == 0xF834);

    assert((0x0334).signedExtend(ushort)(11) == 0x0334);
    assert((0x0734).signedExtend(ushort)(11) == 0xFF34);
}

public ushort maskWith(ushort prevValue, ushort value, ubyte mask) {
    if (mask == 0x1)
        return cast(ushort) (value | (prevValue & 0xFF00));
    else if (mask == 0x2)
        return cast(ushort) ((value << 8) | (prevValue & 0x00FF));
    else
        return value;
} unittest
{
    assert((0x1234).maskWith(0x0056, 0x1) == 0x1256);
    assert((0x1234).maskWith(0x0056, 0x2) == 0x5634);
    assert((0x1234).maskWith(0x0056, 0x3) == 0x0056);
}

public ushort maskWithRef(ref ushort prevValue, ushort value, ubyte mask) {
    if (mask == 0x1)
        prevValue = cast(ushort) (value | (prevValue & 0xFF00));
    else if (mask == 0x2)
        prevValue = cast(ushort) ((value << 8) | (prevValue & 0x00FF));
    else
        prevValue = value;
    return prevValue;
} unittest
{
    ushort reg = 0x1234
    reg.maskWithRef(0x0056, 0x1)
    assert(reg == 0x1256);
    reg.maskWithRef(0x0078, 0x2)
    assert(reg == 0x7856);
    reg.maskWithRef(0x009A, 0x3)
    assert(reg == 0x009A);
}
