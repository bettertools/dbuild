static import std.file;

import std.stdio;
import std.datetime : SysTime;
import std.file : exists, getcwd, timeLastModified, chdir, rmdir, thisExePath, dirEntries, SpanMode;
import std.path : buildPath, dirName;
import std.string : indexOf, endsWith;
import std.format : format, formattedWrite;
import std.array : Appender, appender;
import std.process : spawnShell, wait;

import dbuild.util : formatQuotedIfSpaces, putf, failed;
import dbuild.core : SilentException, DbuildHiddenDir, Exe, exe, BuildMode, CommandHandlerCode;
import dbuild.run : run, tryRun;

__gshared bool verbose = false;

//
// TODO: support all 3 D-compilers?
//       should probably default to dmd, if it isn't found then
//       use either ldc or gdc, whichever is found first
//       the reason for deafaulting to dmd is that speed of the build executable
//       doesn't really matter, what we want is for it to work. some systems may
//       only have ldc or gdc, so just use those if dmd isn't there
//
// TODO: I might add configuration to the .dbuild directory
//

version(Windows)
{
    enum pathSeparatorChar = '\\';
    enum ObjectFileExtension = ".obj";
}
else
{
    enum pathSeparatorChar = '/';
    enum ObjectFileExtension = ".o";
 }

__gshared string[] passthroughArgs;
// todo: add an option to override this
__gshared string buildSource = "build.d";
__gshared bool onlyCompileBuild = false;

auto createBuildExe()
{
    return exe("build")
        .setOutputDir(DbuildHiddenDir)
        .setObjectDir(DbuildHiddenDir)
        ;
}

int main(string[] args)
{

    try { return main2(args[1..$]); }
    catch(SilentException) { return 1; }
}
int main2(string[] args)
{
    passthroughArgs = new string[args.length];
    {
        int newArgsLength = 0;
        int passthroughArgsLength = 0;
        for(size_t i = 0; i < args.length; i++)
        {
            auto arg = args[i];
            if(arg.length == 0 || arg[0] != '-')
            {
                args[newArgsLength++] = arg;
                passthroughArgs[passthroughArgsLength++] = arg;
            }
            else if(arg == "-verbose")
            {
                verbose = true;
                passthroughArgs[passthroughArgsLength++] = arg;
            }
            else if(arg == "-only-compile-build")
            {
                onlyCompileBuild = true;
            }
            else
            {
                // todo: need to pass through all the runBuild arguments in dbuild/core.d
                writefln("Error: unknown option \"%s\"", arg);
                return 1;
            }
        }
        args = args[0..newArgsLength];
        passthroughArgs = passthroughArgs[0..passthroughArgsLength];
    }

    mixin(CommandHandlerCode);

    // this is an unknown command
    return buildBuildAndRun();
}

void runBuildExe(string buildExeOutputFile)
{
    auto command = appender!(char[]);
    command.putf("%s", formatQuotedIfSpaces(format(".%s%s", pathSeparatorChar, buildExeOutputFile)));
    foreach(passthroughArg; passthroughArgs)
    {
        // todo: handle quotes in arg
        command.putf(" %s", formatQuotedIfSpaces(passthroughArg));
    }
    run(cast(string)command.data);
}

int buildBuildAndRun()
{
    auto installPath = dirName(thisExePath());
    if(verbose)
    {
        writefln("dbuild installPath = %s", installPath.formatQuotedIfSpaces);
    }
    auto dbuildPackagePath = buildPath(installPath, "dbuild");

    // Add buildExe config to build it
    auto buildExe = createBuildExe()
        .setBuildMode(BuildMode.debug_)
        .includePath(installPath)
        .source(buildSource)
        .source(buildPath(dbuildPackagePath, "package.d"))
        .source(buildPath(dbuildPackagePath, "core.d"))
        .source(buildPath(dbuildPackagePath, "util.d"))
        .source(buildPath(dbuildPackagePath, "run.d"))
        ;
    if(buildExe.build().failed)
    {
        return 1;
    }

    if(!onlyCompileBuild)
    {
        runBuildExe(buildExe.getOutputFile());
    }

    return 0;
}

int buildCommand(string[] args)
{
    return buildBuildAndRun();
}

int cleanCommand(string[] args)
{
    if(exists(DbuildHiddenDir))
    {
        auto buildExe = createBuildExe();
        auto buildExeOutputFile = buildExe.getOutputFile();
        if(exists(buildExeOutputFile))
        {
            runBuildExe(buildExeOutputFile);
            writefln("removing %s", buildExeOutputFile.formatQuotedIfSpaces);
            std.file.remove(buildExeOutputFile);
        }

        // remove all object files from .dbuild
        foreach(entry; dirEntries(DbuildHiddenDir, SpanMode.shallow))
        {
            if(entry.name.endsWith(ObjectFileExtension))
            {
                writefln("removing %s", entry.name);
                std.file.remove(entry.name);
            }
        }
        writefln("removing %s", DbuildHiddenDir.formatQuotedIfSpaces);
        rmdir(DbuildHiddenDir);
    }
    return 0;
}
