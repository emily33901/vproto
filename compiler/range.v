module compiler

// Helpers for dealing with ranges
pub struct Range {
	min      i64
	max      i64
	taken_by string
}

pub struct RangeChecker {
mut:
	ranges []Range
}

fn range_from_string(range string) (i64, i64) {
	mut lower := range.i64()
	mut upper := range.i64()
	// TODO cleanup when we have else blocks for if x := opt()
	if _ := range.index(' to ') {
		// actual range not just a single number
		values := range.split(' to ')
		lower = values[0].i64()
		if values[1] != 'max' {
			upper = values[1].i64()
		} else {
			upper = 536870911
		}
	}
	return lower, upper
}

pub fn (r &RangeChecker) is_range_taken(min i64, max i64) []string {
	mut owners := []string{}
	for _, range in r.ranges {
		if range.min <= max && min <= range.max {
			// overlap
			owners << range.taken_by
		}
	}
	return owners
}

pub fn (mut r RangeChecker) add_new_range(min i64, max i64, owned_by string) {
	r.ranges << Range{min, max, owned_by}
}
