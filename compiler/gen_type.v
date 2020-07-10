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

fn to_v_message_name(pkg_prefix string, context []string, name string) string {
	mut struct_name := ''
	
	for _, part in context {
		if part == '' {
			continue
		}

		struct_name += to_v_struct_name(part)
	}

	struct_name += to_v_struct_name(name)

	// TODO when this limitation is removed also do so here!

	struct_name = struct_name.replace_each(['.', ''])

	return pkg_prefix + struct_name
}

enum TypeType {
	message enum_ scalar other
}

fn escape_name(name string) string {
	mut new_name := name.replace_each(['__', '_'])
	return new_name.to_lower()
}

fn escape_keyword(name string) string {
	if name in keywords_v {
		return '@' + name
	}

	return name
}

// TODO this is still misleading
// really this should be something about resolving a type
// and then simplifiying it down which is what this function
// actually does.
fn type_to_typename(current_package string, type_table &TypeTable, context []string, t string) (string, TypeType) {
	if t in valid_types {
		idx := valid_types.index(t)
		return valid_types_v[idx], if idx <= type_max_scalar_index {
			TypeType.scalar
		} else { 
			TypeType.other 
		}
	}

	if found := type_table.lookup_type(context, t) {
		typ := found.t

		pkg_prefix := if typ.package == current_package { '' } else { typ.package.all_after_last('.') + '.' }
		
		type_type := if typ.is_enum { TypeType.enum_ } else { TypeType.message }

		fname := typ.name

		if fname.starts_with('.$current_package') {
			return to_v_message_name(pkg_prefix, typ.context_no_pkg, fname['.$current_package'.len..]), type_type
		}

		if fname[0] == `.` {
			return to_v_message_name(pkg_prefix, typ.context_no_pkg, fname[1..]), type_type
		}

		return to_v_message_name(pkg_prefix, typ.context_no_pkg, fname), type_type
	} 
	
	// By this point in the compiler we should know all the types
	// otherwise we shouldnt be trying to generate code for them!

	panic('Unknown type `$t`\ntable was:\n${type_table}')
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

fn message_names(current_package string, tt &TypeTable, type_context []string, name string) MessageNames {
	mut this_type_context := type_context.clone()
	this_type_context << name

	real_type, _ := type_to_typename(current_package, tt, type_context, name)

	return MessageNames {
		struct_name: real_type,
		lowercase_name: real_type.to_lower()
		this_type_context: this_type_context
	}
}