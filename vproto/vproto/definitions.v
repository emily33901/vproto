module vproto

// Protobuf definitions



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

	options []FieldOption
}

pub struct Enum {
	name string
	options []OptionField
	fields []EnumField
}

pub struct Field {
	label string
	name string
	t string
	number string // int literal

	options []FieldOption
}

pub struct Extend {
	t string [json:'type']

	fields []Field
}

pub struct Extension {
	ranges []string
}

pub struct Oneof {
	name string

	fields []Field
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

pub struct ServiceMethod {
	name string
	arg_type string

	return_type string
}


pub struct Service {
	name string

	method []ServiceMethod

	options []OptionField
}