module compiler

// TODO this file needs a massive refactor and clean
// So much code just everywhere with functions that dont
// make any sense
// Please just fix it before its too late...

struct GenProtoC {
	type_table &TypeTable

mut: 
	current_package string
}

fn (g &GenProtoC) gen_file_header(f File) string {
	// TODO figure out an appropriate module
	// if the file doesnt have an explicit package set

	basename := f.filename.all_before_last('.').all_after('/')

	return '
// Generated by vproto - Do not modify
// For use with protobuf-c
//module vproto_gen
module main

import vproto

pub const (
	v_${basename}_package = \'$g.current_package\'
)
'
}

fn (g &GenProtoC) prologue(f &File) string {
	return '	
fn main() {
	mut test := cmsggccstrike15_v2_clienttogcrequestticket_new()

	test.authorized_public_ip = 1234
	test.gameserver_net_id = 12345

	packed := test.pack()

	unpacked := cmsggccstrike15_v2_clienttogcrequestticket_unpack(packed)

	println(\'\$unpacked.gameserver_net_id\')
}

'
}

fn (g &GenProtoC) gen_enum_definition(type_context []string, e &Enum) string {
	e_name := to_v_struct_name(type_context.join('') + e.name)

	e_full_name := (type_context.join('') + e.name).to_lower()

	enum_default_value := e.fields[0].value.value

	mut text := 'pub const (\n'

	// TODO handle empty enum case
	// TODO proper ranges

	mut enum_fields := '\t${e_full_name}_fields = [\n'
	mut enum_names := '\t${e_full_name}_value_names = [\n' 
	enum_value_ranges := '\t${e_full_name}_value_ranges = [[0, $e.fields.len]]\n'

	for i, field in e.fields {
		enum_fields += '\t\tvproto.ProtobufCEnumValue{\n'
		enum_fields += '\t\t\tc\'$field.name\',\n'
		enum_fields += '\t\t\tc\'$field.name\',\n'
		enum_fields += '\t\t\t$field.value.value,\n'
		enum_fields += '\t\t},\n'

		enum_names += '\t\tvproto.ProtobufCEnumValueIndex{\n'
		enum_names += '\t\t\tc\'$field.name\',\n'
		enum_names += '\t\t\tu32($i)\n'
		enum_names += '\t\t},\n'
	}

	enum_fields += '\t]\n'
	enum_names += '\t]\n'

	text += enum_fields + enum_names + enum_value_ranges

	text += '\t${e_full_name}_descriptor = &vproto.ProtobufCEnumDescriptor{\n'
	text += '\t\tvproto.PROTOBUF_C__ENUM_DESCRIPTOR_MAGIC,\n'
	text += '\t\tc\'$e.name\',\n'
	text += '\t\tc\'$e_name\',\n'
	text += '\t\tc\'$e_full_name\',\n'
	text += '\t\tc\'$g.current_package\',\n'
	text += '\t\t$e.fields.len,\n'
	text += '\t\t${e_full_name}_fields.data,\n'

	text += '\t\tu32(${e_full_name}_value_names.len), '
	text += '${e_full_name}_value_names.data,\n'
	text += '\t\tu32(${e_full_name}_value_ranges.len), '
	text += '${e_full_name}_value_names.data,\n'
	
	text += '\t\tvoidptr(0), voidptr(0), voidptr(0), voidptr(0), \n'
	text += '\t}\n\n'

	text += ')\n\n'

	text += '\nenum ${e_name} {\n'

	for _, field in e.fields {
		text += '\t${to_v_field_name(field.name)} = $field.value.value\n'
	}

	text += '}\n'
	
	// TODO helper functions here
	// https://developers.google.com/protocol-buffers/docs/reference/cpp-generated#enum

	return text
}

enum type_type {
	message enum_ other
}

fn (g &GenProtoC) type_to_type(context []string, t string) (string, type_type) {
	mut full_context := [g.current_package]
	full_context << context

	if t in valid_types {
		return valid_types_v[valid_types.index(t)], type_type.other
	}

	if typ := g.type_table.lookup_type(full_context, t) {
		type_type := if typ.is_enum { type_type.enum_ } else { type_type.message }

		fname := typ.full_name

		if fname.starts_with('.$g.current_package') {
			return to_v_message_name([], typ.full_name['.$g.current_package'.len..]), type_type
		}

		if typ.full_name[0] == `.` {
			return to_v_message_name([], typ.full_name[1..]), type_type
		}

		return to_v_message_name([], typ.full_name), type_type
	}

	panic('Unknown type `$t`\ntable was:\n${g.type_table.str()}')
}

fn sort_field_by_name(a, b &Field) int { 
	if a.name < b.name {
		return -1
	} else if a.name > b.name {
		return 1
	}
	return 0
}

fn (g &GenProtoC) gen_message_field_def(this_type_context []string, field &Field, m_name string, oneof_name string) string {
	mut fields_block := '' 
	field_type, field_type_type := g.type_to_type(this_type_context, field.t)
	name := escape_name(field.name)

	enum_field_type := if field_type == 'string' || field_type == 'bool' {
		field_type + '_'
	} else if field_type_type == .message {
		'message'
	} else if field_type_type == .enum_ {
		'enum_'
	} else {
		field.t
	}

	default_value_type := if field_type_type == .other {
		'vproto.default_$field.t'
	} else if field_type_type == .message {
		'default_${to_v_message_name([], field_type).to_lower()}'
	} else if field_type_type == .enum_ {
		'default_${to_v_struct_name(field_type).to_lower()}'
	} else {
		''
	}

	fields_block += '\t\tvproto.ProtobufCFieldDescriptor{\n'
	fields_block += '\t\t\tc\'$field.name\',\n'
	fields_block += '\t\t\t$field.number,\n'
	if field.label == '' {
		fields_block += '\t\t\tvproto.ProtobufCLabel.optional,\n'
	} else {
		fields_block += '\t\t\tvproto.ProtobufCLabel.$field.label,\n'
	}
	fields_block += '\t\t\tvproto.ProtobufCType.$enum_field_type,\n'

	if oneof_name != '' {
		fields_block += '\t\t\t__offsetof($m_name, ${oneof_name}), // quantifier offset\n'
	}
	else if field.label == 'repeated' {
		fields_block += '\t\t\t__offsetof($m_name, $name) + __offsetof(C.array, len), // quantifier offset\n'
	} else if field.label == 'optional' {
		fields_block += '\t\t\t__offsetof($m_name, has_$name), // quantifier offset\n'
	} else {
		fields_block += '\t\t\t0, // quantifier offset\n'
	}

	// TODO quantifier for oneof

	fields_block += '\t\t\t__offsetof($m_name, $name)'

	if field.label == 'repeated' {
		fields_block += ' + __offsetof(C.array, data)'
	}

	fields_block += ',\n'


	if field_type_type == .message {
		t := to_v_message_name([], field_type).to_lower()
		fields_block += '\t\t\t${t}_descriptor,\n'
	} else if field_type_type == .enum_ {
		fields_block += '\t\t\t${to_v_struct_name(field_type).to_lower()}_descriptor,\n'
	} else {
		fields_block += '\t\t\tvoidptr(0),\n'
	}

	fields_block += '\t\t\tvoidptr(0), // default_value\n'

	fields_block += '\t\t\tu32(0)'

	if oneof_name != '' {
		fields_block += ' | u32(vproto.ProtobufCFieldFlag.oneof)'
	}

	fields_block += ', // flags\n'

	fields_block += '\t\t\t0, voidptr(0), voidptr(0) // reserveds\n'

	fields_block += '\t\t},\n'

	return fields_block
}

fn (g &GenProtoC) gen_message_runtime_info(type_context []string, m &Message) string {
	mut text := ''

	m_name := to_v_message_name(type_context, m.name)
	m_full_name := (type_context.join('') + m.name).to_lower()
	m_full_name_pkg := (g.current_package + type_context.join('.') + m.name)

	text += '\npub const (\n'

	mut this_type_context := type_context.clone()
	this_type_context << m.name

	mut fields_block := ''
	mut indicies_by_name := ''
	mut ranges := ''

	// TODO proper ranges please!

	if m.fields.len > 0 {
		fields_block = '\t${m_full_name}_fields = [\n'
		indicies_by_name = '\t${m_full_name}_indicies_by_name = [\n'
		ranges = '\t${m_full_name}_ranges\ = [\n'
	} else {
		fields_block = '\t${m_full_name}_fields = []vproto.ProtobufCFieldDescriptor\n'
		indicies_by_name = '\t${m_full_name}_indicies_by_name = []int\n'
		ranges = '\t${m_full_name}_ranges\ = []int'
	}


	for _, field in m.fields {
		fields_block += g.gen_message_field_def(this_type_context, field, m_name, '')
	}

	for _, oneof in m.oneofs {
		for _, field in oneof.fields {
			oneof_name := to_v_struct_name(this_type_context.join('') + oneof.name)
			field_name := escape_name(oneof_name)
			
			fields_block += g.gen_message_field_def(this_type_context, field, m_name, '${field_name.to_lower()}_oneof_case')
		}
	}


	mut sorted_fields := m.fields.clone()
	for _, x in m.oneofs {
		sorted_fields << x.fields
	}

	sorted_fields.sort_with_compare(sort_field_by_name)

	for _, field in sorted_fields {
		indicies_by_name += '\t\t$field.number, // $field.name\n'
	}

	if m.fields.len > 0 {
		fields_block += '\t]\n'
		indicies_by_name += '\t]\n'

		// TODO temp
		ranges += '\t\t[0, $m.fields.len]\n\t]\n'
	}

	text += indicies_by_name
	text += ranges
	// text += v_name_to_number_map
	text += fields_block

	desc_name := to_v_struct_name(m_full_name).to_lower()

	// Message descriptor
	text += '\t${desc_name}_descriptor = &vproto.ProtobufCMessageDescriptor{\n'
	text += '\t\tvproto.PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,\n'
	text += '\t\tc\'$m_full_name_pkg\',\n'
	text += '\t\tc\'$m.name\',\n'
	text += '\t\tc\'$m_name\',\n'
	text += '\t\tc\'$g.current_package\',\n'
	text += '\t\tsize_t(sizeof($m_name)),\n\n'
	text += '\t\t$m.fields.len,\n'
	text += '\t\t${m_full_name}_fields.data,\n'
	text += '\t\t${m_full_name}_indicies_by_name.data,\n'
	text += '\t\tu32(${m_full_name}_ranges.len), ${m_full_name}_ranges.data,\n'
	text += '\t\t${m_full_name}_init,\n'
	text += '\t\tvoidptr(0), voidptr(0), voidptr(0), \n'
	text += '\t}\n\n'

	text += '\n)\n'

	return text
}

fn (g &GenProtoC) gen_message_internal(type_context []string, m &Message) string {
	mut text := ''

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

	// Generate enums for oneof cases
	for _, sub in m.oneofs {
		mut fields := [
			&EnumField{
				'not_set',
				Literal {LitType.integral, '0'},
				[]&FieldOption
			}
		]

		for _, field in sub.fields {
			fields << &EnumField{
				field.name,
				Literal {LitType.integral, field.number},
				[]&FieldOption
			}
		}

		oneof_name := to_v_struct_name(this_type_context.join('') + sub.name)

		e := &Enum{
			name: '${oneof_name}OneofCase'
			options: []
			fields: fields
		}

		text += g.gen_enum_definition([], e)
	}

	text += '\nstruct $m_name {\n'

	if m.fields.len > 0 {
		text += 'mut:\n\n'
	}

	text += '\tbase vproto.ProtobufCMessage\n'


	for _, field in m.fields {
		field_type, _ := g.type_to_type(this_type_context, field.t)
		name := escape_name(field.name)

		if field.label == 'required' {
			text += '\t${name} ${field_type}\n'
		} else if field.label == 'optional' { 
			text += '\t${name} ${field_type}\n'
			text += '\thas_${name} bool\n\n'
		} else {
			text += '\t${name} []${field_type}\n\n'
		}
	}

	for _, oneof in m.oneofs {
		oneof_name := to_v_struct_name(this_type_context.join('') + oneof.name)
		field_name := escape_name(oneof_name)
		text += '\t${field_name.to_lower()}_oneof_case ${oneof_name}OneofCase\n'
		for _, field in oneof.fields {
			field_type, _ := g.type_to_type(this_type_context, field.t)
			name := escape_name(field.name)

			text += '\t${name} ${field_type}\n'
		}
	}

	text += '}\n'

	// Function for creating a new of that message

	desc_name := to_v_struct_name(m_full_name).to_lower()


	text += 'pub fn ${m_full_name}_init(msg &vproto.ProtobufCMessage) {\n'
	text += '\tmut mmsg := msg\n'
	text += '\tassert mmsg == msg\n'
	text += '\tmmsg.init(${desc_name}_descriptor)\n'
	text += '\n}\n\n'

	text += 'pub fn ${m_full_name}_new() &${m_name} {\n'
	text += '\tmsg := &$m_name{}\n'
	text += '\t${m_full_name}_init(&vproto.ProtobufCMessage(msg))\n'
	text += '\treturn msg\n'
	text += '}\n\n'


	// Now GenProtoC runtime info 
	// default_type depends on the struct being first
	text += g.gen_message_runtime_info(type_context, m)

	// TODO maps and similar


	text += 'fn (o &$m_name) packed_size() int {\n'
	text += '\treturn vproto.message_packed_size(&vproto.ProtobufCMessage(o))\n'
	text += '}\n'

	text += 'fn (o &$m_name) pack() []byte {\n'
	text += '\treturn vproto.message_pack(&vproto.ProtobufCMessage(o))\n'
	text += '}\n'

	text += 'fn ${m_full_name}_unpack(buf []byte) &$m_name {\n'
	text += '\treturn &${m_name}(vproto.message_unpack(${desc_name}_descriptor, buf))\n'
	text += '}\n'

	text += 'fn (o $m_name) serialize_to_array() ?[]byte {\n'
	text += '\treturn none\n'
	text += '}\n'

	text += 'fn (o $m_name) parse_from_array(data []byte) bool {\n'
	text += '\treturn false\n'
	text += '}\n'

	// Not sure if this should return descriptor or runtimefield

	text += 'fn (o $m_name) field_from_number(num int) ?vproto.ProtobufCFieldDescriptor {\n'
	text += '\tfor i, x in ${m_full_name}_fields {\n'
	text += '\t\tif x.id == num {\n'
	text += '\t\t\treturn ${m_full_name}_fields[i]\n'
	text += '\t\t}\n'
	text += '\t}\n'
	text += '\treturn none\n'
	text += '}\n'

	return text
}

pub fn (g mut GenProtoC) gen_file_text(f &File) string {
	g.current_package = f.package
	mut generated_text := g.gen_file_header(f)

	for _, e in f.enums {
		generated_text += g.gen_enum_definition([], e)
	}

	// Then generate the actual structs that back the messages
	for _, m in f.messages {
		generated_text += g.gen_message_internal([], m)
	}

	generated_text += g.prologue(f)

	return generated_text
}

pub fn new_gen_protoc(p &Parser) GenProtoC {
	return GenProtoC{type_table: p.type_table}
}