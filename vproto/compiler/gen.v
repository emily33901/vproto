module compiler

fn empty_double_string() (string, string) {
	return '', ''
}

// TODO this file needs a massive refactor and clean
// So much code just everywhere with functions that dont
// make any sense
// Please just fix it before its too late...

// Other things that would be nice

// Functions for getting names / types consistently
// instead of manually creating m_name and m_full_name
// in each of the places that they are used!

struct Gen {
	type_table &TypeTable

mut: 
	current_package string
}

fn (g &Gen) gen_file_header(f &File) string {
	// TODO figure out an appropriate module
	// if the file doesnt have an explicit package set

	return '
// Generated by vproto - Do not modify
module vproto_gen

import vproto

pub const (
	// v_package = \'$g.current_package\'
)
'
}

fn (g &Gen) gen_enum_definition(type_context []string, e &Enum) string {
	names := message_names(type_context, e.name)
	
	e_name := names.struct_name
	e_full_name := names.lowercase_name

	mut text := '\nenum ${e_name} {\n'

	for _, field in e.fields {
		text += '\t${to_v_field_name(field.name)} = $field.value.value\n'
	}

	text += '}\n\n'

	// generate packing and unpacking functions

	text += 'fn pack_${e_full_name}(e $e_name, num u32) []byte {\n'
	text += '\treturn vproto.pack_int32_field(int(e), num)\n'
	text += '}\n'
	
	text += 'fn unpack_${e_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $e_name) {\n'
	text += '\ti, v := vproto.unpack_int32_field(buf, tag_wiretype)\n'
	text += '\treturn i, ${e_name}(v)\n'
	text += '}\n'

	// TODO helper functions here 
	// https://developers.google.com/protocol-buffers/docs/reference/cpp-generated#enum

	return text
}

// TODO When type_to_type changes name change this name too ! 
fn (g &Gen) type_to_type(context []string, t string) (string, type_type) {
	mut full_context := [g.current_package]
	full_context << context

	return type_to_type(g.current_package, g.type_table, full_context, t)
}

fn (g &Gen) type_pack_name(pack_or_unpack string, field_proto_type string, field_v_type string field_type_type type_type) string {
	match field_type_type {
		.other {
			match field_proto_type {
				'fixed32' {
					return 'vproto.${pack_or_unpack}_32bit_field'
				}

				'sfixed32' {
					return 'vproto.${pack_or_unpack}_s32bit_field'
				}

				'float' {
					return 'vproto.${pack_or_unpack}_float_field'
				}

				'fixed64' {
					return 'vproto.${pack_or_unpack}_64bit_field'
				}

				'sfixed64' {
					return 'vproto.${pack_or_unpack}_s64bit_field'
				}

				'double' {
					return 'vproto.${pack_or_unpack}_double_field'
				}

				'int32' {
					return 'vproto.${pack_or_unpack}_int32_field'
				}

				'sint32' {
					return 'vproto.${pack_or_unpack}_sint32_field'
				}

				'sint64' {
					return 'vproto.${pack_or_unpack}_sint64_field'
				}

				'uint32' {
					return 'vproto.${pack_or_unpack}_uint32_field'
				}

				'int64' {
					return 'vproto.${pack_or_unpack}_int64_field'
				}

				'uint64' {
					return 'vproto.${pack_or_unpack}_uint64_field'
				}

				'bool' {
					return 'vproto.${pack_or_unpack}_bool_field'
				}

				'string' {
					return 'vproto.${pack_or_unpack}_string_field'
				}

				'bytes' {
					return 'vproto.${pack_or_unpack}_bytes_field'
				}

				else {
					panic('unknown type `$field_proto_type`')
				}
			}
		}

		.enum_, .message {
			return '${pack_or_unpack}_$field_v_type'
		}

		.message {
			return '${pack_or_unpack}_$field_v_type'
		}

		else {
			panic('unkown field_type_type `$field_type_type`')
		}
	}
}

fn (g &Gen) gen_field_pack_text(label string, field_proto_type string, field_v_type string, field_type_type type_type, name, number string) (string, string) {
	mut pack_text := ''
	mut unpack_text := ''

	match label {
		'optional', 'required' {
			pack_inside := g.type_pack_name('pack', field_proto_type, field_v_type, field_type_type)
			unpack_inside := g.type_pack_name('unpack', field_proto_type, field_v_type, field_type_type)

			unpack_text += '\t\t\t$number {\n'

			if label == 'optional' {
				pack_text += '\tif o.has_$name {\n\t'

				unpack_text += '\t\t\t\tres.has_$name = true\n'
			}

			pack_text += '\tres << ${pack_inside}(o.$name, $number)\n'

			if label == 'optional' {
				pack_text += '\t}\n'
			}

			// unpack text at this point is inside of a match statement checking tag numbers

			// TODO make this into a oneliner again once match bug is fixed

			unpack_text += '\t\t\t\tii, v := ${unpack_inside}(cur_buf, tag_wiretype.wire_type)\n'
			unpack_text += '\t\t\t\tres.$name = v\n'
			unpack_text += '\t\t\t\ti = ii\n'
			unpack_text += '\t\t\t}\n'
		}

		'repeated' {
			pack_text += '\t// TODO repeated field `$name`\n'
			unpack_text += '\t\t\t$number { /* TODO repeated field `$name` */ }\n'
		}

		else {
			println('Unknown label $label')
		}
	}

	return pack_text, unpack_text

}

