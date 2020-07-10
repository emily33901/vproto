module main

import flag
import os

import v.table
import v.parser
import v.pref
import v.fmt
import v.ast

import compiler

struct Args {
mut:
	filename string
	additional []string
	out_folder string
	imports []string
	quiet bool
	module_override string
	fp &flag.FlagParser
}

fn parse_args() Args {
	mut fp := flag.new_flag_parser(os.args)

	mut args := Args{fp: fp}

	fp.application('vproto')
	fp.version('v0.0.1')
	fp.description('V protocol buffers parser')

	fp.skip_executable()

	args.filename = fp.string('filename', `f`, '', 'Filename of proto to parse')
	args.out_folder = fp.string('out_dir', `o`, '', 'Output folder of V file')
	args.module_override = fp.string('mod', `m`, '', 'V Module override')

	im := fp.string_multi('import', `i`, 'Add a directory to imports')

	args.imports << im

	args.quiet = fp.bool('quiet',`q`, false, 'Supress warnings and messages')

	// TODO revert when vlang #5039 is fixed
	additional := fp.finalize() or { []string{} }

	args.additional = additional

	return args
}

fn format_file(path string) {
	table := table.new_table()
	ast_file := parser.parse_file(path, table, .parse_comments, &pref.Preferences{}, &ast.Scope{
		parent: 0
	})

	result := fmt.fmt(ast_file, table, false)

	os.write_file(path, result)
}

fn main() {
	args := parse_args()

	if args.filename == '' {
		println(args.fp.usage())
		return
	}

	if !os.is_dir(args.out_folder) {
		os.mkdir(args.out_folder)
	}

	mut p := compiler.new_parser(args.quiet, args.imports)

	mut f := p.parse_file(args.filename, args.module_override)
	p.validate()

	if !f.has_package() {
		println('$f.filename does not have a package. You need to pass a -m `new_pkg` to set it manually.')
		exit(1)
	}

	mut g := compiler.new_gen(p)

	filename := os.real_path(f.filename).all_after_last(os.path_separator).all_before_last('.') + '_pb.v'

	path := os.join_path(os.real_path(args.out_folder), filename)

	os.write_file(path, g.gen_file_text(f))
	format_file(path)
}
