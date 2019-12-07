module main

import os
import flag
import json


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

const (
	whitespace = [` `, `\t`, `\n`, `\r`]
)

enum ProtoSyntax {
	proto2
	proto3
}

struct Parser {
	filename string // current file

mut:
	path string

	text string [skip] // file text
	char int [skip] // current char index

	line int [skip]
	line_char int [skip] // The char that the new line was on

	syntax ProtoSyntax // syntax of the file
	
	package string
	imports []Import
	options []OptionField
	enums []Enum
	messages []Message
	extends []Extend
	services []Service
}

fn (p &Parser) report_error(text string) {
	panic('$p.filename:${p.line+1}:${p.cur_char()}: $text')
}

fn (p &Parser) end_of_file() bool {
	return p.char >= p.text.len
}

fn (p &Parser) cur_line() int {
	return p.line
}

fn (p &Parser) cur_char() int {
	return (p.char - p.line_char)
}

fn (p mut Parser) next_line() {
	p.line += 1
	p.line_char = p.char
}

fn (p &Parser) next_char() byte {
	return p.text[p.char]
}

fn (p &Parser) next_chars(count int) string {
	if p.char + count > p.text.len {
		return p.text[p.char .. p.text.len]
	}

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

fn (p mut Parser) consume_oneline_comment() {
	for {
		if p.end_of_file() { break }

		if p.next_char() != `\n` { p.consume_char() }
		else { break }
	}
}

fn (p mut Parser) consume_comment() {
	for {
		if p.end_of_file() { p.report_error('End of file whilst consuming comment') }

		if p.next_chars(2) != '*/' { p.consume_char() }
		else {
			p.consume_chars(2) 
			break 
		}
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
			p.consume_oneline_comment()
		} else if c == `/` && p.next_chars(2)[1] == `*` {
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

	if p.next_char() != `"` { return none }
	p.consume_char()
	
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
		p.report_error('Expected closing `"` for string') 
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

		if (1 > 0 && c.is_digit()) || c.is_letter() || c == `_` {
			continue
		}
	
		break
	}

	return p.next_chars(i-1)
}

fn (p &Parser) next_full_ident() string {
	mut i := 1
	for ; ; i++ {
		if p.end_of_file() { break }

		text := p.next_chars(i)

		c := text[text.len-1]

		if (i > 1 && (c.is_digit() || c == `.`)) || c.is_letter() || c == `_` {
			continue
		}

		break
	}

	return p.next_chars(i-1)
}
 
fn (p mut Parser) consume_ident() ?string {
	mut text := ''

	mut first := true

	for {
		if p.end_of_file() { break }

		c := p.next_char()

		if (!first && c.is_digit()) || c.is_letter() || c == `_` {
			text += p.consume_char().str()
			first = false
		} else if first && c.is_digit() {
			p.report_error('Expected letter or `_` for first character in ident not number')
		} else {
			break
		}

	}

	if text != '' { return text }
	else { return none }
}

fn (p mut Parser) consume_known_ident() {
	p.consume_ident() or {
		p.report_error('Expected identifier')
		panic('') // appease compiler
	}
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

	if p.next_char() < `1` || p.next_char() > `9` {
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
	mut lit := '0'

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

	p.consume_chars(2)
	mut lit := '0x'

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

	if x := p.consume_hex() { return x }
	if x := p.consume_octal() { return x }
	if x := p.consume_decimal() { return x }

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
		if p.next_chars(2) == '0.' {
			p.consume_char()
		} else if p.next_char() == `.` {
			p.consume_char().str()
		}

		// not decimal or float
		return none
	}

	// floatLit = ( decimals "." [ decimals ] [ exponent ] | decimals exponent | "."decimals [ exponent ] ) | "inf" | "nan"
	// decimals  = decimalDigit { decimalDigit }
	// exponent  = ( "e" | "E" ) [ "+" | "-" ] decimals 

	if (p.next_char() != `.` && p.next_char().str().to_lower() != 'e') {
		return NumericConstant{lit, false}
	}

	if lit.len >= 2 {
		// Check that its not a hex or octal number
		if lit[0] == `0` && lit[1] != `.` {
			p.report_error('Hex and octal numbers must be integers')
		}
	}

	// See if the next character is a "." or "e"

	if p.next_char() == `.` {
		// consume the "."
		lit += p.consume_char().str()

		// we expect decimals after a "."
		remainder := p.consume_decimals() or { 
			// unless the next character is an `e`
			if p.next_char().str().to_lower() != 'e' {
				p.report_error('Expected decimal digits or exponent after `.` in floating point literal')
			}

			''
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
			p.report_error('Expected decimal digits after `e(+|-)` in floating point literal') 

			'' // appease the compiler
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
	if p.next_full_ident() != 'syntax' { 
		p.syntax = .proto2
		return 
	}

	p.consume_chars(6)
	p.consume_whitespace()

	if p.consume_char() != `=` { p.report_error('Expected `=` in syntax statement') }
	
	p.consume_whitespace()

	proto_version := p.consume_string() or {
		p.report_error('Expected string constant in syntax statement')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { p.report_error('Expected `;` in syntax statement') }

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
		p.report_error('Expected `weak` or `public` not `$ident`')
	}

	weak := ident == 'weak'
	public := ident == 'public'

	p.consume_whitespace()
	package := p.consume_string() or {
		p.report_error('Expected string constant in import statement')
		'' // appease compiler
	}
	p.consume_whitespace()

	if p.consume_char() != `;` { p.report_error('Expected `;` in import statement') }

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
		p.report_error('Expected full ident in package statement')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { p.report_error('Expected `;` in package statement') }

	p.package = ident
}

// TODO make the distinction between OptionField and FieldOption more distinct
// or roll them up into one thing!

struct OptionField {
	ident string
	value Literal
}

fn (p mut Parser) consume_option() ?OptionField {
	p.consume_whitespace()

	// option = "option" optionName  "=" constant ";"
	// optionName = ( ident | "(" fullIdent ")" ) { "." ident }

	if p.next_full_ident() != 'option' {
		// Not an option statement
		return none
	}

	p.consume_chars(6)
	p.consume_whitespace()

	// TODO consume "optionName" properly
	// at the moment we are only handling the fullIdent part

	ident := p.consume_option_ident() or {
		p.report_error('Expected identifier in option statement')
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `=` { p.report_error('Expected `=` in option statement') }
	p.consume_whitespace()

	lit := p.consume_lit() or {
		p.report_error('Expected literal in option statement')
		panic('') // appease compiler
	}

	if p.consume_char() != `;` { p.report_error('Expected `;` in option statement') }

	return OptionField{ident, lit}
}

struct FieldOption {
	ident string
	value Literal
}

fn (p mut Parser) consume_option_ident() ?string {
	mut ident := ''
	
	if p.next_char() == `(` {
		ident += p.consume_char().str()

		p.consume_whitespace()

		base := p.consume_full_ident() or {
			p.report_error('Expected full identifier in option identifier after `(`')
			'' // appease compiler
		}

		p.consume_whitespace()

		if p.consume_char() != `)` { p.report_error('Expected `)` after full identifier in option') }

		ident += base + ')'
	} else {
		base := p.consume_ident() or {
			// just not here so dont do anything
			return none
		}
		ident += base
	}

	if p.next_char() == `.` {
		ident += p.consume_char().str()

		other := p.consume_full_ident() or { 
			p.report_error('Expected full ident after `.` in option identifier') 
			'' // appease compiler
		}
		ident += other
	}

	return ident
}

fn (p mut Parser) consume_field_options() []FieldOption {
	if p.next_char() != `[` { return [] }

	p.consume_char()

	mut options := []FieldOption

	for {
		p.consume_whitespace()

		if p.next_char() == `]` { break }
	
		ident := p.consume_option_ident() or {
			p.report_error('Expected identifier in field option')
			'' // appease compiler
		}

		p.consume_whitespace()

		if p.consume_char() != `=` { p.report_error('Expected `=` in field option') }

		p.consume_whitespace()

		lit := p.consume_lit() or {
			p.report_error('Expected literal in field option')
			panic('') // appease compiler
		}

		// Unless the next character after whitespace is a `]` expect a comma
		p.consume_whitespace()

		if p.next_char() != `]` && p.next_char() != `,` {
			p.report_error('Expected `]` or `,` after field option (got ${p.next_char().str()})')
		}

		if p.next_char() == `,` { p.consume_char() }

		options << FieldOption{ident, lit}
	}

	p.consume_char()

	return options
}

struct EnumField {
	ident string
	value Literal // int literal

	options []FieldOption
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
	
	if p.consume_char() != `=` { p.report_error('Expected `=` in enum field') }

	p.consume_whitespace()

	// TODO: consume_integral
	lit := p.consume_lit() or {
		p.report_error('Expected literal in enum field')
		panic('') // appease compiler
	}

	if lit.t != .integral {
		p.report_error('Expected integral literal in enum field (got type $lit.t)')
	}

	p.consume_whitespace()
	
	options := p.consume_field_options()

	p.consume_whitespace()
	c := p.consume_char()
	if c != `;` { p.report_error('Expected `;` after enum field (got ${c.str()})') }

	return EnumField{ident, lit, options}
}

struct Enum {
	name string
	options []OptionField
	fields []EnumField
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

fn (p mut Parser) consume_enum() ?Enum {
	// enum = "enum" enumName enumBody

	if p.next_full_ident() != 'enum' {
		return none
	}

	p.consume_chars(4)
	p.consume_whitespace()

	name := p.consume_ident() or {
		p.report_error('Expected identifier after enum')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `{` { p.report_error('expected `{` after enum name') }

	e := p.consume_enum_body(name)

	p.consume_whitespace()

	if p.consume_char() != `}` { p.report_error('expected `}` after enum body') }

	return e
}


const (
	validTypes = ["double", "float",
					"int32", "int64",
					"uint32", "uint64",
					"sint32", "sint64",
					"fixed32", "fixed64",
					"sfixed32", "sfixed64",
					"bool", "string", "bytes"]
)

fn (p mut Parser) consume_field_type(limit_types bool) ?string {
	ident := p.next_full_ident()

	if ident in validTypes {
		p.consume_ident() or {
			panic('') // should never happen
		}
		return ident
	} else if !limit_types {
		if ident != '' {
			return p.consume_full_ident()
		} else if p.next_char() == `.` {
			p.consume_char()

			return p.consume_full_ident()
		}
	}

	println('ident is $ident')

	return none
}

struct Field {
	label string
	ident string
	t string
	number string // int literal

	options []FieldOption
}

fn (p mut Parser) consume_field(is_oneof_field bool) ?Field {
	// field = label type fieldName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
	// fieldOptions = fieldOption { ","  fieldOption }
	// fieldOption = optionName "=" constant

	p.consume_whitespace()

	mut label := p.next_full_ident()

	if label != 'required' && label != 'optional' && label != 'repeated' && !is_oneof_field {
		// Not a "normal field"
		return none
	}

	// oneof fields do not have labels
	if !is_oneof_field {
		p.consume_known_ident()
	} else {
		label = ''
	}

	p.consume_whitespace()

	if p.next_full_ident() == 'group' {
		p.report_error('Groups are deprecated and not supported with this parser...')
	}

	t := p.consume_field_type(false) or {
		p.report_error('Expected valid type in field (got ${p.next_chars(6)}...)')

		panic('') // appease compiler
	}

	p.consume_whitespace()

	ident := p.consume_ident() or {
		p.report_error('Expected valid identifier in field')

		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `=` { p.report_error('Expected `=` in field') }

	p.consume_whitespace()

	lit := p.consume_integral() or {
		p.report_error('Expected integer literal in field')
		panic('') // appease compiler
	}

	p.consume_whitespace()
	
	options := p.consume_field_options()

	p.consume_whitespace()
	c := p.consume_char()
	if c != `;` { p.report_error('Expected `;` after field (got ${c.str()})') }

	return Field{label, ident, t, lit, options}
}

struct Extend {
	t string

	fields []Field
}

fn (p mut Parser) consume_extend() ?Extend {
	if p.next_full_ident() != 'extend' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()

	t := p.consume_field_type(false) or {
		p.report_error('Expected valid message type after extend')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `{` { p.report_error('Expected `{` after extend identifer') }

	mut fields := []Field

	for {
		p.consume_whitespace()

		if f := p.consume_field(false) {
			fields << f
		}

		p.consume_empty_statement()

		if p.end_of_file() { p.report_error('Reached end of body in extend field') }

		if p.next_char() == `}` {
			break
		}
	}

	if p.consume_char() != `}` { p.report_error('Expected `}` after extend identifer') }

	return Extend{t, fields}

}

fn (p mut Parser) consume_ranges() ?[]string {
	mut ranges := []string

	for {
		if p.end_of_file() { p.report_error('End of file reached in extensions statement') }

		p.consume_whitespace()

		mut first := p.consume_integral() or {
			p.report_error('Expected integral in extensions statement')
			'' // appease compiler
		}

		p.consume_whitespace()
		if p.next_full_ident() == 'to' {
			// we have a second aswell
			p.consume_known_ident()
			first += ' to '

			p.consume_whitespace()

			if p.next_full_ident() == 'max' {
				p.consume_known_ident()
				first += 'max'
			} else {
				i := p.consume_integral() or {
					p.report_error('expected `max` or integral in extensions statement')
					'' // appease compiler
				}
				first += i
			}
		}

		ranges << first

		p.consume_whitespace()
		if p.next_char() == `;` { break }
		else if p.consume_char() != `,` { p.report_error('Expected `,` or `;` in extensions statement') }
	}

	p.consume_char()

	return ranges
}

struct Extension {
	ranges []string
}

fn (p mut Parser) consume_extension() ?Extension {
	if p.next_full_ident() != 'extensions' {
		return none
	}

	p.consume_known_ident()

	ranges := p.consume_ranges() or {
		p.report_error('Expected ranges in extensions statement')
		panic('') // appease compiler
	}

	return Extension{ranges}
}

struct Oneof {
	name string

	fields []Field
}

fn (p mut Parser) consume_oneof() ?Oneof {
	if p.next_full_ident() != 'oneof' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()

	ident := p.consume_ident() or {
		p.report_error('expected identifier after oneof')
		'' // appease compile
	}

	p.consume_whitespace()
	if p.consume_char() != `{` { p.report_error('expected `{` after identifier') }

	mut fields := []Field

	for {
		p.consume_whitespace()

		if p.next_char() == `}` { break }

		if x := p.consume_field(true) {
			fields << x
		}
	}

	p.consume_whitespace()

	c := p.consume_char()

	if c != `}` { p.report_error('expected `}` after oneof body (got `${c.str()}`)') }

	return Oneof{ident, fields}
}

struct MapField {
	name string
	
	key_type string
	value_type string

	number string // int literal
}

fn (p mut Parser) consume_map_field() ?MapField {
	if p.next_full_ident() != 'map' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()
	if p.consume_char() != `<` { p.report_error('Expected `<` in map field') }
	p.consume_whitespace()
	
	key_type := p.consume_field_type(true) or {
		p.report_error('Expected key type in map field') 
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `,` { p.report_error('Expected `,` in map field') }
	p.consume_whitespace()

	value_type := p.consume_field_type(false) or {
		p.report_error('Expected value type in map field') 
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `>` { p.report_error('Expected `>` in map field') }
	p.consume_whitespace()

	ident := p.consume_ident() or {
		p.report_error('Expected ident in map field')
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `=` { p.report_error('Expected `=` in map field') }
	p.consume_whitespace()

	number := p.consume_integral() or {
		p.report_error('Expected integral in map field')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { p.report_error('Expected `;` in map field') }

	return MapField{ident, key_type, value_type, number}
}

struct Reserved {
	is_ranges bool
	fields []string
}

fn (p mut Parser) consume_reserved() ?Reserved {
	// reserved = "reserved" ( ranges | fieldNames ) ";"
	// fieldNames = fieldName { "," fieldName }

	if p.next_full_ident() != 'reserved' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()

	mut reserved := []string
	mut is_ranges := true


	if p.next_char() == `"` {
		is_ranges = false
		// This is reserved on field names not ranges
		for {
			if p.end_of_file() { p.report_error('reached end of file in reserved field') }

			p.consume_whitespace()

			str := p.consume_string() or {
				p.report_error('Expected string literal in reserved field')
				'' // appease compiler
			}

			reserved << str

			p.consume_whitespace()
			if p.next_char() == `;` { break }
			else if p.consume_char() != `,` { p.report_error('Expected `,` or `;` in reserved field') }
		}

		p.consume_char()
	} else {
		reserved = p.consume_ranges() or {
			p.report_error('Expected ranges in reserved field')
			panic('') // appease compiler
		}
	}

	return Reserved{is_ranges, reserved}
}

struct Message {
	name string

	fields []Field
	enums []Enum
	messages []Message [skip]
	extends []Extend
	extensions []Extension
	options []OptionField
	oneofs []Oneof
	map_fields []MapField
	reserveds []Reserved
}

fn (p mut Parser) consume_message_body(name string) Message {
	// messageBody = "{" { field | enum | message | extend | extensions | group |
	// option | oneof | mapField | reserved | emptyStatement } "}"

	mut fields := []Field
	mut enums := []Enum
	mut messages := []Message
	mut extends := []Extend
	mut extensions := []Extension
	mut options := []OptionField
	mut oneofs := []Oneof
	mut map_fields := []MapField
	mut reserveds := []Reserved

	for {
		if f := p.consume_field(false) {
			fields << f
		}
		if e := p.consume_enum() {
			enums << e
		}
		if m := p.consume_message() {
			messages << m
		}
		if ex := p.consume_extend() {
			extends << ex
		}
		if ext := p.consume_extension() {
			extensions << ext
		}
		if o := p.consume_option() {
			options << o
		}
		if one := p.consume_oneof() {
			oneofs << one
		}
		if mf := p.consume_map_field() {
			map_fields << mf
		}
		if r := p.consume_reserved() {
			reserveds << r
		}

		p.consume_empty_statement()

		if p.next_char() == `}` {
			break
		}
	}

	return Message{name, fields, enums, messages, extends, extensions, options, oneofs, map_fields, reserveds}

}

fn (p mut Parser) consume_message() ?Message {
	// message = "message" messageName messageBody

	if p.next_full_ident() != 'message' {
		// not a message
		return none
	}

	p.consume_chars(7)
	p.consume_whitespace()

	name := p.consume_ident() or {
		p.report_error('Expected identifier after message')
		'' // appease compiler
	}

	p.consume_whitespace()
	
	if p.consume_char() != `{` { p.report_error('expected `{` after message name') }

	message := p.consume_message_body(name)

	p.consume_whitespace()

	if p.consume_char() != `}` { p.report_error('expected `}` after message body') }

	return message
}

struct ServiceMethod {
	name string
	arg_type string

	return_type string
}


struct Service {
	name string

	method []ServiceMethod

	options []OptionField
}

fn (p mut Parser) consume_service() ?Service {
	if p.next_full_ident() != 'service' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()

	name := p.consume_ident() or { 
		p.report_error('Expected name in service statement ') 
		'' // appease compiler
	}

	p.consume_whitespace()
	if p.consume_char() != `{` { p.report_error('Expected `{` after service name') }
	p.consume_whitespace()

	// TODO actually consume the body properly

	for {
		if p.end_of_file() { p.report_error('Reached end of file while parsing service definition') }
		if p.next_char() == `}` { break }

		p.consume_char()
	}

	p.consume_char()

	return Service{name: name}
}

fn (p mut Parser) consume_top_level_def() {
	// topLevelDef = message | enum | extend | service

	p.consume_whitespace()
	
	if m := p.consume_message() {
		p.messages << m
	}
	if e := p.consume_enum() {
		p.enums << e
	}
	if ex := p.consume_extend() {
		p.extends << ex
	}
	if s := p.consume_service() {
		p.services << s
	}
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

	// proto = syntax { import | package | option | topLevelDef | emptyStatement }

	p.consume_syntax()

	for {
		p.consume_whitespace()
		p.consume_import()
		p.consume_package()
		
		if o := p.consume_option() {
			p.options << o
		}

		p.consume_top_level_def()

		p.consume_empty_statement()
		if p.end_of_file() { break }
	}
}

fn main() {
	args := parse_args()

	if args.filename == '' {
		println('No filename passed')
		return
	}

	mut p := Parser{filename: args.filename}

	p.parse()

	println('${json.encode(p)}')
}