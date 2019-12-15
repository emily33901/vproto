module vproto

// Helper functions for serialization
// Most of these are adapted from the protobuf-c project
// Original comments have been left intact

/**
 * Return the number of bytes required to store the tag for the field. Includes
 * 3 bits for the wire-type, and a single bit that denotes the end-of-tag.
 *
 * \param number
 *      Field tag to encode.
 * \return
 *      Number of bytes required.
 */
fn get_tag_size(number i64) u32
{
	if (number < (1 << 4)) {
		return 1
	} else if (number < (1 << 11)) {
		return 2
	} else if (number < (1 << 18)) {
		return 3
	} else if (number < (1 << 25)) {
		return 4
	} else {
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
fn uint32_size(v u32) u32
{
	if (v < (1 << 7)) {
		return 1
	} else if (v < (1 << 14)) {
		return 2
	} else if (v < (1 << 21)) {
		return 3
	} else if (v < (1 << 28)) {
		return 4
	} else {
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
fn int32_size(v int) u32
{
	if (v < 0) {
		return 10
	} else if (v < (1 << 7)) {
		return 1
	} else if (v < (1 << 14)) {
		return 2
	} else if (v < (1 << 21)) {
		return 3
	} else if (v < (1 << 28)) {
		return 4
	} else {
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
fn zigzag32(v int) u32
{
	if (v < 0) {
		return (-u32(v)) * 2 - 1
	} else {
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
fn sint32_size(v int) u32
{
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
fn uint64_size(v u64) u32
{
	upper_v := u32(v >> 32)

	if (upper_v == 0) {
		return uint32_size(u32(v))
	} else if (upper_v < (1 << 3)) {
		return 5
	} else if (upper_v < (1 << 10)) {
		return 6
	} else if (upper_v < (1 << 17)) {
		return 7
	} else if (upper_v < (1 << 24)) {
		return 8
	} else if (upper_v < (1 << 31)) {
		return 9
	} else {
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
fn zigzag64(v i64) u64
{
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
fn sint64_size(v i64) u32
{
	return uint64_size(zigzag64(v))
}

/**
 * Calculate the serialized size of a single required message field, including
 * the space needed by the preceding tag.
 *
 * \param field
 *      Field descriptor for member.
 * \param member
 *      Field to encode.
 * \return
 *      Number of bytes required.
 */
fn required_field_get_packed_size(field &RuntimeField, member voidptr) u32 {
	rv := get_tag_size(field.number)

	return rv + match field.typ {
		.sint32 {
			sint32_size(*(&int(member))) 
		}

		.enum_, .int32 {
			int32_size(*(&int(member)))
		}

		.uint32 {
			uint32_size(*(&u32(member)))
		}

		.sint64 {
			sint64_size(*(&i64(member)))
		}

		.uint64, .int64 {
			uint64_size(*(&u64(member)))
		}

		.sfixed32, .fixed32 {
			4
		}

		.sfixed64, .fixed64 {
			8
		}

		.bool_ {
			1
		}

		.float {
			4
		}

		.double {
			8
		}

		.string_ {
			// str := *(&string(member))
			// uint32_size(str.len) + str.len
			0
		}

		.bytes {
			// TODO when Bytes{} is an actual thing
			0
		}

		.message {
			// msg := *(&RuntimeMessage(member))
			// size := message_get_packed_size(msg)
			// uint32_size(size) + size
			0
		}

		else {
			0
		}
	}
}
