import dbuild;

int main(string[] args)
{
    exe("db")
        .source("db.d")
        .source("dbuild/core.d")
        .source("dbuild/util.d")
        .source("dbuild/config.d")
        .source("dbuild/compilers.d")
        .source("dbuild/dlangcontracts.d")
        ;
    return runBuild(args);
}
