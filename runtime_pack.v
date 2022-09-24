module vproto

// higher level functions for packing fields of different types

// WireType is the protobuf wiretype of the field
pub enum WireType {
	varint = 0
	_64bit = 1
	length_prefixed = 2
	// we dont support groups
	_32bit = 5
}

fn pack_wire_type(w WireType) byte {
	return u8(int(w))
}

fn pack_tag_wire_type(tag u32, w WireType) []u8 {
	mut res := tag_pack(tag)
	res[0] |= pack_wire_type(w)
	return res
}

pub fn pack_sint32_field(value int, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << sint32_pack(value)
	return ret
}

pub fn pack_sint32_field_packed(values []int, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << uint32_packed_pack(values.map(zigzag32(it)))
	return ret
}

// enum or int32
pub fn pack_int32_field(value int, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << int32_pack(value)
	return ret
}

pub fn pack_int32_field_packed(values []int, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << int32_packed_pack(values)
	return ret
}

pub fn pack_uint32_field_packed(values []u32, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << uint32_packed_pack(values)
	return ret
}

pub fn pack_enum_field<T>(value T, num u32) []u8 {
	return pack_int32_field(int(value), num)
}

pub fn pack_uint32_field(value u32, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << uint32_pack(value)
	return ret
}

pub fn pack_sint64_field(value i64, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << sint64_pack(value)
	return ret
}

pub fn pack_int64_field(value i64, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	v := *(&u64(&value))
	ret << uint64_pack(v)
	return ret
}

pub fn pack_uint64_field(value u64, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << uint64_pack(value)
	return ret
}

pub fn pack_uint64_field_packed(values []u64, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << uint64_packed_pack(values)
	return ret
}

pub fn pack_32bit_field(value &u32, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, ._32bit)
	v := *(value)
	ret << fixed32_pack(v)
	return ret
}

pub fn pack_32bit_field_packed(values array, num u32) []u8 {
	assert values.element_size == 4
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	// v := array{data: values.data, element_size: 4, len: values.len}
	ret << fixed32_packed_pack(values)
	return ret
}

pub fn pack_s32bit_field(value &int, num u32) []u8 {
	return pack_32bit_field(&u32(value), num)
}

pub fn pack_64bit_field(value &u64, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, ._64bit)
	v := *(&u64(value))
	ret << fixed64_pack(v)
	return ret
}

pub fn pack_64bit_field_packed(values array, num u32) []u8 {
	assert values.element_size == 8
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)

	// v := array{data: values.data, element_size: 8, len: values.len}
	ret << fixed64_packed_pack(values)
	return ret
}

pub fn pack_s64bit_field(value i64, num u32) []u8 {
	return pack_64bit_field(&u64(value), num)
}

pub fn pack_float_field(value f32, num u32) []u8 {
	return pack_32bit_field(&u32(&value), num)
}

pub fn pack_double_field(value f64, num u32) []u8 {
	return pack_64bit_field(&u64(&value), num)
}

pub fn pack_bool_field(value bool, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .varint)
	ret << boolean_pack(value)
	return ret
}

pub fn pack_string_field(value string, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << string_pack(value)
	return ret
}

pub fn pack_bytes_field(value []u8, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << bytes_pack(value)
	return ret
}

pub fn pack_message_field(value []u8, num u32) []u8 {
	mut ret := []u8{}
	ret << pack_tag_wire_type(num, .length_prefixed)
	ret << bytes_pack(value)
	return ret
}

// unpacking routines

pub fn unpack_wire_type(b byte) WireType {
	return WireType(b & 0x7)
}

struct TagWireType {
pub:
	consumed  int
	tag       u32
	wire_type WireType
}

pub fn unpack_tag_wire_type(b []u8) ?TagWireType {
	rem := b.len
	max := if rem > 5 { 5 } else { rem }
	mut tag := u32(b[0] & 0x7f)>>3
	if b[0] & 0xf8 == 0 {
		return error('Invalid tag')
	}
	wire_type := WireType(b[0] & 0x7)
	if b[0] & 0x80 == 0 {
		return TagWireType{
			1,tag,wire_type}
	}
	mut shift := 4
	for i := 1; i < (max); i++ {
		if b[i] & 0x80 == 0x80 {
			tag |= (b[i] & 0x7f)<<shift
			shift += 7
		}
		else {
			tag |= (b[i])<<shift
			return TagWireType{
				i + 1,tag,wire_type}
		}
	}
	return error('Bad header')
}

pub fn ensure_wiretype(w WireType, expected WireType) ? {
	if w != expected {
		return error('Malformed: Invalid wiretype')
	}
}

