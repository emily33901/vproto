module vproto

// Needed for putting an interface into a struct
fn as_runtime_valuer(v RuntimeValuer) RuntimeValuer {
	return v
}

fn runtime_valuer(v RuntimeValuer, expected FieldType) {
	t := v.typ()
	assert t == expected
}

fn test_cast_to_opts() {
	runtime_valuer(default_int32, .int32)
	runtime_valuer(default_int64, .int64)

	runtime_valuer(default_uint32, .uint32)
	runtime_valuer(default_uint64, .uint64)

	runtime_valuer(default_sint32, .sint32)
	runtime_valuer(default_sint64, .sint64)

	runtime_valuer(default_fixed32, .fixed32)
	runtime_valuer(default_fixed64, .fixed64)

	runtime_valuer(default_sfixed32, .sfixed32)
	runtime_valuer(default_sfixed64, .sfixed64)

	runtime_valuer(default_float, .float)
	runtime_valuer(default_double, .double)

	runtime_valuer(default_bool, .bool_)
	runtime_valuer(default_string, .string_)
	runtime_valuer(default_bytes, .bytes)

	// Temporary
	// nothing should refer to this and each message
	// should have their own default state
	runtime_valuer(default_default_message, .message)
	runtime_valuer(default_default_enum, .enum_)

	// TODO move back to being const fields when that works again

	test_double := vproto.FieldDescriptor{
		typ_str: 'test_double',
		typ_str_v: 'double',
		typ: FieldType.double,
		name: 'double',
		name_v: 'double',
		number: 1,
		default_value: as_runtime_valuer(default_double)
	}
	test_float := vproto.FieldDescriptor{
		typ_str: 'test_float',
		typ_str_v: 'float',
		typ: FieldType.float,
		name: 'float',
		name_v: 'float',
		number: 1,
		default_value: as_runtime_valuer(default_float),
	}
	test_int32 := vproto.FieldDescriptor{
		typ_str: 'test_int32',
		typ_str_v: 'int32',
		typ: FieldType.int32,
		name: 'int32',
		name_v: 'int32',
		number: 1,
		default_value: as_runtime_valuer(default_int32),
	}
	test_int64 := vproto.FieldDescriptor{
		typ_str: 'test_int64',
		typ_str_v: 'int64',
		typ: FieldType.int64,
		name: 'int64',
		name_v: 'int64',
		number: 1,
		default_value: as_runtime_valuer(default_int64),
	}
	test_uint32 := vproto.FieldDescriptor{
		typ_str: 'test_uint32',
		typ_str_v: 'uint32',
		typ: FieldType.uint32,
		name: 'uint32',
		name_v: 'uint32',
		number: 1,
		default_value: as_runtime_valuer(default_uint32),
	} 
	test_uint64 := vproto.FieldDescriptor{
		typ_str: 'test_uint64',
		typ_str_v: 'uint64',
		typ: FieldType.uint64,
		name: 'uint64',
		name_v: 'uint64',
		number: 1,
		default_value: as_runtime_valuer(default_uint64),
	}
	test_sint32 := vproto.FieldDescriptor{
		typ_str: 'test_sint32',
		typ_str_v: 'sint32',
		typ: FieldType.sint32,
		name: 'sint32',
		name_v: 'sint32',
		number: 1,
		default_value: as_runtime_valuer(default_sint32),
	} 
	test_sint64 := vproto.FieldDescriptor{
		typ_str: 'test_sint64',
		typ_str_v: 'sint64',
		typ: FieldType.sint64,
		name: 'sint64',
		name_v: 'sint64',
		number: 1,
		default_value: as_runtime_valuer(default_sint64),
	}
	test_fixed32 := vproto.FieldDescriptor{
		typ_str: 'test_fixed32',
		typ_str_v: 'fixed32',
		typ: FieldType.fixed32,
		name: 'fixed32',
		name_v: 'fixed32',
		number: 1,
		default_value: as_runtime_valuer(default_fixed32),
	} 
	test_fixed64 := vproto.FieldDescriptor{
		typ_str: 'test_fixed64',
		typ_str_v: 'fixed64',
		typ: FieldType.fixed64,
		name: 'fixed64',
		name_v: 'fixed64',
		number: 1,
		default_value: as_runtime_valuer(default_fixed64),
	}
	test_sfixed32 : vproto.FieldDescriptor{
		typ_str: 'test_sfixed32',
		typ_str_v: 'sfixed32',
		typ: FieldType.sfixed32,
		name: 'sfixed32',
		name_v: 'sfixed32',
		number: 1,
		default_value: as_runtime_valuer(default_sfixed32),
	} 
	test_sfixed64 : vproto.FieldDescriptor{
		typ_str: 'test_sfixed64',
		typ_str_v: 'sfixed64',
		typ: FieldType.sfixed64,
		name: 'sfixed64',
		name_v: 'sfixed64',
		number: 1,
		default_value: as_runtime_valuer(default_sfixed64),
	}
	test_bool := vproto.FieldDescriptor{
		typ_str: 'test_bool',
		typ_str_v: 'bool_',
		typ: FieldType.bool_,
		name: 'bool_',
		name_v: 'bool_',
		number: 1,
		default_value: as_runtime_valuer(default_bool),
	}
	test_string := vproto.FieldDescriptor{
		typ_str: 'test_string',
		typ_str_v: 'string_',
		typ: FieldType.string_,
		name: 'string_',
		name_v: 'string_',
		number: 1,
		default_value: as_runtime_valuer(default_string),
	} 
	test_bytes := vproto.FieldDescriptor{
		typ_str: 'test_bytes',
		typ_str_v: 'bytes',
		typ: FieldType.bytes,
		name: 'bytes',
		name_v: 'bytes',
		number: 1,
		default_value: as_runtime_valuer(default_bytes),
	}
	test_message := vproto.FieldDescriptor{
		typ_str: 'test_message',
		typ_str_v: 'message',
		typ: FieldType.message,
		name: 'message',
		name_v: 'message',
		number: 1,
		default_value: as_runtime_valuer(default_default_message),
	}
	test_enum := vproto.FieldDescriptor{
		typ_str: 'test_enum',
		typ_str_v: 'enum_',
		typ: FieldType.enum_,
		name: 'enum_',
		name_v: 'enum_',
		number: 1,
		default_value: as_runtime_valuer(default_default_enum),
	}

	// TODO test these with the value above eventually

	assert default_int32.str() == '0'
	assert default_int64.str() == '0'
	assert default_sint32.str() == '0'
	assert default_sint64.str() == '0'
	assert default_fixed32.str() == '0'
	assert default_fixed64.str() == '0'
	assert default_sfixed32.str() == '0'
	assert default_sfixed64.str() == '0'
	assert default_double.str() == '0.000000'
	assert default_float.str() == '0.000000'
	assert default_bool.str() == '0' // 'false' when alex fixes it
	assert default_string.str() == ''
	assert default_bytes.str() == ' '
	assert default_default_message.str() == '{ TODO }'
	assert default_default_enum.str() == '0'
}