fn (g &Gen) gen_message_internal(type_context []string, m &Message) string {
	mut text := ''

	m_names := type_to_names(m.typ)

	// TODO replace with message_namess
	m_name := to_v_message_name(type_context, m.name)
	m_full_name := (type_context.join('') + m.name).to_lower()

	mut this_type_context := type_context.clone()
	this_type_context << m.name

	// Generate for submessages
	for _, sub in m.messages {
		text += g.gen_message_internal(this_type_context, sub)
	}
	
	// Generate for subenums
	for _, sub in m.enums {
		text += g.gen_enum_definition(this_type_context, sub)
	}

	pack_unpack_mut := if m.fields.len > 0 {
		'mut '
	} else {
		''
	}

	mut field_pack_text := '\npub fn (o &$m_name) pack() []byte {\n'
	field_pack_text += '\t${pack_unpack_mut}res := []byte // TODO allocate correct size statically\n\n'
	
	mut field_unpack_text := '\npub fn ${m_full_name}_unpack(buf []byte) ?$m_name {\n'
	field_unpack_text += '\t${pack_unpack_mut}res := $m_name{}\n'

	if m.fields.len > 0 {
		field_unpack_text += '\tmut total := 0\n'
		field_unpack_text += '\tfor total < buf.len {\n'
		field_unpack_text += '\t\tmut i := 0\n'
		field_unpack_text += '\t\tbuf_before_wiretype := buf[total..]\n'
		field_unpack_text += '\t\ttag_wiretype := vproto.unpack_tag_wire_type(buf) or { return error(\'malformed protobuf\') }\n'
		field_unpack_text += '\t\tcur_buf := buf_before_wiretype[tag_wiretype.consumed..]\n'
		field_unpack_text += '\t\tmatch tag_wiretype.tag {\n'
	}

	text += '\npub struct $m_name {\n'

	if m.fields.len > 0 {
		text += 'mut:\n\n'
	}

	for _, field in m.fields {
		field_type, field_type_type := g.type_to_type(field.type_context, field.t)
		name := escape_name(field.name)

		if field.label == 'optional' {
			text += '\t${name} ${field_type}\n'
			text += '\thas_${name} bool\n'

		} else if field.label == 'required' {
			text += '\t${name} ${field_type}\n'
		} else if field.label == 'repeated' {
			text += '\t${name} []${field_type}\n'
		}

		// Seperate fields nicer
		text += '\n'

		mut pack_text := ''
		mut unpack_text := ''

		if field_type_type == .enum_ || field_type_type == .message {
			names := message_names([], field.t)
			n := (field.type_context.join('') + names.lowercase_name).to_lower()
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, names.lowercase_name, field_type_type, name, field.number)
		} else {
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, field_type, field_type_type, name, field.number)
		}

		field_pack_text += pack_text
		field_unpack_text += unpack_text
	}

	// TODO oneofs maps extensions and similar

	text += '}\n\n'

	field_pack_text += '\treturn res\n'
	field_pack_text += '}\n\n'

	if m.fields.len > 0 {
		// close match then for then func
		field_unpack_text += '\t\t\telse { println(\'Found unknown field tag `\$tag_wiretype.tag`\') }\n'
		field_unpack_text += '\t\t}\n'

		// TODO we need to actually implement parsing of unknown fields otherwise this will
		// always trigger if we hit one
		field_unpack_text += '\t\tif i == 0 { return error(\'malformed protobuf\') }\n'
		field_unpack_text += '\t\ttotal += i\n'
		field_unpack_text += '\t}\n'
	}
	field_unpack_text += '\treturn res\n'
	field_unpack_text += '}\n\n'

	// Function for creating a new of that message

	text += 'pub fn new_${m_full_name}() $m_name {\n'
	text += '\treturn $m_name{}'
	text += '\n}\n\n'

	text += field_pack_text
	text += field_unpack_text

	// pack and unpack wrappers for when its called as a submessage
	text += 'fn pack_${m_full_name}(o $m_name, num u32) []byte {\n'
	text += '\treturn vproto.pack_message_field(o.pack(), num)\n'
	text += '}\n'
	
	text += 'fn unpack_${m_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $m_name) {\n'
	text += '\ti, v := vproto.unpack_message_field(buf, tag_wiretype)\n'
	text += '\treturn i, ${m_full_name}_unpack(v) or { panic (\'\') }\n'
	text += '}\n'


	// TODO oneof, maps and similar

	return text
}

pub fn (g mut Gen) gen_file_text(f &File) string {
	g.current_package = f.package
	mut generated_text := g.gen_file_header(f)

	for _, e in f.enums {
		generated_text += g.gen_enum_definition([], e)
	}

	// Then generate the actual structs that back the messages
	for _, m in f.messages {
		generated_text += g.gen_message_internal([], m)
	}

	return generated_text
}

pub fn new_gen(p &Parser) Gen {
	return Gen{type_table: p.type_table}
}