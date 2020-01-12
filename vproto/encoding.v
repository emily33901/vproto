module vproto
// Helper functions for serialization
// Most of these are adapted from the protobuf-c project
// Original comments have been left intact
const (
	protobuf_number_max = (2 ^ 29) - 1
)
/**
 * Return the number of bytes required to store the tag for the field. Includes
 * 3 bits for the wire-type, and a single bit that denotes the end-of-tag.
 *
 * \param number
 *      Field tag to encode.
 * \return
 *      Number of bytes required.
 */


fn get_tag_size(number int) u32 {
	if (number < (1<<4)) {
		return 1
	}
	else if (number < (1<<11)) {
		return 2
	}
	else if (number < (1<<18)) {
		return 3
	}
	else if (number < (1<<25)) {
		return 4
	}
	else {
		return 5
	}
}

/**
 * Return the number of bytes required to store a variable-length unsigned
 * 32-bit integer in base-128 varint encoding.
 *
 * \param v
 *      Value to encode.
 * \return
 *      Number of bytes required.
 */


fn uint32_size(v u32) u32 {
	if (v < (1<<7)) {
		return 1
	}
	else if (v < (1<<14)) {
		return 2
	}
	else if (v < (1<<21)) {
		return 3
	}
	else if (v < (1<<28)) {
		return 4
	}
	else {
		return 5
	}
}

/**
 * Return the number of bytes required to store a variable-length signed 32-bit
 * integer in base-128 varint encoding.
 *
 * \param v
 *      Value to encode.
 * \return
 *      Number of bytes required.
 */


fn int32_size(v int) u32 {
	if (v < 0) {
		return 10
	}
	else if (v < (1<<7)) {
		return 1
	}
	else if (v < (1<<14)) {
		return 2
	}
	else if (v < (1<<21)) {
		return 3
	}
	else if (v < (1<<28)) {
		return 4
	}
	else {
		return 5
	}
}

/**
 * Return the ZigZag-encoded 32-bit unsigned integer form of a 32-bit signed
 * integer.
 *
 * \param v
 *      Value to encode.
 * \return
 *      ZigZag encoded integer.
 */


fn zigzag32(v int) u32 {
	if (v < 0) {
		return (-u32(v)) * 2 - 1
	}
	else {
		return u32(v) * 2
	}
}

/**
 * Return the number of bytes required to store a signed 32-bit integer,
 * converted to an unsigned 32-bit integer with ZigZag encoding, using base-128
 * varint encoding.
 *
 * \param v
 *      Value to encode.
 * \return
 *      Number of bytes required.
 */


fn sint32_size(v int) u32 {
	return uint32_size(zigzag32(v))
}

/**
 * Return the number of bytes required to store a 64-bit unsigned integer in
 * base-128 varint encoding.
 *
 * \param v
 *      Value to encode.
 * \return
 *      Number of bytes required.
 */