// const (
// 	test_double =	vproto.FieldDescriptor{'test_double', 'double', FieldType.double, 'double', 'double', 1, default_double},
// 	test_float =	vproto.FieldDescriptor{'test_float', 'float', .float, 'float', 'float', 1, default_float},
// 	test_int32 =	vproto.FieldDescriptor{'test_int32', 'int32', .int32, 'int32', 'int32', 1, default_int32},
// 	test_int64 =	vproto.FieldDescriptor{'test_int64', 'int64', .int64, 'int64', 'int64', 1, default_int64},
// 	test_uint32 =	vproto.FieldDescriptor{'test_uint32', 'uint32', .uint32, 'uint32', 'uint32', 1, default_uint32}, 
// 	test_uint64 =	vproto.FieldDescriptor{'test_uint64', 'uint64', .uint64, 'uint64', 'uint64', 1, default_uint64},
// 	test_sint32 =	vproto.FieldDescriptor{'test_sint32', 'sint32', .sint32, 'sint32', 'sint32', 1, default_sint32}, 
// 	test_sint64 =	vproto.FieldDescriptor{'test_sint64', 'sint64', .sint64, 'sint64', 'sint64', 1, default_sint64},
// 	test_fixed32 =	vproto.FieldDescriptor{'test_fixed32', 'fixed32', .fixed32, 'fixed32', 'fixed32', 1, default_fixed32}, 
// 	test_fixed64 =	vproto.FieldDescriptor{'test_fixed64', 'fixed64', .fixed64, 'fixed64', 'fixed64', 1, default_fixed64},
// 	test_sfixed32 =	vproto.FieldDescriptor{'test_sfixed32', 'sfixed32', .sfixed32, 'sfixed32', 'sfixed32', 1, default_sfixed32}, 
// 	test_sfixed64 =	vproto.FieldDescriptor{'test_sfixed64', 'sfixed64', .sfixed64, 'sfixed64', 'sfixed64', 1, default_sfixed64},
// 	test_bool =		vproto.FieldDescriptor{'test_bool', 'bool_', .bool_, 'bool_', 'bool_', 1, default_bool}, 
// 	test_string =	vproto.FieldDescriptor{'test_string', 'string_', .string_, 'string_', 'string_', 1, default_string}, 
// 	test_bytes =	vproto.FieldDescriptor{'test_bytes', 'bytes', .bytes, 'bytes', 'bytes', 1, default_bytes},
// 	test_message =	vproto.FieldDescriptor{'test_message', 'message', .message, 'message', 'message', 1, default_default_message},
// 	test_enum =		vproto.FieldDescriptor{'test_enum', 'enum_', .enum_, 'enum_', 'enum_', 1, default_default_enum_}
// )