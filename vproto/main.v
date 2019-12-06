module main

import os

import flag

struct Args {
mut:
	filename string
	additional []string
}

fn parse_args() Args {
	mut args := Args{}

	mut fp := flag.new_flag_parser(os.args)
	fp.application('vproto')
	fp.version('v0.0.0')
	fp.description('V protocol buffers parser')

	fp.skip_executable()

	args.filename = fp.string('filename', '', 'Filename of proto to parse')

	args.additional = fp.finalize() or {
		panic(err)
	}

	return args
}

fn report_error(text string) {
	panic(text)
}

const (
	whitespace = [` `, `\t`, `\n`, `\r`]
	comment = '//'
)

enum ProtoSyntax {
	proto2
	proto3
}

struct Parser {
	filename string // current file

mut:
	text string // file text
	char int // current char index

	line int
	line_char int // The char that the new line was on

	syntax ProtoSyntax // syntax of the file
	
	package string
	imports []Import
	options []FieldOption
	enums []Enum
}

fn (p &Parser) end_of_file() bool {
	return p.char >= p.text.len
}

fn (p &Parser) cur_line() int {
	return p.line
}

fn (p &Parser) cur_char() int {
	return (p.char - p.line_char) - 1
}

fn (p mut Parser) next_line() {
	p.line += 1
	p.line_char = p.char
}

fn (p &Parser) next_char() byte {
	return p.text[p.char]
}

fn (p &Parser) next_chars(count int) string {
	return p.text[p.char .. p.char + count]
}

fn (p mut Parser) consume_char() byte {
	ret := p.next_char()
	p.char += 1

	if ret == `\n` { 
		p.next_line()
	}

	return ret
}

fn (p mut Parser) consume_chars(count int) string {
	mut ret := ""

	for i := 0; i < count; i++ {
		ret += p.consume_char().str()
	}

	return ret
}

fn (p mut Parser) consume_comment() {
	for {
		if p.end_of_file() { break }

		if p.next_char() != `\n` { p.consume_char() }
		else { break }
	}
}

fn (p mut Parser) consume_whitespace() {
	for {
		if p.end_of_file() { break }

		c := p.next_char()

		if c in whitespace { 
			p.consume_char() 
			continue 
		} else if c == `/` && p.next_chars(2)[1] == `/` {
			// Try and consume a comment aswell
			p.consume_comment()
		} else {
			// no more whitespace?
			break
		}
	}
}

fn (p mut Parser) consume_string() ?string {
	// strLit = ( "'" { charValue } "'" ) | ( '"' { charValue } '"' )

	// TODO we need to parse escaped characters properly in here aswell!
	// so far only escaped " is done

	if p.consume_char() != `"` { return none }
	
	mut text := ''
	
	for {
		if !p.end_of_file() && p.next_char() != `"` {
			text += p.consume_char().str()
		} else if p.next_chars(2) == '\\"' {
			p.consume_chars(2)
			text += '"'
		} else {
			break
		}
	}

	if p.end_of_file() || p.consume_char() != `"` { 
		report_error('Expected closing `"` for string') 
		return none
	}

	return text
}

fn (p &Parser) next_ident() string {
	mut i := 1
	for ; ; i++ {
		if p.end_of_file() { break }

		text := p.next_chars(i)

		c := text[text.len-1]

		if !c.is_digit() && !c.is_letter() && c != `_` { break }
	}

	return p.next_chars(i-1)
}

fn (p mut Parser) consume_ident() ?string {
	mut text := ''

	for {
		if p.end_of_file() { break }

		c := p.next_char()

		if c.is_digit() || c.is_letter() || c == `_` {
			text += p.consume_char().str()
		} else {
			break
		}
	}

	if text != '' { return text }
	else { return none }
}

fn (p mut Parser) consume_full_ident() ?string {
	mut text := ''

	for {
		ident := p.consume_ident() or {
			break
		}

		text += ident

		if p.next_char() == `.` {
			text += p.consume_char().str()
		} else { break }
	}

	if text != '' { return text }
	else { return none }
}

fn (p mut Parser) consume_decimals() ?string {
	mut lit := ''

	for {
		if p.end_of_file() { break }

		if p.next_char().is_digit() {
			lit += p.consume_char().str()
		} else {
			break
		}
	}

	if lit != '' { return lit }
	else { return none }
}

