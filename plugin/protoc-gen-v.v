module main

import os

import google.protobuf
import google.protobuf.compiler

import json

fn main() {
	as_bytes := os.get_raw_stdin()

	// Wait for debugger so i can maintain my sanity
	// for !os.debugger_present() {
	// }

	os.break_if_debugger_attached()

	request := compiler.codegeneratorrequest_unpack(as_bytes) or {
		panic('Failed to decode protobufs')
	}

	s := json.encode(request)

	os.write_file('test-output/result.txt', s)
}