import dbuild;

int main(string[] args)
{
    dlang.exe("helloWorld")
        .source("helloWorld.d")
        ;
    return runBuild(args);
}
