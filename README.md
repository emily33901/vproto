# vproto

Implementation of protobuf for the V programming language.

## Progress

Right now the all V protobuf parser can parse most of the proto2 spec (enough to parse most of the protobufs in the steam database repository). No attempt has been made to make proto3 work and services are not currently parsed. All the parser does right now is dump a json version of what its parsed to stdout.

No attempt is made to check if any of the definitions are valid or if the options people use exist or similar.