module dbuild.core;

static import std.file;

import std.stdio : writeln, writefln;
import std.file  : getcwd, timeLastModified, thisExePath, exists, remove;
import std.path  : baseName;
import std.array : appender;
import std.datetime : SysTime;

public import std.path : dirName, buildPath;

import dbuild.util : boolstatus, failed, formatQuotedIfSpaces, putf;
import dbuild.run  : tryRun;

class SilentException : Exception { this() { super(null); } }

enum DbuildHiddenDir = ".dbuild";

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

enum BuildMode { default_, debug_, release }

private __gshared Exe[] exes;
auto exe(string name)
{
    auto newExe = new Exe(name);
    exes ~= newExe;
    return newExe;
}
class Exe
{
    string name;
    DirAndFile outputFile;
    string[] sources;
    string[] includePaths;
    string[] libraries;
    BuildMode buildMode;
    string objectDir = ".dbuild"; // default object directory
    this(string name)
    {
        this.name = name;
        string nameWithExtension;
        version(Windows) {
            nameWithExtension = name ~ ".exe";
        } else {
            nameWithExtension = name;
        }
        this.outputFile = DirAndFile(nameWithExtension);
    }
    auto setBuildMode(BuildMode buildMode)
    {
        this.buildMode = buildMode;
        return this;
    }
    auto setOutputDir(string outputDir)
    {
        this.outputFile.setDir(outputDir);
        return this;
    }
    auto setObjectDir(string objectDir)
    {
        this.objectDir = objectDir;
        return this;
    }
    auto source(string sourceFile)
    {
        sources ~= sourceFile;
        return this;
    }
    auto includePath(string includePath)
    {
        includePaths ~= includePath;
        return this;
    }
    auto library(string library)
    {
        libraries ~= library;
        return this;
    }
    boolstatus clean()
    {
      if(exists(outputFile.getDirAndName))
      {
          writefln("removing %s", outputFile.getDirAndName.formatQuotedIfSpaces);
          std.file.remove(outputFile.getDirAndName);
      }
      return boolstatus.success;
    }
    boolstatus build()
    {
        auto exeTime = timeLastModified(outputFile.getDirAndName, SysTime.max);
        if(exeTime == SysTime.max)
        {
            writefln("[DEBUG] executable \"%s\" does not exist", outputFile.getDirAndName);
            return compile();
        }

        foreach(source; sources)
        {
            auto sourceTime = timeLastModified(source, SysTime.max);
            if(sourceTime == SysTime.max)
            {
                writefln("Error: cannot build \"%s\" because source file \"%s\" does not exist", outputFile.getDirAndName, source);
                return boolstatus.fail;
            }
            if(sourceTime > exeTime)
            {
                writefln("[DEBUG] source file \"%s\" (time %s) is newer than executable \"%s\" (time %s)",
                         source, sourceTime, outputFile.getDirAndName, exeTime);
                return compile();
            }
        }

        writefln("[DEBUG] executable \"%s\" is up-to-date", outputFile.getDirAndName);
        return boolstatus.success;
    }
    private boolstatus compile()
    {
        auto exitCode = runDmdCompiler(this);
        return (exitCode == 0) ? boolstatus.success : boolstatus.fail;
    }

    //
    // dmd compiler interface
    //
    auto getOutputFile() { return outputFile.getDirAndName(); }
    auto getObjectDir() { return objectDir; }
}

private struct DirAndFile
{
    private string filename;
    private string dir;
    private string dirAndName;
    this(string filename)
    {
        this.filename = filename;
    }
    @property string getFilename() { return filename; }
    @property string getDir() { return dir; }
    string getDirAndName()
    {
        if(dirAndName is null)
        {
            dirAndName = buildPath(dir, filename);
        }
        return dirAndName;
    }
    void setDir(string newDir)
    {
        this.dir = newDir;
        this.dirAndName = null;
    }
}

int runDmdCompiler(T)(T compilable)
{
  auto command = appender!(char[]);
  command.put("dmd");

  {
    auto objectDir = compilable.getObjectDir();
    if(objectDir !is null) {
      command.putf(" %s", formatQuotedIfSpaces("-od", objectDir));
    }
  }
  {
    auto outputFile = compilable.getOutputFile();
    if(outputFile !is null) {
      command.putf(" %s", formatQuotedIfSpaces("-of", outputFile));
    }
  }

  final switch(compilable.buildMode) {
  case BuildMode.default_:
    break;
  case BuildMode.debug_:
    command.put(" -debug");
    break;
  case BuildMode.release:
    command.put(" -release");
    break;
  }

  foreach(includePath; compilable.includePaths)
  {
      command.putf(" %s", formatQuotedIfSpaces("-I", includePath));
  }
  foreach(library; compilable.libraries)
  {
      command.putf(" %s", formatQuotedIfSpaces(library));
  }

  foreach(source; compilable.sources)
  {
      command.putf(" %s", source.formatQuotedIfSpaces);
  }

  return tryRun(cast(string)command.data);
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
    foreach(ref exe; exes)
    {
        if(exe.clean().failed)
        {
            status = boolstatus.fail;
        }
    }
    return boolstatus.fail ? 1 : 0;
}
private int buildCommand(string[] args)
{
    boolstatus status = boolstatus.success;
    foreach(ref exe; exes)
    {
        if(exe.build().failed)
        {
            status = boolstatus.fail;
        }
    }
    return boolstatus.fail ? 1 : 0;
}