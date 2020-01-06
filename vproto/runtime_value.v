module vproto

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

interface RuntimeValuer { 
	typ() FieldType

	packed_size() u32
	pack() []byte
}

struct ValueInt32 {
	value int
}

struct ValueInt64 {
	value i64
}

struct ValueUInt32 {
	value u32
}

struct ValueUInt64 {
	value u64
}

struct ValueSInt32 {
	value int
}

struct ValueSInt64 {
	value i64
}

struct ValueFixed32 {
	value u32
}

struct ValueFixed64 {
	value u64
}

struct ValueSFixed32 {
	value int
}

struct ValueSFixed64 {
	value i64
}

struct ValueFloat {
	value f32
}

struct ValueDouble {
	value f64
}

struct ValueBool {
	value bool
}

struct ValueString {
	value string
}

struct ValueBytes {
	value Bytes
}

pub struct ValueMessage {
	fields []RuntimeFielder
}

pub struct ValueEnum {
	value int
}

pub fn (v &ValueInt32) typ() FieldType {
	return .int32
}

pub fn (v &ValueInt64) typ() FieldType {
	return .int64
}

pub fn (v &ValueSInt32) typ() FieldType {
	return .sint32
}

pub fn (v &ValueSInt64) typ() FieldType {
	return .sint64
}

pub fn (v &ValueUInt32) typ() FieldType {
	return .uint32
}

pub fn (v &ValueUInt64) typ() FieldType {
	return .uint64
}

pub fn (v &ValueFixed32) typ() FieldType {
	return .fixed32
}

pub fn (v &ValueFixed64) typ() FieldType {
	return .fixed64
}

pub fn (v &ValueSFixed32) typ() FieldType {
	return .sfixed32
}

pub fn (v &ValueSFixed64) typ() FieldType {
	return .sfixed64
}

pub fn (v &ValueFloat) typ() FieldType {
	return .float
}

pub fn (v &ValueDouble) typ() FieldType {
	return .double
}

pub fn (v &ValueMessage) typ() FieldType {
	return .message
}

pub fn (v &ValueString) typ() FieldType {
	return .string_
}

pub fn (v &ValueBytes) typ() FieldType {
	return .bytes
}

pub fn (v &ValueBool) typ() FieldType {
	return .bool_
}

pub fn (v &ValueEnum) typ() FieldType {
	return .enum_
}

pub fn (v &ValueInt32) packed_size() u32 {
	return int32_size(v.value)
}

pub fn (v &ValueInt64) packed_size() u32 {
	return uint64_size(u64(v.value))
}

pub fn (v &ValueSInt32) packed_size() u32 {
	return sint32_size(v.value)
}

pub fn (v &ValueSInt64) packed_size() u32 {
	return sint64_size(v.value)
}

pub fn (v &ValueUInt32) packed_size() u32 {
	return uint32_size(v.value)
}

pub fn (v &ValueUInt64) packed_size() u32 {
	return uint64_size(v.value)
}

pub fn (v &ValueFixed32) packed_size() u32 {
	return 4
}

pub fn (v &ValueFixed64) packed_size() u32{
	return 8
}

pub fn (v &ValueSFixed32) packed_size() u32{
	return 4
}

pub fn (v &ValueSFixed64) packed_size() u32{
	return 8
}

pub fn (v &ValueFloat) packed_size() u32 {
	return 4
}

pub fn (v &ValueDouble) packed_size() u32 {
	return 8
}

pub fn (v &ValueMessage) packed_size() u32 {
	mut size := u32(0)
	
	for _, x in v.fields {
		size += x.value().packed_size()
	}
	return size
}

pub fn (v &ValueString) packed_size() u32 {
	if v.value.len == 0 { return 0 }

	return uint32_size(u32(v.value.len)) + u32(v.value.len)
}

pub fn (v &ValueBytes) packed_size() u32 {
	return 0
}

pub fn (v &ValueBool) packed_size() u32 {
	return 1
}

pub fn (v &ValueEnum) packed_size() u32 {
	return int32_size(v.value)
}


pub fn (v &ValueInt32) pack() []byte {
	return []
}

pub fn (v &ValueInt64) pack() []byte {
	return []
}

pub fn (v &ValueSInt32) pack() []byte {
	return []
}

pub fn (v &ValueSInt64) pack() []byte {
	return []
}

pub fn (v &ValueUInt32) pack() []byte {
	return []
}

pub fn (v &ValueUInt64) pack() []byte {
	return []
}

pub fn (v &ValueFixed32) pack() []byte {
	return []
}

pub fn (v &ValueFixed64) pack() []byte {
	return []
}

pub fn (v &ValueSFixed32) pack() []byte {
	return []
}

pub fn (v &ValueSFixed64) pack() []byte {
	return []
}

pub fn (v &ValueFloat) pack() []byte {
	return []
}

pub fn (v &ValueDouble) pack() []byte {
	return []
}

pub fn (v &ValueMessage) pack() []byte {
	return []
}

pub fn (v &ValueString) pack() []byte {
	return []
}

pub fn (v &ValueBytes) pack() []byte {
	return []
}

pub fn (v &ValueBool) pack() []byte {
	return []
}

pub fn (v &ValueEnum) pack() []byte {
	return []
}

pub fn (v ValueInt32) 	str() string { return '$v.value'}
pub fn (v ValueInt64) 	str() string { return '$v.value'}
pub fn (v ValueSInt32) 	str() string { return '$v.value'}
pub fn (v ValueSInt64) 	str() string { return '$v.value'}
pub fn (v ValueUInt32) 	str() string { return '$v.value'}
pub fn (v ValueUInt64) 	str() string { return '$v.value'}
pub fn (v ValueFixed32) str() string { return '$v.value'}
pub fn (v ValueFixed64) str() string { return '$v.value'}
pub fn (v ValueSFixed32)str() string { return '$v.value'}
pub fn (v ValueSFixed64)str() string { return '$v.value'}
pub fn (v ValueFloat) 	str() string { return '$v.value'}
pub fn (v ValueDouble) 	str() string { return '$v.value'}
pub fn (v ValueMessage)	str() string {
	text := '{ TODO'
	for _, x in v.fields {
	}
	return '$text }'
}
pub fn (v ValueString)	str() string { return '$v.value'}
pub fn (v ValueBytes) 	str() string { return '$v.value'}
pub fn (v ValueBool) 	str() string { return '$v.value'}
pub fn (v ValueEnum) 	str() string { return '$v.value' }

// Default values
pub const (
	default_int32 = ValueInt32{0}
	default_int64 = ValueInt64{0}

	default_uint32 = ValueUInt32{0}
	default_uint64 = ValueUInt64{0}

	default_sint32 = ValueSInt32{0}
	default_sint64 = ValueSInt64{0}

	default_fixed32 = ValueFixed32{0}
	default_fixed64 = ValueFixed64{0}

	default_sfixed32 = ValueSFixed32{0}
	default_sfixed64 = ValueSFixed64{0}

	default_float = ValueFloat{0}
	default_double = ValueDouble{0}

	default_bool = ValueBool{false}
	default_string = ValueString{''}
	default_bytes = ValueBytes{}

	// Temporary
	// nothing should refer to this and each message
	// should have their own default state
	default_default_message = ValueMessage{}
	default_default_enum = ValueEnum{0}
)