fn (p mut Parser) consume_decimal() ?string {
	// decimalLit = ( "1" … "9" ) { decimalDigit }

	if p.next_char() <= `1` || p.next_char() >= `9` {
		// Not a decimal lit
		return none
	}

	mut lit := p.consume_char().str()

	for {
		if p.end_of_file() { break }

		if p.next_char().is_digit() {
			lit += p.consume_char().str()
		} else {
			break
		}
	}

	return lit
}

fn (p mut Parser) consume_octal() ?string {
	if p.next_char() != `0` {
		return none
	}

	p.consume_char()
	mut lit := ''

	for {
		if p.end_of_file() { break }

		if p.next_char() >= `0` && p.next_char() <= `7` {
			lit += p.consume_char().str()
		} else {
			break
		}
	}

	return lit
}

fn (p mut Parser) consume_hex() ?string {
	if p.next_chars(2) != '0x' {
		return none
	}

	p.consume_char()
	mut lit := ''

	for {
		if p.end_of_file() { break }

		if (p.next_char().is_hex_digit())  {
			lit += p.consume_char().str()
		} else {
			break
		}
	}

	return lit
}


fn (p mut Parser) consume_integral() ?string {
	// intLit     = decimalLit | octalLit | hexLit

	// TODO return to this when it is fixed
	// return p.consume_decimal() or { return p.consume_hex() or { return p.consume_octal() or { return none } } }

	if x := p.consume_decimal() { return x }
	if x := p.consume_hex() { return x }
	if x := p.consume_octal() { return x }

	return none
}

// TODO maybe replace with a (string, bool) when it works again
struct NumericConstant {
	value string
	floating bool
}

fn (p mut Parser) consume_numeric_constant() ?NumericConstant {
	mut lit := p.consume_integral() or { 
		// "inf" and "nan" are both valid so check those

		if p.next_chars(3) == 'inf' || p.next_chars(3) == 'nan' {
			// valid floating point
			return NumericConstant{p.consume_chars(3), true}
		}

		// 0 is also valid for floats so we can parse that out later
		if p.next_char() == `0` {
			p.consume_decimals() or { report_error('internal: next char was `0` but there were not decimal digits?') }
		} else if p.next_char() == `.` {
			p.consume_char().str()
		}

		// not decimal or float
		return none
	}

	// floatLit = ( decimals "." [ decimals ] [ exponent ] | decimals exponent | "."decimals [ exponent ] ) | "inf" | "nan"
	// decimals  = decimalDigit { decimalDigit }
	// exponent  = ( "e" | "E" ) [ "+" | "-" ] decimals 

	if p.next_char() != `.` || p.next_char().str().to_lower() != 'e' {
		return NumericConstant{lit, false}
	} 

	// See if the next character is a "." or "e"

	if p.next_char() == `.` {
		// consume the "."
		lit += p.consume_char().str()

		// we expect decimals after a "."
		remainder := p.consume_decimals() or { 
			// unless the next character is an `e`
			if p.next_char().str().to_lower() == 'e' {
				''
			} 
			report_error('Expected decimal digits after `.` in floating point literal')

			'' // to appease the compiler
		}

		lit += remainder
	}

	// Now that we have to check for an exp

	if p.next_char().str().to_lower() == 'e' {
		lit += p.consume_char().str()

		if p.next_char() == `+` || p.next_char() == `-` {
			lit += p.consume_char().str()
		}

		remainder := p.consume_decimals() or { 
			report_error('Expected decimal digits after `e(+|-)` in floating point literal') 

			'' // appease the compiler
			panic('this panic should never happen...') // TODO remove
		}

		lit += remainder
	}

	return NumericConstant{lit, true}
}

fn (p mut Parser) consume_bool_lit() ?string {
	next_ident := p.next_ident()
	
	if next_ident == 'true' || next_ident == 'false' {
		return p.consume_ident()
	}

	return none
}

enum LitType {
	ident
	integral
	float
	str
	boolean
}

struct Literal {
	t LitType
	value string
}

fn (l Literal) str() string {
	return '$l.value'
}

