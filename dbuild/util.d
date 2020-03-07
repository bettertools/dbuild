module dbuild.util;

import std.stdio   : File, writeln, writefln;
import std.string  : indexOf;
import std.format  : formattedWrite, format;
import std.path    : buildPath;
import std.process : spawnShell, wait;

class SilentException : Exception { this() { super(null); } }

enum boolstatus : bool { fail = false, success = true }
@property bool failed(boolstatus status) { return status == boolstatus.fail; }

void putf(T, U...)(T appender, string fmt, U args)
{
    formattedWrite(&appender.put!(const(char)[]), fmt, args);
}

auto zstringByLine(T)(T* str)
{
    struct Range
    {
        T* next;
        T[] current;
        this(T* str)
        {
            this.next = str;
            popFront();
        }
        @property bool empty() { return current is null; }
        T[] front() { return current; }
        void popFront()
        {
            char c = *next;
            if(c == '\0')
            {
                current = null;
                return;
            }
            auto start = next;
            for(;;)
            {
                if(c == '\n')
                {
                    current = start[0..next - start];
                    next = next + 1;
                    return;
                }
                next++;
                c = *next;
                if(c == '\0')
                {
                    current = start[0..next - start];
                    return;
                }
            }
        }
    }
    return Range(str);
}

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

alias StringSink = scope void delegate(const(char)[]);
struct DelegateFormatter
{
    void delegate(StringSink sink) formatter;

    void toString(StringSink sink) const
    {
        formatter(sink);
    }
}

// returns a formatter that will print the given string.  it will print
// it surrounded with quotes if the string contains any spaces.
@property auto formatQuotedIfSpaces(T...)(T args) if(T.length > 0)
{
    struct Formatter
    {
        T args;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            bool useQuotes = false;
            foreach(arg; args)
            {
                if(arg.indexOf(' ') >= 0)
                {
                    useQuotes = true;
                    break;
                }
            }

            if(useQuotes)
            {
                sink("\"");
            }
            foreach(arg; args)
            {
                sink(arg);
            }
            if(useQuotes)
            {
                sink("\"");
            }
        }
    }
    return Formatter(args);
}

inout(char)[] toExeName(inout(char)[] name)
{
    version(Windows) {
        return cast(inout(char)[])(name ~ ".exe");
    } else {
        return name;
    }
}

struct DirAndFile
{
    private string filename;
    private string dir;
    private string dirAndName;
    this(string filename)
    {
        this.filename = filename;
    }
    @property string getFilename() const { return filename; }
    @property string getDir() const { return dir; }
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

// Reads the file into a string, adds a terminating NULL as well
char[] readFile(const(char)[] filename)
{
    auto file = File(filename, "rb");
    auto fileSize = file.size();
    if(fileSize > size_t.max - 1)
    {
        assert(0, format("file \"%s\" is too large %s > %s", filename, fileSize, size_t.max - 1));
    }
    auto contents = new char[cast(size_t)(fileSize + 1)]; // add 1 for '\0'
    auto readSize = file.rawRead(contents).length;
    assert(fileSize == readSize, format("rawRead only read %s bytes of %s byte file", readSize, fileSize));
    contents[cast(size_t)fileSize] = '\0';
    return contents[0..$-1];
}