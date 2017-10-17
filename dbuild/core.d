module dbuild.core;

static import std.file;

import std.stdio  : writeln, writefln;
import std.format : formattedWrite;
import std.file   : getcwd, timeLastModified, thisExePath, exists, remove;
import std.path   : baseName;
import std.array  : appender, Appender;
import std.datetime : SysTime;

public import std.path : dirName, buildPath;

import dbuild.util : SilentException, tryRun, boolstatus, StringSink, DelegateFormatter,
                     failed, formatQuotedIfSpaces, putf, DirAndFile;
import dbuild.config : BuildConfig;
import dbuild.dlangcontracts : DmdCompilerDefinition;

__gshared BuildConfig buildConfig;

version(Windows)
{
    enum PathSeparatorChar = '\\';
    enum MultiPathDelimiterChar = ';';
    // NOTE: ObjectFileExtension should probably be moved somewhere more specific
    //       to compilers rather than the generic core build
    enum ObjectFileExtension = ".obj";
}
else
{
    enum PathSeparatorChar = '/';
    enum MultiPathDelimiterChar = ':';
    // NOTE: ObjectFileExtension should probably be moved somewhere more specific
    //       to compilers rather than the generic core build
    enum ObjectFileExtension = ".o";
}

enum DbuildHiddenDir = ".dbuild";
enum DbuildConfigFilename = DbuildHiddenDir ~ PathSeparatorChar ~ "config";

// directory of build.d file
auto buildDir(string fileFullPath = __FILE_FULL_PATH__)
{
  auto parentDir = dirName(thisExePath());
  auto parentDirBaseName = baseName(parentDir);
  if(parentDirBaseName != DbuildHiddenDir) {
    writefln("Error: expected parent directory of this executable to be \"%s\" but it is \"%s\"",
             DbuildHiddenDir, parentDirBaseName);
    throw new SilentException();
  }
  return dirName(parentDir);
}
//
// TODO: might use in future to allow contracts to specify the
//       type of files it is creating or using
//
enum FileClass
{
    executable,
    commandLinExecutable, // child of executable
}

Appender!(BuildContract[]) globalContractList;
class BuildContract
{
    abstract boolstatus clean();
    abstract boolstatus build();
    abstract DelegateFormatter formatForMessage();
}

class BuildContractor
{
}

int runBuild(string[] args)
{
    try { return runBuild2(args[1..$]); }
    catch(SilentException) { return 1; }
}

private void usage()
{
  writeln("Usage: build <command>");
  writeln();
  writeln("Commands:");
  writeln("  build (default)  perform the build");
  writeln("  clean            clean the build");
}
private bool verbose = false;
private int runBuild2(string[] args)
{
    // load settings
    if(exists(DbuildConfigFilename))
    {
        buildConfig.load(DbuildConfigFilename);
    }

    {
        int newArgsLength = 0;
        for(size_t i = 0; i < args.length; i++)
        {
            auto arg = args[i];
            if(arg.length == 0 || arg[0] != '-')
            {
                args[newArgsLength++] = arg;
            }
            else if(arg == "-verbose")
            {
                verbose = true;
            }
            else if(arg == "-help" || arg == "-h")
            {
                usage();
                return 1;
            }
            else
            {
                writefln("Error: unknown option \"%s\"", arg);
                return 1;
            }
        }
        args = args[0..newArgsLength];
    }

    mixin(CommandHandlerCode);

    writefln("Error: extended commands are not implemented (command=\"%s\")", command);
    return 1;
}

enum CommandHandlerCode = `
    if(args.length == 0) {
        return buildCommand(args);
    }
    auto command = args[0];
    args = args[1..$];
    if(command == "build") {
      return buildCommand(args);
    }
    if(command == "clean") {
      return cleanCommand(args);
    }
`;

private int cleanCommand(string[] args)
{
    boolstatus status = boolstatus.success;
    foreach(ref contract; globalContractList.data)
    {
        if(contract.clean().failed)
        {
            status = boolstatus.fail;
        }
    }
    return boolstatus.fail ? 1 : 0;
}
private int buildCommand(string[] args)
{
    boolstatus status = boolstatus.success;
    foreach(ref contract; globalContractList.data)
    {
        if(contract.build().failed)
        {
            status = boolstatus.fail;
        }
    }
    return boolstatus.fail ? 1 : 0;
}