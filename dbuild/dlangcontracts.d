module dbuild.dlangcontracts;

static import std.file;
import std.stdio : writeln, writefln;
import std.format : formattedWrite;
import std.array : appender;
import std.file : timeLastModified;
import std.datetime : SysTime;

import dbuild.util : SilentException, tryRun, boolstatus, StringSink, DelegateFormatter, formatQuotedIfSpaces,
                     putf, DirAndFile, toExeName;
import dbuild.core : globalContractList, buildConfig;
import dbuild.compilers;

// allows you to define build contracts that would be carried out
// by a D compiler
struct dlang
{
    static auto exe(string name)
    {
        auto newContract = new DLangCompilerContract(DCompilerTargetType.exe, name);
        globalContractList.put(newContract);
        return newContract;
    }
}

enum DCompilerTargetType
{
    exe, staticLibrary, dynamicLibrary, objectFile
}

class DLangCompilerContract : CompilerContract
{
    // TODO: need a way to provide options
    //       that the user can specify at
    //       build time such as build mode (debug/release
    //       or enable unittest
    DCompilerTargetType targetType;
    string name;
    DirAndFile outputFile;
    string[] sources;
    string[] includePaths;
    string[] libraries;
    CompileMode compileMode;
    string objectDir = ".dbuild"; // default object directory

    private this(DCompilerTargetType targetType, string name)
    {
        this.targetType = targetType;
        this.name = name;
        this.outputFile = DirAndFile(toExeName(name));
    }
    auto setCompileMode(CompileMode compileMode)
    {
        this.compileMode = compileMode;
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

    override immutable(Language)[] getSourceLanguages()
    {
        return LanguageLists.dlangOnly;
    }
    override boolstatus clean()
    {
      if(std.file.exists(outputFile.getDirAndName))
      {
          writefln("removing %s", outputFile.getDirAndName.formatQuotedIfSpaces);
          std.file.remove(outputFile.getDirAndName);
      }
      return boolstatus.success;
    }
    override boolstatus build()
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
        auto compiler = buildConfig.getCompiler(this);
        if(!compiler)
        {
            writefln("Error: cannot find a %s compiler for %s",
                formatLanguages(getSourceLanguages()), this.formatForMessage());
            return boolstatus.fail;
        }
        auto exitCode = compiler.compile(this);
        return (exitCode == 0) ? boolstatus.success : boolstatus.fail;
    }

    override DelegateFormatter formatForMessage()
    {
        return DelegateFormatter(&formatterForMessage);
    }
    private void formatterForMessage(StringSink sink)
    {
        formattedWrite(sink, "the \"%s\" %s", name, targetType);
    }

    //
    // dmd compiler interface
    //
    auto getOutputFile() { return outputFile.getDirAndName(); }
    auto getObjectDir() { return objectDir; }
}

class DmdCompilerDefinition : CompilerDefinition
{
    this() immutable
    {
        super("dmd", LanguageLists.dlangOnly);
    }
    override int compile(Compiler instance, CompilerContract genericContract) const
    {
        auto contract = cast(DLangCompilerContract)genericContract;
        if(contract is null)
        {
            writefln("Error: the dmd compiler cannot compile %s", genericContract.formatForMessage());
            throw new SilentException();
        }

        auto command = appender!(char[]);
        command.putf("%s", instance.fullPathExe.formatQuotedIfSpaces());

        {
            auto objectDir = contract.getObjectDir();
            if(objectDir !is null)
            {
                command.putf(" %s", formatQuotedIfSpaces("-od", objectDir));
            }
        }
        {
            auto outputFile = contract.getOutputFile();
            if(outputFile !is null)
            {
                command.putf(" %s", formatQuotedIfSpaces("-of", outputFile));
            }
        }

        final switch(contract.compileMode)
        {
          case CompileMode.default_:
            command.put(" -g -debug");
            break;
          case CompileMode.debug_:
            command.put(" -g -debug");
            break;
          case CompileMode.release:
            command.put(" -release");
            break;
        }

        foreach(includePath; contract.includePaths)
        {
            command.putf(" %s", formatQuotedIfSpaces("-I", includePath));
        }
        foreach(library; contract.libraries)
        {
            command.putf(" %s", formatQuotedIfSpaces(library));
        }

        foreach(source; contract.sources)
        {
            command.putf(" %s", source.formatQuotedIfSpaces);
        }

        return tryRun(cast(string)command.data);
    }
}
