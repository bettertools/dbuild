dbuild
================================================================================
This tool allows you to configure your build in the D Programming language.

### How to use

Create the file "build.d":
```D
import dbuild;

int main(string[] args)
{
    exe("helloWorld")
        .source("helloWorld.d")
        ;
    return runBuild(args);
}
```

Run the "db" program
```
db
```

db supports other commands such as:
```
db clean
```

### Build/Install db using an existing db

If you already have `db` installed, you can use it to build/install another version of db.

> Note: instructions for this to come

### Build/Install db on Windows

If you do not already have `db` installed, you can use the following instructions to build/install it on windows.  Run the following command to build:

```
build.bat
```

This will create the file "db.exe".  The installation requires that db.exe be in your PATH and that the folder "dbuild" lives in the same directory as "db.exe".  If you're making changes to dbuild, you can install db in place by adding a script to forward calls to db.exe inside the repository.  Just create the file "db.bat" somewhere in your PATH with the following contents:
```BATCH
@<path-to-dbuild-repo>\db.exe %*
```
The other option to install is to copy "db.exe" and the "dbuild" folder to a directory in your PATH.

### Build/Install db on Linux/Mac

```
make
```

> TODO: add similar instructions as the windows section on how to install

# Syntax Style Notes
### Original Syntax:
```D
import dbuild;

int main(string[] args)
{
    auto helloWorld = addExe("helloWorld");
    helloWorld.addSource("helloWorld.d");
    helloWorld.addLibrary("someLibrary.lib");
    return runBuild(args);
}
```
### New Syntax:
```D
import dbuild;

int main(string[] args)
{
    exe("helloWorld")
        .source("helloWorld.d")
        .library("someLibrary.lib")
        ;
    return runBuild(args);
}
```
### Why?

* Changed "addXXX" to just "XXX".  Since the most common thing the build file is doing is "adding" to the build, it makes sense to omit the extra characters and make "adding" that the default operation.

* Using `object.operation.operation ...;` intead of `name = object; name.operation; name.operation; ...`.  Note that the original style still works, however the new style is recommended. The new style allows the configuration code to access the build object without having to give it a name.  This simplifies the configuration code and makes it impossible to have copy/paste errors  with build objects.  There may be times when the code needs to refer back to the object later in which case it still makes sense to assign it to a variable.

* Each operation goes on it's own line and the `.` character goes on the same line as the next operation.  This makes each operation fit on one line.  Copying operations between objects becomes easier since you can just copy entire lines instead of piecing together parts of lines.  It also means that adding and removing operations has no affect on the surrounding lines.


