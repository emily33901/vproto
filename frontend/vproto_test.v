module main

import vproto_test

fn basic() ? {
	mut x := vproto_test.Person{}
	x.name = 'Human person'	
	x.id = 100
	x.email = 'humanperson@humanpeople.org'

	mut y := vproto_test.Person{
		name: 'Human person'
		id: 100
		email: 'humanperson@humanpeople.org'
	}

	// TODO compare when im not lazy
	return
}

fn map_fields() ? {
	mut x := vproto_test.TestMapFields{}
	x.map1['wow'] = 10
	x.map1['nice'] = 30
	x.map1['protobuf'] = 20

	x.complexmap['wow'] = x

	packed := x.pack()

	unpacked := vproto_test.testmapfields_unpack(packed)?

	for k, v in x.map1 {
		assert unpacked.map1[k] == v
	}

	for k, v in x.complexmap {
		for k2, v2 in unpacked.complexmap[k].map1 {
			assert x.map1[k2] == v2
		}
	}

	return
}

fn test_vproto() ? {
	basic()?
	map_fields()?

	return 
}
