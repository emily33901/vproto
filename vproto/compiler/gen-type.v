module compiler

fn to_v_field_name(name string) string {
	return name.to_lower()
}

fn to_v_struct_name(name string) string {
	mut new_name := name[0].str().to_upper() + name[1..]
	new_name = new_name.replace_each(['_', '', '.', ''])

	// Get around the capital letters limitations
	mut was_cap := 0
	for i, c in new_name {
		if c >= `A` && c <= `Z` {
			if was_cap > 1 {
				new_name = new_name[..i] + c.str().to_lower() + new_name[i+1..]
			} else {
				was_cap++
			}
		} else {
			was_cap = 0
		}
	}

	return new_name
}

fn to_v_message_name(context []string, name string) string {
	mut struct_name := ''
	
	for _, part in context {
		struct_name += to_v_struct_name(part)
	}

	struct_name += to_v_struct_name(name)

	// TODO when this limitation is removed also do so here!

	struct_name = struct_name.replace_each(['.', ''])

	return struct_name
}

pub enum type_type {
	message enum_ other
}

// Returns all the names that are needed from a type
struct TypeNames {
	// Whether this is an enum message or other
	tt type_type

	// For use in types
	// e.g. TestEnum or TestMessageInnerTestMessage
	type_name string

	// For use in fields
	// e.g. pack_testmessage
	field_name string
}

fn type_to_names(t &Type) TypeNames {
	return TypeNames{
		type_name: to_v_message_name(t.context_no_pkg, t.name)
	}
}

fn enum_to_names(e &Enum) TypeNames {
	return type_to_names(e.typ)
}

fn message_to_names(m &Message) TypeNames {
	return type_to_names(m.typ)
}

fn escape_name(name string) string {
	if name in keywords_v {
		return name + '_'
	}

	new_name := name.replace_each(['__', '_'])

	return new_name
}

// TODO come up with a better name for this
fn type_to_type(current_package string, type_table &TypeTable, context []string, t string) (string, type_type) {
	if t in valid_types {
		return valid_types_v[valid_types.index(t)], type_type.other
	}

	if typ := type_table.lookup_type(context, t) {
		type_type := if typ.is_enum { type_type.enum_ } else { type_type.message }

		fname := typ.full_name

		if fname.starts_with('.$current_package') {
			return to_v_message_name([], typ.full_name['.$current_package'.len..]), type_type
		}

		if typ.full_name[0] == `.` {
			return to_v_message_name([], typ.full_name[1..]), type_type
		}

		return to_v_message_name([], typ.full_name), type_type
	}

	// By this point in the compiler we should know all the types
	// otherwise we shouldnt be trying to generate code for them!

	panic('Unknown type `$t`\ntable was:\n${type_table.str()}')
}

struct MessageNames {
	// Used for the struct itself
	struct_name string

	// used for fields or metadata that refer
	// to this message
	lowercase_name string

	// Type context for submessages
	this_type_context []string
}

fn message_names(type_context []string, name string) MessageNames {
	mut this_type_context := type_context.clone()
	this_type_context << name

	return MessageNames {
		struct_name: to_v_message_name(type_context, name),
		lowercase_name: (type_context.join('') + name).to_lower().replace_each(['.', ''])
		this_type_context: this_type_context
	}
}