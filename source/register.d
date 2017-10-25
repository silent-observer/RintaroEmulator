/**
 * Register
 */
class Register(size_t size)
    if (size == 16 || size == 32 || size == 4)
{
private:
    uint _value;

    invariant {
        assert(_value >= 0);
        assert(_value < (1 << size));
    }
public:
    this() pure {
        _value = 0;
    }
    @property uint value() pure const 
    out (result) {
        assert(result < (1 << size));
    }
    do {
        return _value;
    }
    @property value(in uint arg) pure {
        _value = arg & ((1 << size) - 1);
    }
}

unittest
{
    auto r1 = new Register!16;
    assert(r1.value == 0);
    r1.value = 1234;
    assert(r1.value == 1234);
    r1.value = 65536;
    assert(r1.value == 0);
    r1.value = 65540;
    assert(r1.value == 4);
    auto r2 = new Register!4;
    foreach (i; 0..100) {
        r2.value = i;
        assert(r2.value == (i & 15));
    }
    assert(r1.value == 4);
}