fn (p mut Parser) consume_lit() ?Literal {
	// constant = fullIdent | ( [ "-" | "+" ] intLit ) | ( [ "-" | "+" ] floatLit ) |
    //             strLit | boolLit 

	// Start with trying to consume a bool or a string
	{
		if lit := p.consume_bool_lit() {
			return Literal{LitType.boolean, lit}
		} 
		
		if lit := p.consume_string() {
			return Literal{LitType.str, lit}
		}
	}
	// then try int / float with optional + -
	{
		mut lit_base := ''

		if p.next_char() == `+` || p.next_char() == `-` {
			lit_base += p.consume_char().str()
		}

		if lit := p.consume_numeric_constant() {
			if lit.floating {
				return Literal{LitType.float, lit_base + lit.value}
			} else {
				return Literal{LitType.integral, lit_base + lit.value}
			}
		}
	}
	// finally full ident
	{
		if lit := p.consume_full_ident() {
			return Literal{LitType.ident, lit}
		}
	}

	// There was nothing here we could find
	return none
}

fn (p mut Parser) consume_syntax() {
	p.consume_whitespace()

	// syntax = "syntax" "=" quote "proto2" quote ";"

	// if there is no 'syntax' then this cant be parsed right now
	if p.next_chars(6) != 'syntax' { 
		p.syntax = .proto2
		return 
	}

	p.consume_chars(6)
	p.consume_whitespace()

	if p.consume_char() != `=` { report_error('Expected `=` in syntax statement') }
	
	p.consume_whitespace()

	proto_version := p.consume_string() or {
		report_error('Expected string constant in syntax statement')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { report_error('Expected `;` in syntax statement') }

	if proto_version == 'proto2' {
		p.syntax = .proto2
	} else if proto_version == 'proto3' {
		p.syntax = .proto3
	}
}

struct Import {
	weak bool
	public bool
	package string
}

pub fn (i Import) str() string {
	weak := if i.weak { 'weak' } else { '' }
	public := if i.public { 'public' } else { '' }
	return '$weak $public $i.package'
}

// TODO should these return ?Import and then Parser.parse() adds them?
fn (p mut Parser) consume_import() {
	p.consume_whitespace()

	if p.next_chars(6) != 'import' {
		// Not an import statement
		return
	}

	// import = "import" [ "weak" | "public" ] strLit ";" 

	p.consume_chars(6)
	p.consume_whitespace()
	
	ident := p.next_ident()

	if ident == 'weak' || ident == 'public' {
		// Do something here if this is the case
		p.consume_ident() or { 
			panic('') // should never happen
		}


	} else if ident != '' {
		report_error('Expected `weak` or `public` not `$ident`')
	}

	weak := ident == 'weak'
	public := ident == 'public'

	p.consume_whitespace()
	package := p.consume_string() or {
		report_error('Expected string constant in import statement')
		'' // appease compiler
	}
	p.consume_whitespace()

	if p.consume_char() != `;` { report_error('Expected `;` in import statement') }

	p.imports << Import{weak, public, package}
}

fn (p mut Parser) consume_package() {
	p.consume_whitespace()

	// package = "package" fullIdent ";"

	if p.next_chars(7) != 'package' {
		// Not a package statement
		return
	}

	p.consume_chars(7)

	p.consume_whitespace()
	ident := p.consume_full_ident() or {
		report_error('Expected full ident in package statement')
		''
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { report_error('Expected `;` in package statement') }

	// TODO add package token to stream

	p.package = ident
}

struct OptionField {
	ident string
	value Literal
}

pub fn (o OptionField) str() string {
	return '$o.ident = $o.value'
}

fn (p mut Parser) consume_option() ?OptionField {
	p.consume_whitespace()

	// option = "option" optionName  "=" constant ";"
	// optionName = ( ident | "(" fullIdent ")" ) { "." ident }

	if p.next_chars(6) != 'option' {
		// Not an option statement
		return none
	}

	p.consume_chars(6)
	p.consume_whitespace()

	// TODO consume "optionName" properly
	// at the moment we are only handling the fullIdent part

	ident := p.consume_full_ident() or {
		report_error('Expected identifier in option statement')
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `=` { report_error('Expected `;` in option statement') }
	p.consume_whitespace()

	lit := p.consume_lit() or {
		report_error('Expected literal in option statement')
		panic('') // appease compiler
	}

	if p.consume_char() != `;` { report_error('Expected `;` in package statement') }

	return OptionField{ident, lit}
}

struct FieldOption {
	ident string
	value Literal
}

pub fn (o FieldOption) str() string {
	return '$o.ident = o.value'
}

fn (p mut Parser) consume_field_options() []FieldOption {
	if p.next_char() != `[` { return [] }

	p.consume_char()

	mut options := []FieldOption

	for {
		p.consume_whitespace()

		if p.next_char() == `]` { break }
	
		ident := p.consume_ident() or {
			report_error('Expected identifier in field option')
			'' // appease compiler
		}

		p.consume_whitespace()

		if p.consume_char() != `=` { report_error('Expected `=` in field option') }

		p.consume_whitespace()

		lit := p.consume_lit() or {
			report_error('Expected literal in field option')
			panic('') // appease compiler
		}

		// Unless the next character after whitespace is a `]` expect a comma
		p.consume_whitespace()

		if p.next_char() != `]` || p.next_char() != `,` {
			report_error('Expected `]` or `,` after field option')
		}

		if p.next_char() == `,` { p.consume_char() }

		options << FieldOption{ident, lit}
	}

	return options
}

struct EnumField {
	ident string
	value Literal // int literal

	options []FieldOption
}

pub fn (e EnumField) str() string {
	return '$e.ident $e.value $e.options'
}

fn (p mut Parser) consume_enum_field() ?EnumField {
	// enumField = ident "=" intLit [ "[" enumValueOption { ","  enumValueOption } "]" ]";"
	// enumValueOption = optionName "=" constant

	p.consume_whitespace()

	ident := p.consume_ident() or {
		// There is no field here
		return none
	}

	p.consume_whitespace()
	
	if p.consume_char() != `=` { report_error('Expected `=` in enum field') }

	p.consume_whitespace()

	lit := p.consume_lit() or {
		report_error('Expected literal in enum field')
		panic('') // appease compiler
	}

	if lit.t != .integral {
		report_error('Expected integral literal in enum field (got type $lit.t)')
	}

	p.consume_whitespace()
	
	options := p.consume_field_options()

	p.consume_whitespace()
	if p.consume_char() != `;` { report_error('Expected `;` after enum field') }

	return EnumField{ident, lit, options}

}

struct Enum {
	name string
	options []OptionField
	fields []EnumField
}

pub fn (e Enum) str() string {
	return 'Enum: $e.name
fields: $e.fields
options: $e.options'
}

fn (p mut Parser) consume_enum_body(name string) Enum {
	// enumBody = "{" { option | enumField | emptyStatement } "}"

	mut options := []OptionField
	mut fields := []EnumField

	for {
		if o := p.consume_option() {
			options << o
		}
		
		if f := p.consume_enum_field() {
			fields << f
		}

		p.consume_empty_statement()

		if p.next_char() == `}` {
			break
		}
	}

	return Enum{name, options, fields}
}

fn (p mut Parser) consume_enum() {
	// enum = "enum" enumName enumBody

	if p.next_chars(4) != 'enum' {
		return
	}

	p.consume_chars(4)
	p.consume_whitespace()

	name := p.consume_ident() or {
		report_error('Expected identifier after enum')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `{` { report_error('expected `{` after enum name') }

	e := p.consume_enum_body(name)

	p.consume_whitespace()

	if p.consume_char() != `}` { report_error('expected `}` after enum body') }

	p.enums << e
}

fn (p mut Parser) consume_top_level_def() {
	// topLevelDef = message | enum | extend | service

	p.consume_whitespace()

	// p.consume_message()
	p.consume_enum()
	// p.consume_extend()
	// p.consume_service()
}

fn (p mut Parser) consume_empty_statement() {
	p.consume_whitespace()

	if !p.end_of_file() && p.next_char() == `;` {
		p.consume_char()
	}
}

fn (p mut Parser) parse() {
	text := os.read_file(p.filename) or {
		panic(err)
	}
	p.text = text

	println('$text')

	// proto = syntax { import | package | option | topLevelDef | emptyStatement }

	p.consume_syntax()

	for {
		// TODO find a nicer way of doing this

		p.consume_whitespace()
		if p.end_of_file() { break }

		p.consume_import()
		if p.end_of_file() { break }

		p.consume_package()
		if p.end_of_file() { break }
		
		if option := p.consume_option() {
		}
		if p.end_of_file() { break }

		p.consume_top_level_def()
		if p.end_of_file() { break }

		p.consume_empty_statement()
		if p.end_of_file() { break }
	}
}

pub fn (p Parser) str() string {
	return 'File $p.filename:
> syntax:
$p.syntax\n
> package:
$p.package\n
> imports:
$p.imports\n
> options:
$p.options\n
> enums:
$p.enums'
}

fn main() {
	args := parse_args()

	if args.filename == '' {
		println('No filename passed')
		return
	}

	mut p := Parser{filename: args.filename}

	p.parse()

	println('$p')
}