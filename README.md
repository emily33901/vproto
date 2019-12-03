# very-protobuf

Implementation of protobuf for the V programming language.

Incredibly WIP!! - does not even generate a V file.

This will eventually probably turn into a protoc plugin but since I cannot get that to work right now its just in standalone mode!

Based on the work done by the creators of [protobuf-c](https://github.com/protobuf-c/protobuf-c)

## To build

Make directory `build` in `build-cmake` and `cmake ..` in there.

If you're using vcpkg or visual studio pass the correct parameters now so that it can find libprotobuf and similar packages (e.g. `cmake -G "Visual Studio 15 2017" -A x64 -DCMAKE_TOOLCHAIN_FILE=E:\src\vcpkg\scripts\buildsystems\vcpkg.cmake ..`).