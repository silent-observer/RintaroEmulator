import std.stdio;
import rcpu;
import ram;

bool isLogging = false;

void main(string[] args)
{
    if (args.length > 2) {
        writeln(stderr, "Usage: rintaro [<.mif file>]");
        return;
    }
    RAM ram;
    RCPU rcpu = new RCPU(&log);
    bool initialized = false;

    writeln("Welcome to almighty Rintaro Emulator!");

    if (args.length == 2) {
        ram = loadFile(args[1], rcpu);
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
                    ram = loadFile(cmd[1], rcpu);
                    initialized = true;
                    break;
                }
            default: break;
        }
    }
}

private void log(string s) {
    if (isLogging)
        writeln(s);
}

private RAM loadFile(string filename, RCPU rcpu) {
    RAM ram = new RAM(filename, &log);
    rcpu.setRAM(ram);
    writeln("File ", filename, " has been successfully loaded!");
    return ram;
}