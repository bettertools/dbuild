module dbuild.run;

import std.stdio : writeln, writefln;
import std.process : spawnShell, wait;

import dbuild.core : SilentException;

auto tryRun(string command)
{
    writefln("[SHELL] %s", command);
    auto pid = spawnShell(command);
    auto exitCode = wait(pid);
    writeln("-------------------------------------------------------");
    return exitCode;
}
void run(string command)
{
    auto exitCode = tryRun(command);
    if(exitCode)
    {
        writefln("failed with exit code %s", exitCode);
        throw new SilentException();
    }
}
