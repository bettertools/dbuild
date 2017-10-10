module dbuild.util;

import std.string : indexOf;
import std.format : formattedWrite;

enum boolstatus : bool { fail = false, success = true }
@property bool failed(boolstatus status) { return status == boolstatus.fail; }

void putf(T, U...)(T appender, string fmt, U args)
{
    formattedWrite(&appender.put!(const(char)[]), fmt, args);
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
