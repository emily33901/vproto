module vproto

#include "protobuf-c/protobuf-c.h"
#flag vproto/protobuf-c/protobuf-c.o
pub const (
	PROTOBUF_C__SERVICE_DESCRIPTOR_MAGIC = u32(0x14159bc3)
	PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC = u32(0x28aaeef9)
	PROTOBUF_C__ENUM_DESCRIPTOR_MAGIC = u32(0x114315af)
)
// C.ProtobufCType
pub enum ProtobufCType {
	int32 = 0,/**< int32 */

	sint32,/**< signed int32 */

	sfixed32,/**< signed int32 (4 bytes) */

	int64,/**< int64 */

	sint64,/**< signed int64 */

	sfixed64,/**< signed int64 (8 bytes) */

	uint32,/**< unsigned int32 */

	fixed32,/**< unsigned int32 (4 bytes) */

	uint64,/**< unsigned int64 */

	fixed64,/**< unsigned int64 (8 bytes) */

	float,/**< float */

	double,/**< double */

	bool_,/**< boolean */

	enum_,/**< enumerated type */

	string_,/**< UTF-8 or ASCII string */

	bytes,/**< arbitrary byte sequence */

	message,/**< nested message */

}

pub enum ProtobufCFieldFlag {
	/** Set if the field is repeated and marked with the `packed` option. */
	packed = 1
	/** Set if the field is marked with the `deprecated` option. */

	deprecated = 2
	/** Set if the field is a member of a oneof (union). */

	oneof = 4
}

pub enum ProtobufCLabel {
	required,
	optional,
	repeated,
	none_,
}

pub struct ProtobufCEnumValue {
	name   charptr
	c_name charptr
	value  int
}

pub struct ProtobufCEnumValueIndex {
	name  charptr
	index u32
}

pub struct ProtobufCEnumDescriptor {
	magic          u32
	name           charptr
	short_name     charptr
	c_name         charptr
	package_name   charptr
	n_values       u32
	values         &C.ProtobufCEnumValue
	n_value_names  u32
	values_by_name &C.ProtobufCEnumValueIndex
	n_value_ranges u32
	value_ranges   &C.ProtobufCIntRange
	reserved1      voidptr
	reserved2      voidptr
	reserved3      voidptr
	reserved4      voidptr
}

pub struct ProtobufCFieldDescriptor {
pub:
	name              charptr
	id                u32
	label             ProtobufCLabel
	typ               ProtobufCType
	quantifier_offset u32
	offset            u32
	descriptor        voidptr
	default_value     voidptr
	flags             u32
	reserved_flags    u32
	reserved2         voidptr
	reserved3         voidptr
}

pub struct ProtobufCIntRange {
	start_value int
	orig_index  u32
}

pub struct ProtobufCMessage {
pub mut:
	descriptor       &ProtobufCMessageDescriptor
	n_unknown_fields u32
	unknown_fields   &C.ProtobufCMessageUnknownField
}

pub fn (m mut ProtobufCMessage) init(desc &ProtobufCMessageDescriptor) {
	m.descriptor = desc
	m.n_unknown_fields = 0
	m.unknown_fields = &ProtobufCMessageUnknownField(0)
}

pub struct ProtobufCMessageDescriptor {
	magic            u32
	name             charptr
	short_name       charptr
	c_name           charptr
	package_name     charptr
	sizeof_message   C.size_t
	n_fields         u32
	fields           &C.ProtobufCFieldDescriptor
	indicies_by_name &int
	n_field_ranges   u32
	field_ranges     &C.ProtobufCIntRange
	message_init     fn(&ProtobufCMessage) // ProtobufCMessageInit
	reserved1        voidptr
	reserved2        voidptr
	reserved3        voidptr
}

struct C.ProtobufCMessageUnknownField {
	tag       u32
	wire_type C.ProtobufCWireType
	len       u32
	data      &byte
}

fn C.protobuf_c_version() &byte


pub fn c_version() string {
	return cstring_to_vstring(C.protobuf_c_version())
}

fn C.protobuf_c_message_get_packed_size(msg &ProtobufCMessage) int


pub fn message_packed_size(msg &ProtobufCMessage) int {
	return C.protobuf_c_message_get_packed_size(msg)
}

fn C.protobuf_c_message_pack(message &ProtobufCMessage, out &byte) u32


pub fn message_pack(msg &ProtobufCMessage) []byte {
	size := message_packed_size(msg)
	out := [byte(0)].repeat(size)
	wrote := C.protobuf_c_message_pack(msg, out.data)
	assert wrote == size
	return out
}

fn C.protobuf_c_message_unpack(descriptor &ProtobufCMessageDescriptor, alloc voidptr, len int, data &byte) &ProtobufCMessage


pub fn message_unpack(desc &ProtobufCMessageDescriptor, buf []byte) &ProtobufCMessage {
	return C.protobuf_c_message_unpack(desc, voidptr(0), buf.len, buf.data)
}
