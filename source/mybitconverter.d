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