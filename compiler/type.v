module compiler

pub struct Type {
	name string
	full_name string // Full canonicalised name
	full_name_no_pkg string
	context []string // context for this type
	context_no_pkg []string
	package string

	// Only one of these should be set
	is_enum bool
	is_message bool

	file &File [skip] // where this type is from
}

pub fn new_type(context []string, name string, is_enum, is_message bool, file &File) &Type {
	mut full_name_pieces := []string{}
	mut context_no_pkg := []string{}
	// TODO cleanup when vlang #5041 is fixed

	if context.len != 0 {

		// no package?
		if context[0].len == 0 {
			if context.len > 1 {
				fnp := context[1..]
				full_name_pieces = fnp.clone()
			}
		} else {
			full_name_pieces = context.clone()
		}
		context_no_pkg = context.join('.').replace(file.package, '').split('.')
	}

	full_name_pieces << name

	full_name := 
		'.' + full_name_pieces.join('.')

	full_name_no_pkg := context_no_pkg.join('.') + '.$name'

	assert (is_enum || is_message) && !(is_enum && is_message)

	return &Type{name, 
		full_name,
		full_name_no_pkg, 
		context.clone(), 
		context_no_pkg,
		file.package
		is_enum, 
		is_message, 
		file}
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

pub fn (mut table  TypeTable) add_message(t &Type, m &Message) {
	// TODO make sure that type isnt already in table
	table.table[t.full_name] = t
	table.messages[t.full_name] = m
}

pub fn (mut table  TypeTable) add_enum(t &Type, e &Enum) {
	// TODO make sure that type isnt already in table
	table.table[t.full_name] = t
	table.enums[t.full_name] = e
}

pub struct FoundType {
	t &Type

	// Context that this type was found in
	// this is needed to rebuild the typename later in gen
	context []string
}

pub fn (t &TypeTable) lookup_type(ctx []string, name string) ?FoundType {
	// There are a few things we can try here

	mut context := []string{}

	// remove anything blank from the start of context
	for x in ctx {
		if x != '' {
			context << x 
		}
	}

	// '$name' '.$name'
	// '.${context.last...}.$name'

	if name in t.table {
		return FoundType{
			t: t.table[name],
			context: context
		}
	}

	if '.$name' in t.table {
		return FoundType{
			t: t.table['.$name'],
			context: context
		}
	}

	for i := context.len; i >= 0; i-- {
		context_full := context[..i].join('.')
		full_name := '.${context_full}.$name'

		if full_name in t.table {
			return FoundType{
				t: t.table[full_name],
				context: context_full.split('.')
			}
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
	if found := t.lookup_type(context, name) {
		return t.messages[found.t.full_name]
	}

	return none
}

// simplify context one by removing context2
pub fn simplify_type_context(context1, context2 []string) []string {
	scontext1 := context1.join('.')
	scontext2 := context2.join('.')

	return scontext1.replace(scontext2, '').split('.')
}