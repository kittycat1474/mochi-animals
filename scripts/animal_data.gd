extends RefCounted
## The one source of truth for the fixed evolution order and art palette.

const NAMES := ["Hamster", "Chick", "Bunny", "Capybara", "Cat", "Dog", "Unicorn"]
const RADII := [39.0, 48.0, 59.0, 72.0, 86.0, 102.0, 120.0]
const COLORS := [Color("ffc895"), Color("ffe78c"), Color("ffc5d5"), Color("cb946c"), Color("b8dff3"), Color("b8e2c6"), Color("dbc6f4")]
const EDGES := [Color("d69868"), Color("d3b557"), Color("d992a9"), Color("a17054"), Color("86b6cf"), Color("87b397"), Color("b09acb")]
const POINTS := [0, 10, 30, 60, 100, 150, 250]
const LAST_LEVEL := 6

static func random_drop(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	return 0 if roll < 0.48 else (1 if roll < 0.80 else 2)