// all of these return the number of consumed bytes + the value
pub fn unpack_sint32_field(buf []u8, wire_type WireType) ?(int, int) {
	ensure_wiretype(wire_type, .varint)?
	i,v := uint32_unpack(buf)
	return i,unzigzag32(v)
}

pub fn unpack_sint32_field_packed(buf []u8, wire_type WireType) ?(int, []int) {
	ensure_wiretype(wire_type, .length_prefixed)?
	i, v := uint32_unpack_packed(buf)
	return i, v.map(unzigzag32(it))
}

pub fn unpack_int32_field(buf []u8, wire_type WireType) ?(int, int) {
	ensure_wiretype(wire_type, .varint)?
	return int32_unpack(buf)
}

pub fn unpack_int32_field_packed(buf []u8, wire_type WireType) ?(int, []int) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return int32_unpack_packed(buf)
}

pub fn unpack_uint32_field_packed(buf []u8, wire_type WireType) ?(int, []u32) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return uint32_unpack_packed(buf)
}

pub fn unpack_uint32_field(buf []u8, wire_type WireType) ?(int,u32) {
	ensure_wiretype(wire_type, .varint)?
	return uint32_unpack(buf)
}

pub fn unpack_sint64_field(buf []u8, wire_type WireType) ?(int,i64) {
	ensure_wiretype(wire_type, .varint)?
	i,v := uint64_unpack(buf)
	return i,unzigzag64(v)
}

pub fn unpack_int64_field(buf []u8, wire_type WireType) ?(int,i64) {
	ensure_wiretype(wire_type, .varint)?
	i,v := uint64_unpack(buf)
	return i,*(&i64(&v))
}

pub fn unpack_uint64_field(buf []u8, wire_type WireType) ?(int,u64) {
	ensure_wiretype(wire_type, .varint)?
	return uint64_unpack(buf)
}

pub fn unpack_uint64_field_packed(buf []u8, wire_type WireType) ?(int, []u64) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return uint64_unpack_packed(buf)
}

pub fn unpack_32bit_field(buf []u8, wire_type WireType) ?(int,u32) {
	ensure_wiretype(wire_type, ._32bit)?
	return 4,fixed32_unpack(buf)
}

pub fn unpack_32bit_field_packed(buf []u8, wire_type WireType) ?(int,[]u32) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return fixed32_unpack_packed(buf)
}

pub fn unpack_64bit_field(buf []u8, wire_type WireType) ?(int,u64) {
	ensure_wiretype(wire_type, ._64bit)?
	return 8,fixed64_unpack(buf)
}

pub fn unpack_64bit_field_packed(buf []u8, wire_type WireType) ?(int,[]u64) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return fixed64_unpack_packed(buf)
}

pub fn unpack_s32bit_field(buf []u8, wire_type WireType) ?(int,int) {
	ensure_wiretype(wire_type, ._32bit)?
	v := fixed32_unpack(buf)
	return 4,*(&int(&v))
}

pub fn unpack_s64bit_field(buf []u8, wire_type WireType) ?(int,i64) {
	ensure_wiretype(wire_type, ._64bit)?
	v := fixed64_unpack(buf)
	return 8,*(&i64(&v))
}

pub fn unpack_float_field(buf []u8, wire_type WireType) ?(int,f32) {
	_, v := unpack_32bit_field(buf, wire_type)?
	return 4,*(&f32(&v))
}

pub fn unpack_double_field(buf []u8, wire_type WireType) ?(int,f64) {
	_, v := unpack_64bit_field(buf, wire_type)?
	return 8,*(&f64(&v))
}

pub fn unpack_bool_field(buf []u8, wire_type WireType) ?(int,bool) {
	ensure_wiretype(wire_type, .varint)?
	i,v := uint32_unpack(buf)
	return i,v != 0
}

pub fn unpack_string_field(buf []u8, wire_type WireType) ?(int,string) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return string_unpack(buf)
}

pub fn unpack_bytes_field(buf []u8, wire_type WireType) ?(int,[]u8) {
	ensure_wiretype(wire_type, .length_prefixed)?
	return bytes_unpack(buf)
}

pub fn unpack_message_field(buf []u8, wire_type WireType) ?(int,[]u8) {
	return unpack_bytes_field(buf, wire_type)
}

// When unpacking this is used when we find a field where we dont
// recognise the number
pub struct UnknownField {
pub:
	wire WireType
	number u32
	data []u8
}

pub fn unpack_unknown_field(buf []u8, wire_type WireType) (int, []u8) {
	match wire_type {
		.length_prefixed {
			return bytes_unpack(buf)
		}

		.varint {
			_, v := uint64_unpack(buf)
			b := uint64_pack(v)
			return b.len, b
		}

		._32bit {
			return 4, buf[..4]
		}

		._64bit {
			return 8, buf[..8]
		}
	}
}
