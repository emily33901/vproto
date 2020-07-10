# vproto

vproto can parse most (or maybe all...) of the proto2 spec. It compiles the [Steam Protobufs](https://github.com/SteamDatabase/Protobufs) generating valid code and also parses the `protoc` plugin protobufs (which can be found in `plugin/google/protobuf`). It can parse options, extensions, map fields and extends definitions but does not generate relevent code for it.


![](https://i.f1ssi0n.com/CelestineGrilledMountainlion.png)


vproto is used by [vapor](https://github.com/emily33901/vapor) for both generating V code and runtime packing and unpacking of those generated protobufs