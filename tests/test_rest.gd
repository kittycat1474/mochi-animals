extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Body = preload("res://scripts/soft_body.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)

func run() -> void:
	for scenario in ["single", "load", "crowded", "corner"]:
		var world := World.new()
		world.allow_merges = false
		var seeds := [[4, 263, 658]]
		if scenario == "load":
			seeds.append([6, 263, 450])
		elif scenario == "crowded":
			seeds = [[0, 158, 710], [1, 220, 708], [2, 169, 615], [4, 297, 641], [5, 300, 467], [6, 263, 262]]
		elif scenario == "corner":
			seeds = [[0, 158, 615], [1, 164, 704], [4, 275, 669], [1, 387, 712]]
		for seed in seeds:
			# Preserve the v2.8 fixture's release heights relative to the cup.
			world.add_animal(seed[0], Vector2(seed[1], seed[2] + World.Layout.SHIFT_Y - 43.0))
		var previous: Array[PackedVector2Array] = []
		var reference: Array[PackedVector2Array] = []
		var largest_step := 0.0
		var largest_drift := 0.0
		var first_sleep := -1
		for frame in 960:
			world.step(1.0 / 60.0)
			if first_sleep < 0 and world.bodies.all(func(body): return body.sleeping):
				first_sleep = frame
			if frame < 720:
				continue
			for i in world.bodies.size():
				if previous.size() <= i:
					previous.append(world.bodies[i].points.duplicate())
					reference.append(world.bodies[i].points.duplicate())
				for j in Body.COUNT:
					largest_step = maxf(largest_step, previous[i][j].distance_to(world.bodies[i].points[j]))
					largest_drift = maxf(largest_drift, reference[i][j].distance_to(world.bodies[i].points[j]))
				previous[i] = world.bodies[i].points.duplicate()
		print("METRIC: ", scenario, " max contour step=", largest_step, "; 4s drift=", largest_drift, "; settled after ", first_sleep / 60.0, "s")
		check(largest_step < 0.03 and largest_drift < 0.15, scenario + " settles without visible contour jitter or creep")
		check(first_sleep > 0 and first_sleep < 480, scenario + " reaches stable rest within eight seconds")
	test_waking()
	print("RESULT: ", checks - failures, "/", checks, " rest checks passed")
	quit(1 if failures else 0)

func make_sleeping_pile():
	var world := World.new()
	world.allow_merges = false
	world.add_animal(4, Vector2(263, 658))
	world.add_animal(5, Vector2(263, 450))
	for frame in 600:
		world.step(1.0 / 60.0)
	return world

func test_waking() -> void:
	var world = make_sleeping_pile()
	var bottom = world.bodies[0]
	var top = world.bodies[1]
	check(bottom.sleeping and top.sleeping, "supported pile is asleep before wake-up regressions")
	world.add_animal(1, Vector2(263, 90), Vector2(0, 900))
	check(bottom.sleeping and top.sleeping, "a distant new drop does not unnecessarily shake the resting pile")
	var woke := false
	var moved := false
	var before: PackedVector2Array = top.points.duplicate()
	for frame in 120:
		world.step(1.0 / 60.0)
		woke = woke or (not top.sleeping and not bottom.sleeping)
		for i in Body.COUNT:
			moved = moved or before[i].distance_to(top.points[i]) > 1.0
	check(woke and moved, "incoming impact wakes and deforms the whole supported pile")

	world = make_sleeping_pile()
	bottom = world.bodies[0]
	top = world.bodies[1]
	var y: float = top.center.y
	world.remove_near(bottom.center, 1.0)
	check(not top.sleeping, "removing a support wakes the remaining animal immediately")
	for frame in 60:
		world.step(1.0 / 60.0)
	check(top.center.y > y + 30, "woken animal falls into the removed support's space")

	world.clear()
	var airborne = world.add_animal(0, Vector2(263, 130))
	airborne.age = 20.0
	var froze := false
	for frame in 25:
		world.step(1.0 / 60.0)
		froze = froze or airborne.sleeping
	check(not froze and airborne.center.y > 170, "an unsupported animal never sleeps in mid-air")

	world = make_sleeping_pile()
	bottom = world.bodies[0]
	top = world.bodies[1]
	world.allow_merges = true
	var partner = world.add_animal(top.level, top.center + Vector2(0, -top.radius * 2 + 1))
	partner.age = 1.0
	var merged := false
	for frame in 90:
		var events: Array = world.step(1.0 / 60.0)
		merged = merged or not events.is_empty()
	check(merged, "a sleeping animal still wakes and merges with an identical incoming animal")
