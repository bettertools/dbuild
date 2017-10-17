module dbuild.config;

import std.stdio   : stdin, stdout, write, writef, writeln, writefln;
import std.file    : exists;
import std.path    : buildPath;
import std.string  : strip;
import std.conv    : to, ConvException;
import std.array   : appender, Appender;
import std.process : environment;

import dbuild.util : SilentException, zstringByLine, formatQuotedIfSpaces, readFile;
import dbuild.core : MultiPathDelimiterChar, BuildContractor;
import dbuild.compilers : formatLanguages, CompilerDefinition, Compiler,
                          CompilerContract, getSupportedCompilersDefinitionsFor;

struct BuildConfig
{
    string filename;
    string fileContents;

    Appender!(BuildContractor[]) contractors;
    bool modifiedFromFile;

    void load(string filename) in { assert(!filename); } body
    {
        this.filename = filename;
        this.fileContents = cast(string)readFile(filename);

        uint lineNumber = 1;
        foreach(line; zstringByLine(fileContents.ptr))
        {
            writefln("line %s: \"%s\"", lineNumber, line);
        }
    }

    // TODO: might want different overloads for this, maybe one
    //       that applies to all contracts
    void compiler(Compiler compiler, CompilerContract contract)
    {
        contractors.put(compiler);
        modifiedFromFile = true;
    }

    Compiler getCompiler(CompilerContract contract)
    {
        auto sourceLanguages = contract.getSourceLanguages();

        // check if there is already a contractor that supports this contract
        /*
        foreach(contractor; contractors)
        {

        }
        */

        // TODO: check if compiler is already configured

        writefln("[DEBUG] Searching for compilers that support %s", formatLanguages(sourceLanguages));

        // Get a list of known compilers that support the given langauges
        auto supportedCompilerDefinitions = getSupportedCompilersDefinitionsFor(contract);
        foreach(supportedCompiler; supportedCompilerDefinitions)
        {
            writefln("[DEBUG] Compiler \"%s\" supports %s", supportedCompiler.name, formatLanguages(sourceLanguages));
        }

        // Here assume the compiler is not configured, attempt to find the compiler
        struct FoundCompiler
        {
            immutable(CompilerDefinition) definition;
            string fullPathExe;
        }
        auto compilers = appender!(FoundCompiler[]);

        foreach(path; pathIterator(environment.get("PATH", null)))
        {
            //writefln("[DEBUG]  searching path \"%s\" for a valid compiler", path);
            foreach(compilerDefinition; supportedCompilerDefinitions)
            {
                auto fullPathExe = buildPath(path, compilerDefinition.exeFilename);
                if(exists(fullPathExe))
                {
                    writefln("[DEBUG]    FOUND          \"%s\"", fullPathExe);
                    compilers.put(FoundCompiler(compilerDefinition, fullPathExe));
                }
                else
                {
                    //writefln("[DEBUG]    does not exist \"%s\"", fullPathExe);
                }
            }
        }

        if(compilers.data.length == 0)
        {
            return null; // no compiler found
        }

        uint compilerToUseIndex;
        if(compilers.data.length == 1)
        {
            compilerToUseIndex = 0;
            writefln("Only found 1 D compiler at %s", compilers.data[compilerToUseIndex].fullPathExe.formatQuotedIfSpaces);
            auto result = queryYesNo("Would you like to use this compiler", true);
            if(!result)
            {
                throw new SilentException();
            }
        }
        else
        {
            writefln("Found %s compiler(s) for %s", compilers.data.length, contract.formatForMessage());
            foreach(i, foundCompiler; compilers.data)
            {
                writefln("[%s] %s", i, foundCompiler.fullPathExe.formatQuotedIfSpaces);
            }
            compilerToUseIndex = queryRange("Enter the compiler you would like to use", 0, compilers.data.length - 1);
        }

        auto chosenCompiler = compilers.data[compilerToUseIndex];
        auto newCompiler = new Compiler(chosenCompiler.definition, chosenCompiler.fullPathExe);
        compiler(newCompiler, contract);
        return newCompiler;
    }
}

bool queryYesNo(string message, bool default_)
{
    for(;;)
    {
        stdout.writef("%s (y/n): ", message);
        stdout.flush();
        auto response = stdin.readln().strip();
        if(response is null)
        {
            writeln();
            writefln("Error: failed to get a response");
            throw new SilentException();
        }
        if(response.length == 0)
        {
            return default_;
        }
        if(response[0] == 'y')
        {
            return true;
        }
        if(response[0] == 'n')
        {
            return false;
        }
    }
}
T queryRange(T)(string message, T min, T max)
{
    for(;;)
    {
        stdout.writef("%s (%s to %s): ", message, min, max);
        stdout.flush();
        auto response = stdin.readln().strip();
        if(response is null)
        {
            writeln();
            writefln("Error: failed to get a response");
            throw new SilentException();
        }
        try
        {
            return to!T(response);
        }
        catch(ConvException)
        {
        }
    }
}



//
// TODO: might move this somewhere more common?
//
static findProgramInPath(string programName)
{

}
auto pathIterator(T)(T[] paths)
{
    return PathIterator!T(paths);
}
struct PathIterator(T)
{
    T* limit;
    T* current;
    size_t currentLength;
    this(T[] paths)
    {
        this.limit = paths.ptr + paths.length;
        this.current = paths.ptr - 1; // subtract 1 so popFront works correctly
        this.currentLength = 0;
        popFront();
    }
    @property bool empty() const
    {
        return current >= limit;
    }
    T[] front() const
    {
        return current[0..currentLength];
    }
    void popFront()
    {
        current += currentLength;
        if(current < limit)
        {
            current++; // skip delimiter
            for(auto next = current;; next++)
            {
                if(next == limit || *next == MultiPathDelimiterChar)
                {
                    currentLength = next - current;
                    break;
                }
            }
        }
    }
}