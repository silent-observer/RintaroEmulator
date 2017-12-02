module lcd;
import register;

/**
 * LCD
 */
class LCD
{
private:
    Register!8 data;
    Register!3 ctrl;

    char[20][4] text;
    ubyte col, row;

public:
    this() pure
    {
        text[0][] = ' ';
        text[1][] = ' ';
        text[2][] = ' ';
        text[3][] = ' ';
        data = 0;
        ctrl = 0;
        col = 0;
        row = 0;
    }
    void writeData(ushort x) pure {
        data = x;
    }
    void writeCtrl(ushort x) pure {
        import mybitconverter;
        if (!ctrl.value.getBit(0) && x.getBit(0) && !x.getBit(1)) {
            if (x.getBit(2)) {
                text[row][col++] = cast(char) data.value;
                if (col == 20) {
                    col = 0; 
                    if (row < 2) row += 2;
                    else if (row == 2) row = 1;
                    else if (row == 3) row = 0;
                }
                if (row == 4) {
                    row = 0;
                }
            } else {
                if (data == 1) {
                    text[0][] = ' ';
                    text[1][] = ' ';
                    text[2][] = ' ';
                    text[3][] = ' ';
                    col = 0;
                    row = 0;
                } else if (data.value.getBit(7)) {
                    if (data >= 0x80 && data <= 0x93) {
                        row = 0; col = cast(ubyte) (data - 0x80);
                    } else if (data >= 0xC0 && data <= 0xD3) {
                        row = 1; col = cast(ubyte) (data - 0xC0);
                    } else if (data >= 0x94 && data <= 0xA7) {
                        row = 2; col = cast(ubyte) (data - 0x94);
                    } else if (data >= 0xD4 && data <= 0xE7) {
                        row = 3; col = cast(ubyte) (data - 0xD4);
                    }
                }
            }
        }
        ctrl = x;
    }
    override string toString() pure const{
        return "+--------------------+\n" ~
               "|" ~ text[0] ~      "|\n" ~
               "|" ~ text[1] ~      "|\n" ~
               "|" ~ text[2] ~      "|\n" ~
               "|" ~ text[3] ~      "|\n" ~
               "+--------------------+";
    }
}

unittest
{
    LCD lcd = new LCD();
    lcd.writeData('A');
    lcd.writeCtrl(4);
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);
    lcd.writeData('B');
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);
    lcd.writeData('C');
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);

    lcd.writeData(0xC3);
    lcd.writeCtrl(0);
    lcd.writeCtrl(1);
    lcd.writeCtrl(0);

    lcd.writeData('D');
    lcd.writeCtrl(4);
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);
    lcd.writeData('E');
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);
    lcd.writeData('F');
    lcd.writeCtrl(5);
    lcd.writeCtrl(4);

    assert(lcd.toString ==  "+--------------------+\n" ~
                            "|ABC                 |\n" ~
                            "|   DEF              |\n" ~
                            "|                    |\n" ~
                            "|                    |\n" ~
                            "+--------------------+");

    lcd.writeData(0x01);
    lcd.writeCtrl(0);
    lcd.writeCtrl(1);
    lcd.writeCtrl(0);

    assert(lcd.toString ==  "+--------------------+\n" ~
                            "|                    |\n" ~
                            "|                    |\n" ~
                            "|                    |\n" ~
                            "|                    |\n" ~
                            "+--------------------+");
}