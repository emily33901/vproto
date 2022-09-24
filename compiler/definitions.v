module compiler

// Protobuf definitions
enum LitType {
	ident = 0
	integral
	float
	// TODO revert when vlang #5040 is fixed
	str_
	boolean
}

struct Literal {
	t     LitType
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

[heap]
pub struct Import {
	weak    bool
	public  bool

mut:
	package string
}

// TODO make the distinction between OptionField and FieldOption more distinct
// or roll them up into one thing!
[heap]
pub struct OptionField {
	ident string
	value Literal
}

[heap]
pub struct FieldOption {
	ident string
	value Literal
}

[heap]
pub struct EnumField {
	name    string
	value   Literal // int literal
	options []&FieldOption
}

[heap]
pub struct Enum {
	name    string
	options []&OptionField
	fields  []&EnumField
	typ     &Type
}

const (
	valid_types   = [
		'double', 'float',
		'int32', 'int64',
		'uint32', 'uint64',
		'sint32', 'sint64',
		'fixed32', 'fixed64',
		'sfixed32', 'sfixed64',
		'bool', 
		'string', 'bytes']
	valid_types_v = [
		'f64', 'f32',
		'int', 'i64',
		'u32', 'u64',
		'int', 'i64',
		'u32', 'u64',
		'int', 'i64',
		'bool', 
		'string', '[]u8']
	keywords_v    = ['type', 'none', 'module', 'match', 'or', 'select']
	type_max_scalar_index = 12
)

[heap]
pub struct Field {
	label        string
	name         string
	t            string
	// recreate it in gen
	type_context []string
	number       string // int literal
	options      []&FieldOption
}

[heap]
pub struct Extend {
	t      string
	fields []&Field
}

[heap]
pub struct Extension {
	ranges []string
}

[heap]
pub struct Oneof {
	name   string
	fields []&Field
}

[heap]
pub struct MapField {
	name       string
	key_type   string
	value_type string
	// recreate it in gen
	type_context []string
	number     string // int literal
}

[heap]
pub struct Reserved {
	is_ranges bool
	fields    []string
}

[heap]
pub struct Message {
	name       string
	fields     []&Field
	enums      []&Enum
	messages   []&Message
	extends    []&Extend
	extensions []&Extension
	options    []&OptionField
	oneofs     []&Oneof
	map_fields []&MapField
	reserveds  []&Reserved
	typ        &Type
}

[heap]
pub struct ServiceMethod {
	name        string
	arg_type    string
	arg_is_stream bool
	return_type string
	return_is_stream bool
}

[heap]
pub struct Service {
	name    string
	methods  []&ServiceMethod
	options []&OptionField
}

const (
	// Internal function prefix to deter people from using functions
	// that they are not supposed to
	vproto_ifp = "zzz_vproto_internal_"
)
