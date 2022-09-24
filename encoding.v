module vproto

// Helper functions for serialization
// Most of these are adapted from the protobuf-c project
// Some original comments have been left intact
const (
	protobuf_number_max = (2 ^ 29) - 1
)

fn zigzag32(v int) u32 {
	if v < 0 {
		return (-u32(v)) * 2 - 1
	}
	else {
		return u32(v) * 2
	}
}

/**
 * Return the ZigZag-encoded 64-bit unsigned integer form of a 64-bit signed
 * integer.
 *
 * \param v
 *      Value to encode.
 * \return
 *      ZigZag encoded integer.
 */


fn zigzag64(v i64) u64 {
	if v < 0 {
		return (-u64(v)) * 2 - 1
	}
	else {
		return u64(v) * 2
	}
}

fn int32_pack(value int) []u8 {
	if value < 0 {
		return [u8(value) | 0x80,
		u8(value>>7) | 0x80,
		u8(value>>14) | 0x80,
		u8(value>>21) | 0x80,
		u8(value>>28) | 0x80,
		0xff,
		0xff,
		0xff,
		0x01,
		]
	}
	else {
		return uint32_pack(u32(value))
	}
}

fn int32_packed_pack(values []int) []u8 {
	mut packed := []u8{}

	for v in values {
		packed << int32_pack(v)
	}

	return bytes_pack(packed)
}

fn uint32_packed_pack(values []u32) []u8 {
	mut packed := []u8{}

	for v in values {
		packed << uint32_pack(v)
	}

	return bytes_pack(packed)
}

fn uint64_packed_pack(values []u64) []u8 {
	mut packed := []u8{}

	for v in values {
		packed << uint64_pack(v)
	}

	return bytes_pack(packed)
}

