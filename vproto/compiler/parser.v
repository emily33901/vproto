module compiler

import os
import json
import filepath

pub struct Parser {
mut:
	file_inputs []string
	imports []string // paths imported on the cmd line
	quiet bool // whether to supress messages

	text string [skip] // file text
	char int [skip] // current char index

	line int [skip]
	line_char int [skip] // The char that the new line was on


	type_table &TypeTable

	type_context []string

	// TODO dont make public
pub mut:
	files []&File

}

const (
	whitespace = [` `, `\t`, `\n`, `\r`]
)

fn (p & Parser) current_file() &File {
	return &p.files[p.files.len-1]
}

fn (p &Parser) report_error(text string) {
	panic('\n${p.current_file().filename}:${p.line+1}:${p.cur_char()}: $text\n')
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
	p.line++
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
	p.char++

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

	if p.next_char() == `.` {
		text += p.consume_char().str()
	}

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
		p.current_file().syntax = .proto2
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
		p.current_file().syntax = .proto2
	} else if proto_version == 'proto3' {
		p.current_file().syntax = .proto3
	}
}

// TODO should these return ?Import and then Parser.parse() adds them?
fn (p mut Parser) consume_import() bool {
	p.consume_whitespace()

	if p.next_chars(6) != 'import' {
		// Not an import statement
		return false
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

	p.current_file().imports << &Import{weak, public, package}

	return true
}

fn (p mut Parser) consume_package() bool  {
	p.consume_whitespace()

	// package = "package" fullIdent ";"

	if p.next_chars(7) != 'package' {
		// Not a package statement
		return false
	}

	if p.current_file().package != '' {
		p.report_error('Too many package statements in file')
	}

	p.consume_chars(7)

	p.consume_whitespace()
	ident := p.consume_full_ident() or {
		p.report_error('Expected full ident in package statement')
		'' // appease compiler
	}

	p.consume_whitespace()

	if p.consume_char() != `;` { p.report_error('Expected `;` in package statement') }

	p.current_file().package = ident

	return true
}

fn (p mut Parser) consume_option() ?&OptionField {
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

	return &OptionField{ident, lit}
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

fn (p mut Parser) consume_field_options() []&FieldOption {
	if p.next_char() != `[` { return [] }

	p.consume_char()

	mut options := []&FieldOption

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

		options << &FieldOption{ident, lit}
	}

	p.consume_char()

	return options
}



fn (p mut Parser) consume_enum_field() ?&EnumField {
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

	return &EnumField{ident, lit, options}
}


fn (p mut Parser) consume_enum_body(name string, typ &Type) &Enum {
	// enumBody = "{" { option | enumField | emptyStatement } "}"

	mut options := []&OptionField
	mut fields := []&EnumField

	for {
		mut consumed_something := false
		
		if o := p.consume_option() {
			consumed_something = true
			options << o
		}
		
		if f := p.consume_enum_field() {
			consumed_something = true
			fields << f
		}

		if p.consume_empty_statement() {
			consumed_something = true
		}

		if p.next_char() == `}` {
			break
		}

		if !consumed_something {
			ident := p.next_full_ident()
			p.report_error('Bad syntax: `$ident` not expected here')
		}
	}

	return &Enum{name, options, fields, typ}
}

fn (p mut Parser) consume_enum() ?&Enum {
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

	typ := new_type(p.type_scope(), name, true, false, p.current_file())
	e := p.consume_enum_body(name, typ)
	p.type_table.add_enum(typ, e)

	p.consume_whitespace()

	if p.consume_char() != `}` { p.report_error('expected `}` after enum body') }

	return e
}

fn (p mut Parser) consume_field_type(limit_types bool) ?string {
	ident := p.next_full_ident()

	if ident in valid_types {
		p.consume_ident() or {
			panic('') // should never happen
		}
		return ident
	} else if !limit_types {
		if ident != '' {
			return p.consume_full_ident()
		} else if p.next_char() == `.` {
			p.consume_char()

			actual_ident := p.consume_full_ident() or {
				return none
			}

			return '.' + actual_ident
		}
	}

	println('ident is $ident')

	return none
}

fn (p mut Parser) consume_field(is_oneof_field bool) ?&Field {
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

	return &Field{label, 
		ident, 
		t, 
		p.type_scope(), 
		lit, 
		options}
}


fn (p mut Parser) consume_extend() ?&Extend {
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

	mut fields := []&Field

	for {
		p.consume_whitespace()
		// TODO what should type_context be here?
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

	return &Extend{t, fields}

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



fn (p mut Parser) consume_extension() ?&Extension {
	if p.next_full_ident() != 'extensions' {
		return none
	}

	p.consume_known_ident()

	ranges := p.consume_ranges() or {
		p.report_error('Expected ranges in extensions statement')
		panic('') // appease compiler
	}

	return &Extension{ranges}
}



fn (p mut Parser) consume_oneof() ?&Oneof {
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

	mut fields := []&Field

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

	return &Oneof{ident, fields}
}



fn (p mut Parser) consume_map_field() ?&MapField {
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

	return &MapField{ident, key_type, value_type, number}
}

fn (p mut Parser) consume_reserved() ?&Reserved {
	// reserved = "reserved" ( ranges | fieldNames ) ";"
	// fieldNames = fieldName { "," fieldName }

	if p.next_full_ident() != 'reserved' {
		return none
	}

	p.consume_known_ident()

	p.consume_whitespace()

	if p.next_char() == `"` {
		// This is reserved on field names not ranges
		mut reserved := []string
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

		return &Reserved{false, reserved}
	} else {
		ranges := p.consume_ranges() or {
			p.report_error('Expected ranges in reserved field')
			panic('') // appease compiler
		}

		return &Reserved{true, ranges}
	}
}

fn (p mut Parser) consume_message_body(name string, typ &Type) &Message {
	// messageBody = "{" { field | enum | message | extend | extensions | group |
	// option | oneof | mapField | reserved | emptyStatement } "}"

	mut fields := []&Field
	mut enums := []&Enum
	mut messages := []&Message
	mut extends := []&Extend
	mut extensions := []&Extension
	mut options := []&OptionField
	mut oneofs := []&Oneof
	mut map_fields := []&MapField
	mut reserveds := []&Reserved

	for {
		mut consumed_something := false

		if f := p.consume_field(false) {
			consumed_something = true
			fields << f
		}
		if e := p.consume_enum() {
			consumed_something = true
			enums << e
		}
		if m := p.consume_message() {
			consumed_something = true
			messages << m
		}
		if ex := p.consume_extend() {
			consumed_something = true
			extends << ex
		}
		if ext := p.consume_extension() {
			consumed_something = true
			extensions << ext
		}
		if o := p.consume_option() {
			consumed_something = true
			options << o
		}
		if one := p.consume_oneof() {
			consumed_something = true
			oneofs << one
		}
		if mf := p.consume_map_field() {
			consumed_something = true
			map_fields << mf
		}
		if r := p.consume_reserved() {
			consumed_something = true
			reserveds << r
		}

		if p.consume_empty_statement() {
			consumed_something = true
		}

		if p.next_char() == `}` {
			break
		}

		if !consumed_something {
			ident := p.next_full_ident()
			p.report_error('Bad syntax: `$ident` not expected here')
		}
	}

	return &Message{name, fields, enums, messages, extends, extensions, options, oneofs, map_fields, reserveds, typ}

}

fn (p mut Parser) consume_message() ?&Message {
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

	typ := new_type(p.type_scope(), name, false, true, p.current_file())

	p.enter_new_type_scope(name)
	message := p.consume_message_body(name, typ)
	p.exit_type_scope()

	p.type_table.add_message(typ, message)

	p.consume_whitespace()

	if p.consume_char() != `}` { p.report_error('expected `}` after message body') }

	return message
}

fn (p mut Parser) consume_service() ?&Service {
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

	return &Service{name: name}
}

fn (p mut Parser) consume_top_level_def() bool {
	// topLevelDef = message | enum | extend | service

	p.consume_whitespace()

	mut consumed := false
	
	if m := p.consume_message() {
		p.current_file().messages << m
		consumed = true
	}
	if e := p.consume_enum() {
		p.current_file().enums << e
		consumed = true
	}
	if ex := p.consume_extend() {
		p.current_file().extends << ex
		consumed = true
	}
	if s := p.consume_service() {
		p.current_file().services << s
		consumed = true
	}

	return consumed
}

fn (p mut Parser) consume_empty_statement() bool {
	p.consume_whitespace()

	if !p.end_of_file() && p.next_char() == `;` {
		p.consume_char()

		return true
	}

	return false
}

pub fn (p mut Parser) parse() {
	p.type_table = &TypeTable{}

	for i := 0; ; i++ {
		if i >= p.file_inputs.len { break }

		filename := p.file_inputs[i]

		text := os.read_file(filename) or {
			panic(err)
		}

		// reset the parser
		p.text = text
		p.line = 0
		p.line_char = 0
		p.char = 0
		p.files << &File{filename: filename, path: filename}
		p.type_context = []

		// proto = syntax { import | package | option | topLevelDef | emptyStatement }

		p.consume_syntax()

		if p.current_file().syntax == .proto3 {
			p.report_error('Unable to parse proto3 files right now...')
		}

		for {
			mut consumed_something := false

			p.consume_whitespace()

			if p.consume_import() { consumed_something = true }
			if p.consume_package() { consumed_something = true }
			
			if o := p.consume_option() {
				consumed_something = true
				p.current_file().options << o
			}

			if p.consume_top_level_def() { consumed_something = true }
			if p.consume_empty_statement() { consumed_something = true }

			if !consumed_something {
				ident := p.next_full_ident()
				p.report_error('Bad syntax: `$ident` not expected here')
			}

			if p.end_of_file() { break }
		}

		// parsed this file
		// see if we have any imports that need resolving

		for _, im in p.current_file().imports {
			// TODO if the proto isnt in this folder than we need to check
			// other include folders for it
			mut new_path := os.realpath(filepath.join(os.realpath(p.current_file().path).all_before_last(os.path_separator), im.package))


			if !p.quiet { println('importing $im.package ...') }

			mut found := false

			if !os.exists(new_path) {
				found = false

				// Check in the import paths
				for _, im_path in p.imports {
					path := os.realpath(filepath.join(os.realpath(im_path), im.package))

					if !p.quiet { println('> Trying $path') }
					
					if os.exists(path) {
						new_path = path
						found = true
						break
					}
				}

			} else {
				found = true
			}

			if !found {
				p.report_error('Unable to find $new_path')
			}

			if new_path in p.file_inputs {
			} else {
				p.file_inputs << new_path
			}
		}
	}
}

fn (p mut Parser) enter_new_type_scope(name string) {
	p.type_context << name
}

fn (p mut Parser) exit_type_scope() {
	p.type_context = p.type_context[..p.type_context.len-1]
}

fn (p &Parser) type_scope() []string {
	mut ctx := [p.current_file().package]
	ctx << p.type_context
	return ctx
}

// TODO refactor validation from the parser to another struct

fn (p &Parser) report_invalid(text string) {
	println('\nerror: $text')
}

fn (p &Parser) check_message_field_numbers(type_context []string, message &Message) {
	mut ranges := RangeChecker{}

	for _, field in message.fields {
		number := field.number.i64()
		owners := ranges.is_range_taken(number, number)
		
		if owners.len > 0 {
			p.report_invalid('Overlap of field number `$field.number` in `$message.name`\n`$field.name` attempted to use it but it was taken by `${owners}`')
		}

		ranges.add_new_range(number, number, field.name)
	}

	for _, oneof in message.oneofs {
		for _, field in oneof.fields {
			number := field.number.i64()
			owners := ranges.is_range_taken(number, number)
			
			if owners.len > 0 {
				p.report_invalid('Overlap of field number `$field.number` in `$message.name`\n`$field.name` attempted to use it but it was taken by `${owners}`')
			}

			ranges.add_new_range(number, number, field.name)
		}
	}

	for _, field in message.map_fields {
		number := field.number.i64()
		owners := ranges.is_range_taken(number, number)
		
		if owners.len > 0 {
			p.report_invalid('Overlap of field number `$field.number` in `$message.name`\n`$field.name` attempted to use it but it was taken by `${owners}`')
		}

		ranges.add_new_range(number, number, field.name)
	}

	for _, res in message.reserveds {
		if !res.is_ranges {
			continue
		}

		for _, range in res.fields {
			lower, upper := range_from_string(range)

			owners := ranges.is_range_taken(lower, upper)

			if owners.len > 0 {
				p.report_invalid('Overlap of field number `$lower to $upper` in `$message.name`\n`reserveds` attempted to use it but it was taken by `${owners}`')
			}

			ranges.add_new_range(lower, upper, 'reserveds')
		}
	}

	// TODO cut n paste
	for _, extension in message.extensions {
		for _, range in extension.ranges {
			lower, upper := range_from_string(range)

			owners := ranges.is_range_taken(lower, upper)

			if owners.len > 0 {
				p.report_invalid('Overlap of field number `$lower to $upper` in `$message.name`\n`extensions` attempted to use it but it was taken by `${owners}`')
			}

			ranges.add_new_range(lower, upper, 'reserveds')
		}
	}

	mut message_type_context := [message.name]
	message_type_context << type_context.clone()

	for _, extend in message.extends {
		p.check_extends(message_type_context, extend)
	}
}

fn (p &Parser) check_message_field_types(type_context []string, message &Message) {
	mut message_type_context := type_context.clone()
	message_type_context << message.name
	
	for _, field in message.fields {
		if field.t in valid_types { continue }
		
		if x := p.type_table.lookup_type(message_type_context, field.t) {
			continue
		}

		p.report_invalid('Unable to find type `$field.t` for `$field.name` in `$message.name`')
	}

}

fn (p &Parser) check_field_numbers() {
	for _, file in p.files {
		for _, message in file.messages {
			p.check_message_field_numbers([file.package], message)
		}
	}
}

fn (p &Parser) check_field_types() {
	for _, file in p.files {
		for _, message in file.messages {
			p.check_message_field_types([file.package], message)
		}
	}
}

fn (p &Parser) check_message_field_names(type_context []string, message &Message) {
	mut used_names := map[string]bool
	
	for _, field in message.fields {
		if field.name in used_names {
			p.report_invalid('Field name `$field.name` is already used in `$message.name`')
		}
		used_names[field.name] = true
	}
}

fn (p &Parser) check_enum_field_names(type_context []string, e &Enum) {
	mut used_names := map[string]bool
	
	for _, field in e.fields {
		if field.name in used_names {
			p.report_invalid('Field name `$field.name` is already used in `$e.name`')
		}
		used_names[field.name] = true
	}
}

fn (p &Parser) check_field_names() {
	for _, file in p.files {
		for _, message in file.messages {
			p.check_message_field_names([file.package], message)
		}

		for _, e in file.enums {
			p.check_enum_field_names([file.package], e)
		}
	}
}

fn (p &Parser) check_extends(type_context []string, extend &Extend) {
	// Check that the type exists

	lookup_result := p.type_table.lookup_message(type_context, extend.t) or {
		p.report_invalid('Unable to find type `$extend.t` for extend block')
		return
	}

	message := lookup_result

	mut extension_ranges := RangeChecker{}

	for _, ext in message.extensions {
		for _, range in ext.ranges {
			lower, upper := range_from_string(range)

			extension_ranges.add_new_range(lower, upper, 'extensions')
		}
	}

	for _, field in extend.fields {
		number := field.number.i64()
		owners := extension_ranges.is_range_taken(number, number)

		if owners.len == 0 {
			// not a valid extension number
			// TODO print valid ranges that could be used?
			p.report_invalid('Field number `$number` is not in a valid extension range for `$message.name`')
		}
	}
}

fn (p &Parser) check_file_extends() {
	for _, file in p.files {
		for _, extend in file.extends {
			p.check_extends([file.package], extend)
		}
	}
}


struct Options {
	message_options []OptionField
	enum_options []OptionField
	file_options []OptionField

	message_field_options []FieldOption
	enum_field_option []FieldOption

	// TODO service and method options
}

const (
	file_options_message = 'FileOptions'

	message_options_message = 'MessageOptions'

	field_options_message = 'FieldOptions'

	enum_options_message = 'EnumOptions'
	enum_value_options_message = 'EnumValueOptions'
)

fn (p &Parser) find_valid_options() Options {
	// Look for the messages for all the options

	// First we need to get the default set of options
	// file_options := p.type_table.lookup_message(file_options_message)
	// message_message := p.type_table.lookup_message(message_options_message)
	// field_message := p.type_table.lookup_message(field_options_message)
	// enums_message := p.type_table.lookup_message(enum_options_message)
	// enum_value_message := p.type_table.lookup_message(enum_value_options_message)

	// First file level options
	// for _, file in p.files {
	// 	for _, o in file.options {

	// 	}
	// }

	return Options{}
}

fn (p &Parser) check_file_options(file &File, valid_options []OptionField) {
}

fn (p &Parser) check_field_options(field &Field, valid_options []FieldOption) {
}

fn (p &Parser) check_message_field_options(message &Message, valid_options []FieldOption) {
}

fn (p &Parser) check_message_options(message &Message, valid_options []OptionField) {
}

fn (p &Parser) check_enum_field_options(e &Enum, valid_options []FieldOption) {
}

fn (p &Parser) check_enum_options(e &Enum, valid_options []OptionField) {
}

fn (p &Parser) check_options() {
	valid_options := p.find_valid_options()

	for _, file in p.files {
		for _, message in file.messages { 
			p.check_message_options(message, valid_options.message_options)
			p.check_message_field_options(message, valid_options.message_field_options) 
		}

		for _, extend in file.extends {
			for _, field in extend.fields {
				p.check_field_options(field, valid_options.message_field_options)
			}
		}

		for _, e in file.enums { 
			p.check_enum_options(e, valid_options.enum_options)
			p.check_enum_field_options(e, valid_options.enum_field_option) 
		}

		p.check_file_options(file, valid_options.file_options)
	}
}

pub fn (p &Parser) validate() {
	// Check whether everything is gucci or not

	// - check that field numbers do not overlap
	p.check_field_numbers()

	// - check file level extends
	p.check_file_extends()

	// - check that field names do not overlap
	p.check_field_names()

	// - check all field types
	p.check_field_types()

	// - check that options are valid
	p.check_options()
}
