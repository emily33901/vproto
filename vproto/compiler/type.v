module compiler

pub struct Type {
	name string
	full_name string // Full canonicalised name
	full_name_no_pkg string
	context []string // context for this type
	context_no_pkg []string

	// Only one of these should be set
	is_enum bool
	is_message bool

	file &File [skip] // where this type is from
}

pub fn new_type(context []string, name string, is_enum, is_message bool, file &File) &Type {
	mut full_name_pieces := []string

	mut context_no_pkg := []string

	// no package?
	if context[0].len == 0 {
		if context.len > 1 {
			full_name_pieces = context[1..].clone()
			context_no_pkg = full_name_pieces.clone()
		}
	} else {
		full_name_pieces = context.clone()

		context_no_pkg = context[1..].clone()
	}

	full_name_pieces << name

	full_name := 
		'.' + full_name_pieces.join('.')

	full_name_no_pkg := context_no_pkg.join('.') + '.$name'

	assert (is_enum || is_message) && !(is_enum && is_message)

	return &Type{name, full_name, full_name_no_pkg, context.clone(), context_no_pkg, is_enum, is_message, file}
}

pub struct TypeTable {
mut:
	// Maps *canonicalised full names* to their type
	// e.g. `.Wow.Nice`
	table map[string]&Type

	messages map[string]&Message
	enums map [string]&Enum
}

pub fn (t TypeTable) str() string {
	mut ret := ''
	for k, v in t.table {
		typ := if v.is_message { 'message' } else if v.is_enum { 'enum' } else { 'unknown?' }
		ret = '$ret\n$k = $v.full_name $typ'
	}

	return ret
}

pub fn (table mut TypeTable) add_message(t &Type, m &Message) {
	// TODO make sure that type isnt already in table
	table.table[t.full_name] = t
	table.messages[t.full_name] = m
}

pub fn (table mut TypeTable) add_enum(t &Type, e &Enum) {
	// TODO make sure that type isnt already in table
	table.table[t.full_name] = t
	table.enums[t.full_name] = e
}

pub fn (t &TypeTable) lookup_type(context []string, name string) ?&Type {
	// There are a few things we can try here

	// '$name' '.$name'
	// '.${context.last...}.$name'

	if name in t.table {
		return t.table[name]
	}

	if '.$name' in t.table {
		return t.table['.$name']
	}

	for i := context.len; i >= 0; i-- {
		context_full := context[..i].join('.')
		full_name := '.${context_full}.$name'

		if full_name in t.table {
			return t.table[full_name]
		}
	}

	return none
}

struct LookupMessage {
	typ &Type
	message &Message
}

// TODO return LookupMessage

pub fn (t &TypeTable) lookup_message(context []string, name string) ?&Message {
	if typ := t.lookup_type(context, name) {
		return t.messages[typ.full_name]
	}

	return none
}