/**
 * Pack an unsigned 32-bit integer in base-128 varint encoding and return the
 * number of bytes written, which must be 5 or less.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn uint32_pack(v u32) []u8 {
	mut res := []u8{}
	mut value := v
	if value >= 0x80 {
		res << u8(value | 0x80)
		value >>= 7
		if value >= 0x80 {
			res << u8(value | 0x80)
			value >>= 7
			if value >= 0x80 {
				res << u8(value | 0x80)
				value >>= 7
				if value >= 0x80 {
					res << u8(value | 0x80)
					value >>= 7
				}
			}
		}
	}
	res << u8(value)
	return res
}

/**
 * Pack a signed 32-bit integer using ZigZag encoding and return the number of
 * bytes written.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn sint32_pack(value int) []u8 {
	return uint32_pack(zigzag32(value))
}

/**
 * Pack a 64-bit unsigned integer using base-128 varint encoding and return the
 * number of bytes written.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn uint64_pack(value u64) []u8 {
	mut hi := u32(value>>32)
	lo := *(&u32(&value))
	mut res := []u8{}
	if hi == 0 {
		return uint32_pack(lo)
	}
	res << u8((lo)) | 0x80
	res << u8((lo>>7)) | 0x80
	res << u8((lo>>14)) | 0x80
	res << u8((lo>>21)) | 0x80
	if hi < 8 {
		res << u8((hi<<4) | (lo>>28))
		return res
	}
	else {
		res << u8(((hi & 7)<<4) | (lo>>28)) | 0x80
		hi >>= 3
	}
	for hi >= 128 {
		res << u8(hi) | 0x80
		hi >>= 7
	}
	res << u8(hi)
	return res
}

/**
 * Pack a 64-bit signed integer in ZigZag encoding and return the number of
 * bytes written.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn sint64_pack(value i64) []u8 {
	return uint64_pack(zigzag64(value))
}

/**
 * Pack a 32-bit quantity in little-endian byte order. Used for protobuf wire
 * types fixed32, sfixed32, float. Similar to "htole32".
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn fixed32_pack(value u32) []u8 {
	v := []u8{len: 4}
	unsafe {
		C.memcpy(v.data, &value, 4)
	}
	return v
}

fn fixed32_packed_pack(values []u32) []u8 {
	v := []u8 {len: values.len * 4}
	unsafe {
		C.memcpy(v.data, values.data, v.len)
	}
	return v
}

/**
 * Pack a 64-bit quantity in little-endian byte order. Used for protobuf wire
 * types fixed64, sfixed64, double. Similar to "htole64".
 *
 * \todo The big-endian impl is really only good for 32-bit machines, a 64-bit
 * version would be appreciated, plus a way to decide to use 64-bit math where
 * convenient.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn fixed64_pack(value u64) []u8 {
	v := []u8{len: 8}
	unsafe {
		C.memcpy(&v[0], &value, 8)
	}
	return v
}

fn fixed64_packed_pack(values []u64) []u8 {
	v := []u8{len: 8 * values.len}
	unsafe {
		C.memcpy(v.data, values.data, v.len)
	}
	return v
}

/**
 * Pack a boolean value as an integer and return the number of bytes written.
 *
 * \todo Perhaps on some platforms *out = !!value would be a better impl, b/c
 * that is idiomatic C++ in some STL implementations.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn boolean_pack(value bool) []u8 {
	if value {
		return [u8(1)]
	}
	else {
		return [u8(0)]
	}
}

/**
 * Pack a NUL-terminated C string and return the number of bytes written. The
 * output includes a length delimiter.
 *
 * The NULL pointer is treated as an empty string. This isn't really necessary,
 * but it allows people to leave required strings blank. (See Issue #13 in the
 * bug tracker for a little more explanation).
 *
 * \param str
 *      String to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn string_pack(str string) []u8 {
	mut out := []u8{}
	if str == '' {
		out << 0
		return out
	}
	else {
		out << uint32_pack(u32(str.len))
		for _, b in str {
			out << b
		}
		return out
	}
}

/**
 * Pack a field tag.
 *
 * Wire-type will be added in required_field_pack().
 *
 * \todo Just call uint64_pack on 64-bit platforms.
 *
 * \param id
 *      Tag value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn tag_pack(id u32) []u8 {
	if id < (1<<(32 - 3)) {
		return uint32_pack(id<<3)
	}
	else {
		return uint64_pack(u64(id)<<3)
	}
}

fn bytes_pack(buf []u8) []u8 {
	mut ret := uint32_pack(u32(buf.len))
	ret << buf
	return ret
}

fn uint32_unpack(buf []u8) (int,u32) {
	mut i := 0
	mut ret := u32(buf[0] & 0x7f)
	if buf[0] & 0x80 == 0x80 {
		ret |= u32(buf[1] & 0x7f)<<7
		if buf[1] & 0x80 == 0x80 {
			ret |= u32(buf[2] & 0x7f)<<14
			if buf[2] & 0x80 == 0x80 {
				ret |= u32(buf[3] & 0x7f)<<21
				if buf[3] & 0x80 == 0x80 {
					ret |= u32(buf[4] & 0x7f)<<28
					i++
				}
				i++
			}
			i++
		}
		i++
	}
	i++
	return i,ret
}

fn int32_unpack(buf []u8) (int,int) {
	// NOTE: negative int32 values are stored as a
	// twos compliment 64bit integer!
	// So make sure we get all those tasty bits!
	i, v := uint64_unpack(buf)
	return i,int(v)
}

fn int32_unpack_packed(buf []u8) (int, []int) {
	i, bytes := bytes_unpack(buf)

	mut ret := []int{}

	for j := 0; j < bytes.len; {
		consumed, value := int32_unpack(bytes[j..])
		j += consumed
		ret << value
	}

	return i, ret
}

fn uint32_unpack_packed(buf []u8) (int, []u32) {
	i, bytes := bytes_unpack(buf)

	mut ret := []u32{}

	for j := 0; j < bytes.len; {
		consumed, value := uint32_unpack(bytes[j..])
		j += consumed
		ret << value
	}

	return i, ret
}

fn uint64_unpack_packed(buf []u8) (int, []u64) {
	i, bytes := bytes_unpack(buf)

	mut ret := []u64{}

	for j := 0; j < bytes.len; {
		consumed, value := uint64_unpack(bytes[j..])
		j += consumed
		ret << value
	}

	return i, ret
}

fn unzigzag32(v u32) int {
	if v & 1 == 1 {
		return int(-(v>>1) - 1)
	}
	else {
		return int(v>>1)
	}
}

fn fixed32_unpack(buf []u8) u32 {
	v := u32(0)
	unsafe {
		C.memcpy(&v, &buf[0], 4)
	}
	return v
}

fn fixed32_unpack_packed(buf []u8) (int, []u32) {
	i, bytes := bytes_unpack(buf)

	len := bytes.len / 4
	
	ret := []u32{len: len}
	unsafe {
		C.memcpy(&ret.data, bytes.data, len)
	}
	
	return i, ret
}

fn fixed64_unpack(buf []u8) u64 {
	v := u64(0)
	unsafe {
		C.memcpy(&v, &buf[0], 8)
	}
	return v
}

fn fixed64_unpack_packed(buf []u8) (int, []u64) {
	i, bytes := bytes_unpack(buf)

	len := bytes.len / 8
	
	ret := []u64{len: len}
	unsafe {
		C.memcpy(&ret.data, bytes.data, len)
	}
	return i, ret
}

fn uint64_unpack(buf []u8) (int,u64) {
	mut res := u64(buf[0] & 0x7f)

	mut i := 1
	for i = 1; (buf[i-1] & 0x80) == 0x80; i++ {
		res |= u64(buf[i] & 0x7f)<<(i * 7)
	}
	return i,res
}

fn unzigzag64(v u64) i64 {
	if v & 1 == 1 {
		return i64(-(v>>1) - 1)
	}
	return i64(v>>1)
}

fn string_unpack(buf []u8) (int,string) {
	size_len, str_len := uint32_unpack(buf)
	if str_len == 0 {
		return size_len, ''
	}
	// Clone here to make sure the string is 0 terminated
	return int(str_len) + size_len, tos(&buf[size_len], int(str_len)).clone()
}

fn bytes_unpack(buf []u8) (int,[]u8) {
	size_len, bytes_len := uint32_unpack(buf)
	return int(bytes_len) + size_len, buf[size_len..(int(bytes_len)+size_len)].clone()
}
