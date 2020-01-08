module vproto

pub struct Bytes {
	// TODO
	}

	pub fn (b Bytes) str() string {
		return ''
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
	// Protobuf field descriptor
	pub struct FieldDescriptor {
	pub:
		typ_str       string
		typ_str_v     string
		typ           FieldType
		name          string
		name_v        string
		number        u32
		default_value RuntimeValuer
	}

	interface RuntimeFielder {
		typ          ()FieldType
		field_type   ()FieldType
		value        ()RuntimeValuer
		default_value()RuntimeValuer
		number       ()int
		// For optional may return true of false
		// for anything else will return true
		has          ()bool
	}

	pub struct RuntimeRequiredField {
	pub:
		descriptor    &FieldDescriptor
		runtime_value RuntimeValuer
	}

	pub struct OneofFieldValue {
		internal &RuntimeRequiredField
	}

	pub struct RuntimeOneofField {
	pub:
	// values in this oneof
		values     []OneofFieldValue
		// which oneof this is
		oneof_case int
	}

	pub struct RuntimeOptionalField {
	pub:
		descriptor    &FieldDescriptor
		runtime_value RuntimeValuer
		has           bool
	}

	pub struct RuntimeRepeatedField {
	pub:
	// TODO
		todo int
	}

	pub fn (f &RuntimeRequiredField) typ() FieldType {
		return f.descriptor.typ
	}

	pub fn (f &RuntimeRequiredField) number() int {
		return f.descriptor.number
	}

	pub fn (f &RuntimeRequiredField) has() bool {
		return true
	}

	pub fn (f &RuntimeRequiredField) default_value() RuntimeValuer {
		return f.descriptor.default_value
	}

	pub fn (f &RuntimeRequiredField) value() RuntimeValuer {
		return f.runtime_value
	}

	pub fn (f &RuntimeOneofField) typ() FieldType {
		return f.values[f.oneof_case].internal.typ()
	}

	pub fn (f &RuntimeOneofField) number() int {
		return f.values[f.oneof_case].internal.number()
	}

	pub fn (f &RuntimeOneofField) has() bool {
		return true
	}

	pub fn (f &RuntimeOneofField) default_value() RuntimeValuer {
		return f.values[f.oneof_case].internal.default_value()
	}

	pub fn (f &RuntimeOneofField) value() RuntimeValuer {
		return f.values[f.oneof_case].internal.value()
	}

	pub fn (f &RuntimeOptionalField) typ() FieldType {
		return f.descriptor.typ
	}

	pub fn (f &RuntimeOptionalField) number() int {
		return f.descriptor.number
	}

	pub fn (f &RuntimeOptionalField) has() bool {
		return f.has
	}

	pub fn (f &RuntimeOptionalField) default_value() RuntimeValuer {
		return f.descriptor.default_value
	}

	pub fn (f &RuntimeOptionalField) value() RuntimeValuer {
		return f.runtime_value
	}

	interface Messageer {
		name                  ()string
		serialize_to_array    ()?[]byte
		parse_from_array      (data []byte)bool
		// Get the fields that back this message
		fields                ()[]FieldDescriptor
		field_name_to_number  (name string)?int
		field_v_name_to_number(name string)?int
		field_from_number     (number int)?FieldDescriptor
	}

	pub struct RuntimeMessage {
		// TODO
		}
