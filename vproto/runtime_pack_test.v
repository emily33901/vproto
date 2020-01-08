module vproto

fn test_pack_wire_type() {
	w := vproto.WireType._32bit
	tag := u32(40000)
	b := vproto.pack_tag_wire_type(tag, w)
	r := vproto.unpack_tag_wire_type(b) or {
		panic('$err')
	}
	assert r.tag == tag
	assert r.wire_type == w
}

fn test_int32_fields() {
	int_field_packed := pack_int32_field(100000, 100)
	t := unpack_tag_wire_type(int_field_packed) or {
		panic('$err')
	}
	assert t.tag == 100
	assert t.wire_type == .varint
	i,v := unpack_int32_field(int_field_packed[t.consumed..], .varint)
	assert v == 100000
	assert i == 3
}

fn test_sint32_fields() {
	int_field_packed := pack_sint32_field(100000, 100)
	t := unpack_tag_wire_type(int_field_packed) or {
		panic('$err')
	}
	assert t.tag == 100
	assert t.wire_type == .varint
	i,v := unpack_sint32_field(int_field_packed[t.consumed..], .varint)
	assert v == 100000
	assert i == 3
}

fn test_uint64_fields() {
	int_field_packed := pack_uint64_field(100000, 100)
	
	for _, x in int_field_packed {
		print('$x.hex() ')
	}

	println('')
	
	t := unpack_tag_wire_type(int_field_packed) or {
		panic('$err')
	}
	assert t.tag == 100
	assert t.wire_type == .varint
	i,v := unpack_uint64_field(int_field_packed[t.consumed..], .varint)
	println('$i $v')
	assert v == 100000
	assert i == 3
}

// fn test_int64_fields() {
// int_field_packed := pack_int64_field(100000, 100)
// t := unpack_tag_wire_type(int_field_packed) or {
// panic('$err')
// }
// assert t.tag == 100
// assert t.wire_type == .varint
// i, v := unpack_int64_field(int_field_packed[t.consumed..], .varint)
// assert v == 100000
// assert i == 3
// }
// fn test_sint64_fields() {
// int_field_packed := pack_sint64_field(100000, 100)
// t := unpack_tag_wire_type(int_field_packed) or {
// panic('$err')
// }
// assert t.tag == 100
// assert t.wire_type == .varint
// i, v := unpack_sint64_field(int_field_packed[t.consumed..], .varint)
// assert v == 100000
// assert i == 3
// }
fn test_bytes_field() {
	bytes_field_packed := pack_bytes_field([byte(0), 1, 2, 3, 4], 100)
	t := unpack_tag_wire_type(bytes_field_packed) or {
		panic('$err')
	}
	assert t.tag == 100
	assert t.wire_type == .length_prefixed
	consumed,v := unpack_bytes_field(bytes_field_packed[t.consumed..], .length_prefixed)
	assert v.len == 5
	for i := 0; i < 5; i++ {
		assert v[i] == i
	}
	assert consumed == 6
}

fn test_string_field() {
	str := 'Hello, Sailor!'
	string_field_packed := pack_string_field(str, 100)
	t := unpack_tag_wire_type(string_field_packed) or {
		panic('$err')
	}
	assert t.tag == 100
	assert t.wire_type == .length_prefixed
	_,v := unpack_string_field(string_field_packed[t.consumed..], .length_prefixed)
	assert v == str
}
