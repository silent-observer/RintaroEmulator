module register;

import mybitconverter;
/**
 * Register
 */
struct Register(size_t size)
if (size == 16 || size == 32 || size == 8 || size == 4 || size == 3) {

    static if (size == 32) alias T = uint;
    else alias T = ushort;

private:
    T _value;

    invariant {
        assert(_value >= 0);
        static if(size == 16) assert(_value <= ushort.max);
        else static if(size == 4) assert(_value <= 15);
        else static if(size == 3) assert(_value <= 7);
        else static if(size == 8) assert(_value <= 255);
    }
public:
    this(T value) pure {
        this._value = value;
    }
    @property T value() pure const 
    out (result) {
        static if(size == 16) assert(_value <= ushort.max);
        else static if(size == 4) assert(_value <= 15);
        else static if(size == 3) assert(_value <= 7);
        else static if(size == 8) assert(_value <= 255);
    }
    body {
        return _value;
    }
    @property void value(in T arg) pure {
        _value = arg;
        static if(size == 16) _value &= ushort.max;
        else static if(size == 4) _value &= 15;
        else static if(size == 3) _value &= 7;
        else static if(size == 8) _value &= 255;
    }

    T opUnary(string s)() if (s == "+" || s == "-" || s == "~") {
        mixin("return " ~ s ~ "value;");
    }
    typeof(this) opUnary(string s)() if (s == "++" || s == "--") {
        mixin("value = cast(T)(value " ~ s[0] ~ " 1);");
        return this;
    }
    void opAssign(T rhs) pure {
        value = rhs;
    }
    void opOpAssign(string s)(T rhs) pure {
        mixin("value = cast(T)(value " ~ s ~ " rhs);");
    }
    bool opEquals(T rhs) pure {
        return value == rhs;
    }

    alias value this;
}

/**
 * FlagRegister
 */
struct FlagRegister
{
    Register!4 reg;
    @property bool c() pure const {
        return value.getBit(3);
    } 
    @property void c(in bool arg) pure {
        value = value.setBitNoRef(3, arg);
    }
    @property bool n() pure const {
        return value.getBit(2);
    } 
    @property void n(in bool arg) pure {
        value = value.setBitNoRef(2, arg);
    }
    @property bool z() pure const {
        return value.getBit(1);
    } 
    @property void z(in bool arg) pure {
        value = value.setBitNoRef(1, arg);
    }
    @property bool v() pure const {
        return value.getBit(0);
    } 
    @property void v(in bool arg) pure {
        value = value.setBitNoRef(0, arg);
    }
    alias reg this;
}

unittest
{
    auto r1 = Register!16();
    assert(r1 == 0);
    r1 = cast(ushort) 1234;
    assert(r1 == 1234);
    r1 = cast(ushort) 65536;
    assert(r1 == 0);
    r1 = cast(ushort) 65540;
    assert(r1 == 4);
    auto r2 = Register!4();
    foreach (ushort i; 0..100) {
        r2 = i;
        assert(r2 == (i & 15));
    }
    assert(r1 == 4);
    FlagRegister r3 = FlagRegister();
    assert(r3 == 0  && !r3.c && !r3.n && !r3.z && !r3.v);
    r3.c = 1;
    assert(r3 == 8  &&  r3.c && !r3.n && !r3.z && !r3.v);
    r3.z = 1;
    assert(r3 == 10 &&  r3.c && !r3.n &&  r3.z && !r3.v);
    r3.c = 0;
    assert(r3 == 2  && !r3.c && !r3.n &&  r3.z && !r3.v);
    r3.v = 1;
    assert(r3 == 3  && !r3.c && !r3.n &&  r3.z &&  r3.v);
    r3.n = 1;
    assert(r3 == 7  && !r3.c &&  r3.n &&  r3.z &&  r3.v);
    r3.c = 1;
    assert(r3 == 15 &&  r3.c &&  r3.n &&  r3.z &&  r3.v);
    r3 = 10;
    assert(r3 == 10 &&  r3.c && !r3.n &&  r3.z && !r3.v);
}
