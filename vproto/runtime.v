module vproto

pub struct Bytes {
	// TODO
}

interface Messageer {
	serialize_to_array() ?[]byte
	parse_from_array(data []byte) bool
}