module main

import flag
import os

import vproto

struct Args {
mut:
	filename string
	additional []string
	imports []string
	quiet bool
}

fn parse_args() Args {
	mut args := Args{}

	mut fp := flag.new_flag_parser(os.args)
	fp.application('vproto')
	fp.version('v0.0.1')
	fp.description('V protocol buffers parser')

	fp.skip_executable()

	args.filename = fp.string('filename', '', 'Filename of proto to parse')
	im := fp.string('import', '', 'Add a directory to imports')
	args.imports << im

	args.quiet = fp.bool('quiet', false, 'Supress warnings and messages')

	args.additional = fp.finalize() or {
		panic(err)
	}

	return args
}

fn main() {
	args := parse_args()

	if args.filename == '' {
		println('No filename passed')
		return
	}

	mut p := vproto.Parser{file_inputs: [args.filename], imports: args.imports, quiet: args.quiet}

	p.parse()
	p.validate()

	println('${json.encode(p)}')
}