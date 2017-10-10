import dbuild;

int main(string[] args)
{
    exe("db")
        .source("db.d")
        .source("dbuild/core.d")
        .source("dbuild/util.d")
        .source("dbuild/run.d")
        ;
    return runBuild(args);
}
