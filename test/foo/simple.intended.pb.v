// package foo;

// enum Test {
//     enabled = 0;
//     disabled = 5;
// }

// message Simple {
//     required int32 id = 1;
//     optional string name = 2;
    
//     repeated int32 other = 3;

//     required Test enum_test = 4;
// }

// Turns into:

module foo

enum Test {
	enabled = 0
	disabled = 5
}

interface Simpleer {
	id() &int

	name() ?string
	set_name(name string)
	clear_name()

	other() []int

	enum_test() &Test
}

struct SimpleImpl {
mut:
	id int
	name string
	has_name bool
	
	other []int

	enum_test Test
}

fn new_simple() &Simpleer {
	return SimpleImpl{}
}

fn (simpleimpl SimpleImpl) id() int {
	return simpleimpl.id
}

fn (simpleimpl SimpleImpl) name() ?string {
	if simpleimpl.has_name {
		return simpleimpl.name
	} else {
		return none
	}
}

fn (simpleimpl mut SimpleImpl) set_name(name string) {
	simpleimpl.has_name = true
	simpleimpl.name = name
}

fn (simpleimpl mut SimpleImpl) clear_name() {
	simpleimpl.has_name = false
}

fn (simpleimpl SimpleImpl) other() []int {
	return simpleimpl.other
}

fn (simpleimpl &SimpleImpl) enum_test() Test {
	return simpleimpl.enum_test
}


// Not generated but used to make sure that this parses
fn main() {
	mut x := new_simple()

	x.id() = 1
	x.set_name('wow nice')

	x.other() = [1, 2, 3, 4]

	x.enum_test() = .disabled
}