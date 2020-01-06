module compiler

// Protobuf definitions

enum LitType {
	ident = 0
	integral
	float
	str
	boolean
}

struct Literal {
	t LitType [json:'type']
	value string
}

pub struct SrcLoc {
	// TODO fill out and use in other definitions
	file string
	line int
	char int
}

pub fn (s SrcLoc) str() string {
	return '$s.file:$s.line:$s.char'
}

pub struct Import {
	weak bool
	public bool
	package string
}

// TODO make the distinction between OptionField and FieldOption more distinct
// or roll them up into one thing!

pub struct OptionField {
	ident string
	value Literal
}

pub struct FieldOption {
	ident string
	value Literal
}

pub struct EnumField {
	name string
	value Literal // int literal

	options []&FieldOption
}

pub struct Enum {
	name string
	options []&OptionField
	fields []&EnumField

	typ &Type
}

const (
	valid_types = ['double', 'float',
					'int32', 'int64',
					'uint32', 'uint64',
					'sint32', 'sint64',
					'fixed32', 'fixed64',
					'sfixed32', 'sfixed64',
					'bool', 'string', 'bytes']

	valid_types_v = ['f64', 'f32', 
					'int', 'i64',
					'u32', 'u64',
					'int', 'i64',
					'u32', 'u64',
					'int', 'i64',
					'bool', 'string', '[]byte']

	keywords_v = ['type', 'error']
)

pub struct Field {
	label string
	name string
	t string [json:'type']

	// this is stored so we dont have to
	// recreate it in gen
	type_context []string
	number string // int literal

	options []&FieldOption
}

pub struct Extend {
	t string [json:'type']

	fields []&Field
}

pub struct Extension {
	ranges []string
}

pub struct Oneof {
	name string

	fields []&Field
}

pub struct MapField {
	name string
	
	key_type string
	value_type string

	number string // int literal
}

pub struct Reserved {
	is_ranges bool
	fields []string
}

pub struct Message {
	name string

	fields []&Field
	enums []&Enum
	messages []&Message [skip]
	extends []&Extend
	extensions []&Extension
	options []&OptionField
	oneofs []&Oneof
	map_fields []&MapField
	reserveds []&Reserved

	typ &Type
}

pub struct ServiceMethod {
	name string
	arg_type string

	return_type string
}


pub struct Service {
	name string

	method []&ServiceMethod

	options []&OptionField
}