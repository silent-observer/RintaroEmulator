import std.stdio;
import rcpu;
import ram;
import lcd;

bool isLogging = false;

void main(string[] args)
{
    if (args.length > 2) {
        writeln(stderr, "Usage: rintaro [<.mif file>]");
        return;
    }
    RAM ram;
    RCPU rcpu = new RCPU(&log);
    LCD lcd = new LCD();
    bool initialized = false;

    writeln("Welcome to almighty Rintaro Emulator!");

    if (args.length == 2) {
        ram = loadFile(args[1], rcpu, lcd);
        initialized = true;
    }

    while (true) {
        import std.string;
        write("> ");
        string[] cmd = readln().split;
        if (cmd.length == 0) continue;
        if (!initialized && cmd[0] != "load" && cmd[0] != "exit") {
            writeln("Memory is not initialized!");
            continue;
        }
        switch (cmd[0]) {
            case "exit": return;
            case "load":
                if (cmd.length != 2) {
                    writeln(stderr, "Usage: load <.mif file>");
                    break;
                } else {
                    ram = loadFile(cmd[1], rcpu, lcd);
                    initialized = true;
                    break;
                }

            case "state":
                writeln(rcpu.reportState);
                break;

            case "run":
            if (cmd.length > 2) {
                writeln(stderr, "Usage: run [<instruction count>]");
                break;
            } else {
                isLogging = false;
                int count = 1;
                if (cmd.length == 2) count = cmd[1].getInt;
                rcpu.ticks = 0;
                for (int i = 0; i < count; i++) {
                    rcpu.executeInstruction();
                    if (ram.stopFlag) {
                        import std.conv : to;
                        writefln("Breakpoint encountered after %s instructions! %s %08X",
                            i, ram.emulatorBPRW? "Write to" : "Read from", ram.lastEmulatorBP);
                        ram.stopFlag = false;
                        break;
                    }
                }
                writefln("Execution took %s ms", rcpu.ticks * 0.00256);
                break;
            }

            case "log":
            if (cmd.length > 2) {
                writeln(stderr, "Usage: log [<instruction count>]");
                break;
            } else {
                isLogging = true;
                uint count = 1;
                if (cmd.length == 2) count = cmd[1].getInt;
                rcpu.ticks = 0;
                for (uint i = 0; i < count; i++) {
                    rcpu.executeInstruction();
                    if (i != count - 1) writeln();
                    if (ram.stopFlag) {
                        import std.conv : to;
                        writefln("Breakpoint encountered after %s instructions! %s %08X",
                            i, ram.emulatorBPRW? "Write to" : "Read from", ram.lastEmulatorBP);
                        ram.stopFlag = false;
                        break;
                    }
                }
                writefln("Execution took %s ms", rcpu.ticks * 0.00256);
                break;
            }

            case "read":
            if (cmd.length != 2 && cmd.length != 3) {
                writeln(stderr, "Usage: read <start address> [<end address>]");
                break;
            } else {
                isLogging = true;
                uint startAddr = cmd[1].getInt;
                uint endAddr = startAddr;
                if (cmd.length == 3) endAddr = cmd[2].getInt;
                for (uint i = startAddr; i <= endAddr; i += 2)
                    ram.memRead(i);
                break;
            }

            case "write":
            if (cmd.length != 3 && cmd.length != 4) {
                writeln(stderr, "Usage: write <start address> [<end address>] <data>");
                break;
            } else {
                isLogging = true;
                uint startAddr = cmd[1].getInt;
                uint endAddr = startAddr;
                ushort data = cast(ushort) cmd[$-1].getInt;
                if (cmd.length == 4) endAddr = cmd[2].getInt;
                for (uint i = startAddr; i <= endAddr; i += 2)
                    ram.memWrite(i, data);
                break;
            }

            case "stack": {
                isLogging = false;
                uint endAddr = rcpu.sp < 0xFFE0 ? 0xD000001E + rcpu.sp : 0xD000FFFE;
                for (uint i = 0xD0000000 + rcpu.sp; i <= endAddr; i += 2) {
                    writef("%08X: %04X", i, ram.memRead(i));
                    if ((i & 0xFFFF) == rcpu.fp - 2) writef(" <- [-4]");
                    else if ((i & 0xFFFF) == rcpu.fp - 1) writef(" <- [-2]");
                    else if ((i & 0xFFFF) == rcpu.fp + 0) writef(" <- FP");
                    else if ((i & 0xFFFF) == rcpu.fp + 1) writef(" <- [2]");
                    else if ((i & 0xFFFF) == rcpu.fp + 2) writef(" <- [4]");
                    else if ((i & 0xFFFF) == rcpu.fp + 3) writef(" <- [6]");
                    else if ((i & 0xFFFF) == rcpu.fp + 4) writef(" <- [8]");
                    else if ((i & 0xFFFF) == rcpu.fp + 5) writef(" <- [10]");
                    if ((i & 0xFFFF) == rcpu.sp.value) writef(" <- SP");
                    writeln();
                }
                break;
            }

            case "reset":
                rcpu.reset();
                break;

            case "bpadd": if (cmd.length != 2) {
                writeln(stderr, "Usage: bpadd <address>");
                break;
            } else {
                ram.emulatorBP ~= cmd[1].getInt;
                break;
            }

            case "bplist":
                foreach (addr; ram.emulatorBP)
                    writefln("%08X", addr);
                break;

            case "bpremove": if (cmd.length != 2) {
                writeln(stderr, "Usage: bpremove <address>");
                break;
            } else {
                import std.algorithm;
                int index = ram.emulatorBP.countUntil(cmd[1].getInt);
                if (index == -1) writeln("No such breakpoint!");
                else ram.emulatorBP = ram.emulatorBP.remove(index);
                break;
            }

            case "lcd": writeln(lcd); break;

            case "ir": if (cmd.length != 2) {
                writeln(stderr, "Usage: ir <number>");
                break;
            } else {
                ram.irInterrupt(cast(ubyte) cmd[1].getInt);
                break;
            }
            case "key": if (cmd.length != 2) {
                writeln(stderr, "Usage: key <code>");
                break;
            } else {
                ram.keyInterrupt(cast(ubyte) cmd[1].getInt);
                break;
            }

            case "help":
                writeln("bpadd <address> -- Add emulator breakpoint");
                writeln("bplist -- List all emulator breakpoints");
                writeln("bpremove <address> -- Remove emulator breakpoint");
                writeln("exit -- Exit from emulator");
                writeln("help -- Show this text");
                writeln("ir <number> -- Press number key on the IR remote");
                writeln("key <code> -- Press key on the keyboard");
                writeln("lcd -- Show LCD content");
                writeln("load <.mif file> -- Load file to ROM");
                writeln("log [<instruction count>] -- Execute instructions with logging");
                writeln("read <start address> [<end address>] -- Read memory content");
                writeln("reset -- Reset RCPU to default state (file is still loaded)");
                writeln("run [<instruction count>] -- Execute instructions without logging");
                writeln("state -- Show current RCPU state");
                writeln("stack -- Show stack content");
                writeln("write <start address> [<end address>] <data> -- Write data to memory");
                break;

            default: writeln("Invalid instruction \"", cmd[0],
                "\", use \"help\" command to see all available instructions."); break;
        }
    }
}

private void log(string s) {
    if (isLogging)
        writeln(s);
}

private RAM loadFile(string filename, RCPU rcpu, LCD lcd) {
    RAM ram = new RAM(filename, &log);
    ram.setLCD(lcd);
    ram.setInterruptCallback(&rcpu.interrupt);
    rcpu.setRAM(ram);
    writeln("File ", filename, " has been successfully loaded!");
    return ram;
}

private uint getInt(string s) {
    import std.conv : to;
    if (s.length < 2) return s.to!uint;
    if (s[0..2] == "0x") return s[2..$].to!uint(16);
    if (s[0..2] == "0b") return s[2..$].to!uint(2);
    if (s[0..2] == "0o") return s[2..$].to!uint(8);
    return s.to!uint;
}