fn uint64_size(v u64) u32 {
	upper_v := u32(v>>32)
	if (upper_v == 0) {
		return uint32_size(u32(v))
	}
	else if (upper_v < (1<<3)) {
		return 5
	}
	else if (upper_v < (1<<10)) {
		return 6
	}
	else if (upper_v < (1<<17)) {
		return 7
	}
	else if (upper_v < (1<<24)) {
		return 8
	}
	else if (upper_v < (1<<31)) {
		return 9
	}
	else {
		return 10
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
	if (v < 0) {
		return (-u64(v)) * 2 - 1
	}
	else {
		return u64(v) * 2
	}
}

/**
 * Return the number of bytes required to store a signed 64-bit integer,
 * converted to an unsigned 64-bit integer with ZigZag encoding, using base-128
 * varint encoding.
 *
 * \param v
 *      Value to encode.
 * \return
 *      Number of bytes required.
 */


fn sint64_size(v i64) u32 {
	return uint64_size(zigzag64(v))
}

/**
 * Pack a signed 32-bit integer and return the number of bytes written.
 * Negative numbers are encoded as two's complement 64-bit integers.
 *
 * \param value
 *      Value to encode.
 * \param[out] out
 *      Packed value.
 * \return
 *      Number of bytes written to `out`.
 */


fn int32_pack(value int) []byte {
	if (value < 0) {
		return [value | 0x80,
		(value>>7) | 0x80,
		(value>>14) | 0x80,
		(value>>21) | 0x80,
		(value>>28) | 0x80,
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


fn uint32_pack(v u32) []byte {
	mut res := []byte
	mut value := v
	if value >= 0x80 {
		res << value | 0x80
		value >>= 7
		if value >= 0x80 {
			res << value | 0x80
			value >>= 7
			if value >= 0x80 {
				res << value | 0x80
				value >>= 7
				if value >= 0x80 {
					res << value | 0x80
					value >>= 7
				}
			}
		}
	}
	res << value
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


fn sint32_pack(value int) []byte {
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


fn uint64_pack(value u64) []byte {
	mut hi := u32(value>>32)
	lo := *(&u32(&value))
	mut res := []byte
	if hi == 0 {
		return uint32_pack(lo)
	}
	res << (lo) | 0x80
	res << (lo>>7) | 0x80
	res << (lo>>14) | 0x80
	res << (lo>>21) | 0x80
	if hi < 8 {
		res << (hi<<4) | (lo>>28)
		return res
	}
	else {
		res << ((hi & 7)<<4) | (lo>>28) | 0x80
		hi >>= 3
	}
	for hi >= 128 {
		res << hi | 0x80
		hi >>= 7
	}
	res << hi
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


fn sint64_pack(value i64) []byte {
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


fn fixed32_pack(value u32) []byte {
	v := [byte(0), 0, 0, 0]
	C.memcpy(&v[0], &value, 4)
	return v
	// v := *byte(&value)
	// return [ v[0], v[1], v[2], v[3] ]
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


fn fixed64_pack(value u64) []byte {
	v := [byte(0), 0, 0, 0, 0, 0, 0, 0]
	C.memcpy(&v[0], &value, 8)
	return v
	// v := *byte(&value)
	// return [ v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7] ]
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


fn boolean_pack(value bool) []byte {
	if value {
		return [1]
	}
	else {
		return [0]
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


fn string_pack(str string) []byte {
	mut out := []byte
	if (str == '') {
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


fn tag_pack(id u32) []byte {
	if (id < (1<<(32 - 3))) {
		return uint32_pack(id<<3)
	}
	else {
		return uint64_pack(u64(id)<<3)
	}
}

fn bytes_pack(buf []byte) []byte {
	mut ret := uint32_pack(u32(buf.len))
	ret << buf
	return ret
}

fn uint32_unpack(buf []byte) (int,u32) {
	mut i := 0
	mut ret := u32(buf[0] & 0x7f)
	if (buf[0] & 0x80) == 0x80 {
		ret |= u32(buf[1] & 0x7f)<<7
		if (buf[1] & 0x80) == 0x80 {
			ret |= u32(buf[2] & 0x7f)<<14
			if (buf[2] & 0x80) == 0x80 {
				ret |= u32(buf[3] & 0x7f)<<21
				if (buf[3] & 0x80) == 0x80 {
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

fn int32_unpack(buf []byte) (int,int) {
	i,v := uint32_unpack(buf)
	return i,int(v)
}

fn unzigzag32(v u32) int {
	if v & 1 == 1 {
		return int(-(v>>1) - 1)
	}
	else {
		return int(v>>1)
	}
}

fn fixed32_unpack(buf []byte) u32 {
	v := u32(0)
	C.memcpy(&v, &buf[0], 4)
	return v
}

fn fixed64_unpack(buf []byte) u64 {
	v := u64(0)
	C.memcpy(&v, &buf[0], 8)
	return v
}

fn uint64_unpack(buf []byte) (int,u64) {
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

fn string_unpack(buf []byte) (int,string) {
	i,len := uint32_unpack(buf)
	println('$len')
	if len == 0 {
		return i,''
	}
	return i + len, tos(&buf[i], int(len))
}

fn bytes_unpack(buf []byte) (int,[]byte) {
	i,len := uint32_unpack(buf)
	return i + len,buf[i..len + 1].clone()
}
