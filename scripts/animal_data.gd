extends RefCounted
## The one source of truth for the fixed evolution order and art palette.

const NAMES := ["Hamster", "Chick", "Bunny", "Capybara", "Cat", "Dog", "Fox", "Sheep", "Penguin", "Unicorn"]
# Two late-game size resets create room before the largest, final animal.
const RADII := [39.0, 48.0, 59.0, 72.0, 86.0, 102.0, 120.0, 95.0, 83.0, 138.0]
const COLORS := [Color("ffc895"), Color("ffe78c"), Color("ffc5d5"), Color("cb946c"), Color("b8dff3"), Color("b8e2c6"), Color("edaaeb"), Color("e1dbff"), Color("77716f"), Color("dbc6f4")]
const EDGES := [Color("d69868"), Color("d3b557"), Color("d992a9"), Color("a17054"), Color("86b6cf"), Color("87b397"), Color("b863b8"), Color("b2a0dd"), Color("4b4543"), Color("b09acb")]
const POINTS := [0, 10, 30, 60, 100, 150, 250, 350, 500, 800]
const LAST_LEVEL := 9
const FIRST_DROP := 1

static func random_drop(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	# All rolls after the guaranteed opening chick use 30 / 30 / 30 / 10.
	return 0 if roll < 0.30 else (1 if roll < 0.60 else (2 if roll < 0.90 else 3))
