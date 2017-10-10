import dbuild;

int main(string[] args)
{
    exe("helloWorld")
        .source("helloWorld.d")
        ;
    return runBuild(args);
}
