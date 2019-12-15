module vproto

pub struct Bytes {
	// TODO
}

// TODO cut n paste from definitions.v
const (
	valid_types = ['double', 'float',
					'int32', 'int64',
					'uint32', 'uint64',
					'sint32', 'sint64',
					'fixed32', 'fixed64',
					'sfixed32', 'sfixed64',
					'bool', 'string', 'bytes']
)

pub enum FieldType {
	double float
	int32 int64
	uint32 uint64
	sint32 sint64
	fixed32 fixed64
	sfixed32 sfixed64
	bool_ string_ bytes

	// Not included in the const block above but used below
	message
	enum_
}

// Generic protobuf field interface
pub struct RuntimeField {
pub:
	typ_str string
	typ_str_v string
	typ FieldType

	name string
	name_v string
	number i64
}

interface Messageer {
	name() string

	serialize_to_array() ?[]byte
	parse_from_array(data []byte) bool

	// Get the fields that back this message
	fields() []RuntimeField
	field_name_to_number(name string) ?i64
	field_v_name_to_number(name string) ?i64
	field_from_number(number i64) ?RuntimeField
}

pub struct RuntimeMessage {
	// TODO
}

