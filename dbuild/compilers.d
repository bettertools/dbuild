module dbuild.compilers;

import std.format : formattedWrite;

import dbuild.util;
import dbuild.core : BuildContract, BuildContractor;
import dbuild.dlangcontracts : DmdCompilerDefinition;

class CompilerContract : BuildContract
{
    abstract immutable(Language)[] getSourceLanguages();
}

enum CompileMode { default_, debug_, release }

enum Language
{
    dlang, c, cpp
}
struct LanguageLists
{
    __gshared static immutable dlangOnly = [Language.dlang];
}
auto formatLanguages(const(Language)[] languages)
{
    static struct Formatter
    {
        const(Language)[] languages;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            string nextPrefix = "";
            foreach(language; languages)
            {
                formattedWrite(sink, "%s%s", nextPrefix, language);
                nextPrefix = "/";
            }
        }
    }
    return Formatter(languages);
}
bool isOnly(const(Language)[] languages, Language only)
{
    return languages.length == 1 && languages[0] == only;
}

class CompilerDefinition
{
    string name;
    string exeFilename;
    Language[] supportedLanguages;
    this(string name, immutable(Language)[] supportedLanguages) immutable
    {
        this.name = name;
        this.exeFilename = toExeName(name);
        this.supportedLanguages = supportedLanguages;
    }
    abstract int compile(Compiler instance, CompilerContract genericContract) const;
}

immutable(CompilerDefinition)[] globalCompilerDefinitionList = [
    new immutable DmdCompilerDefinition(),
    //new immutable CompilerDefinition("ldc", LanguageLists.dlangOnly),
    //new immutable CompilerDefinition("gdc", LanguageLists.dlangOnly),
];
immutable(CompilerDefinition)[] getSupportedCompilersDefinitionsFor(CompilerContract contract)
{
    auto sourceLanguages = contract.getSourceLanguages();
    if(sourceLanguages.isOnly(Language.dlang))
    {
        return globalCompilerDefinitionList;
    }
    assert(0, "not implemented");
}


class Compiler : BuildContractor
{
    immutable(CompilerDefinition) definition;
    string fullPathExe;
    this(immutable(CompilerDefinition) definition, string fullPathExe)
    {
        this.definition = definition;
        this.fullPathExe = fullPathExe;
    }
    int compile(CompilerContract contract)
    {
        return definition.compile(this, contract);
    }
}