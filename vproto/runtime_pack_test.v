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

	i, v := unpack_int32_field(int_field_packed[t.consumed..], .varint)

	assert v == 100000
	assert i == 3
}