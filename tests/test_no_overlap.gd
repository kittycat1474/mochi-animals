extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Body = preload("res://scripts/soft_body.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)
	else:
		print("PASS: ", description)

func area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for i in polygon.size():
		result += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(result) * 0.5

func intersection_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var result := 0.0
	for polygon in Geometry2D.intersect_polygons(a, b):
		result += area(polygon)
	return result

func worst_overlap(world, rendered := false) -> float:
	var result := 0.0
	for i in world.bodies.size():
		for j in range(i + 1, world.bodies.size()):
			var a = world.bodies[i]
			var b = world.bodies[j]
			if not a.bounds().grow(8).intersects(b.bounds()):
				continue
			var ap: PackedVector2Array = world.render_outline(a) if rendered else a.points
			var bp: PackedVector2Array = world.render_outline(b) if rendered else b.points
			result = maxf(result, intersection_area(ap, bp))
	return result

func deform(body, scale_by: Vector2) -> void:
	for i in Body.COUNT:
		body.points[i] = body.center + body.rest[i] * scale_by
		body.previous[i] = body.points[i]

func run() -> void:
	# Reproduces a small animal trapped under a larger compressed animal.
	var world := World.new()
	world.allow_merges = false
	for seed in [[0, 158, 710], [1, 220, 708], [2, 169, 615], [4, 297, 641], [5, 300, 467], [6, 263, 262]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	var worst_physics := 0.0
	var worst_art := 0.0
	var all_visible := true
	var start := Time.get_ticks_usec()
	for frame in 420:
		world.step(1.0 / 60.0)
		worst_physics = maxf(worst_physics, worst_overlap(world))
		worst_art = maxf(worst_art, worst_overlap(world, true))
		for body in world.bodies:
			all_visible = all_visible and not Geometry2D.triangulate_polygon(world.render_outline(body)).is_empty()
	print("METRIC: crowded pile overlap physics=", worst_physics, ", artwork=", worst_art,
		" square pixels; ", (Time.get_ticks_usec() - start) / 420000.0, " ms/frame including polygon checks")
	check(worst_physics < 0.01, "compressed mixed-size pile has no physical intersection on any frame")
	check(worst_art < 0.01, "smoothed artwork never crosses another animal's silhouette")
	check(all_visible, "severely deformed artwork remains a drawable, ordered polygon")
	var smallest_area := 1.0
	var pressure := 0.0
	for body in world.bodies:
		smallest_area = minf(smallest_area, body.signed_area() / body.rest_area)
		pressure = maxf(pressure, body.pressure)
	print("METRIC: final minimum area=", smallest_area, ", pressure=", pressure)
	check(smallest_area > 0.96, "non-overlap does not solve crowding by permanently shrinking animals")
	check(pressure > 0.12, "animals remain visibly squishy under a heavy pile")

	# Long crossing strips intersect through edges, without any enclosed vertices.
	world.clear()
	var a = world.add_animal(0, Vector2(263, 190))
	var b = world.add_animal(1, Vector2(263, 190))
	deform(a, Vector2(2.6, 0.16))
	deform(b, Vector2(0.16, 2.2))
	world.collide(a, b)
	check(intersection_area(a.points, b.points) < 0.01, "edge-only crossings are separated even with no vertex inside")

	# A concave contact cannot be treated as a convex point-in-polygon query.
	world.clear()
	a = world.add_animal(2, Vector2(263, 220))
	b = world.add_animal(0, Vector2(325, 220))
	a.points[0] = a.center + Vector2(10, 0)
	a.previous[0] = a.points[0]
	world.collide(a, b)
	check(intersection_area(a.points, b.points) < 0.01, "deep concave indentation does not disable collision detection")

	world.clear()
	a = world.add_animal(0, Vector2(145, 185))
	b = world.add_animal(1, Vector2(373, 185))
	deform(a, Vector2(3.5, 0.32))
	deform(b, Vector2(2.5, 0.4))
	world.step(1.0 / 60.0)
	check(worst_overlap(world) < 0.01, "broad phase uses deformed bounds, not original circular radii")

	world.clear()
	world.allow_merges = true
	a = world.add_animal(0, Vector2(225, 700))
	b = world.add_animal(0, Vector2(302, 700))
	world.add_animal(2, Vector2(263, 610))
	a.age = 1.0
	b.age = 1.0
	world.contacts = [[a, b]]
	world.merge_contacts()
	check(worst_overlap(world) < 0.01 and worst_overlap(world, true) < 0.01, "larger merged newborn is separated before its first rendered frame")
	test_dense_drops()
	print("RESULT: ", checks - failures, "/", checks, " non-overlap checks passed")
	quit(1 if failures else 0)

func test_dense_drops() -> void:
	for merging in [false, true]:
		var world := World.new()
		world.allow_merges = merging
		var rng := RandomNumberGenerator.new()
		rng.seed = 240930
		var worst := 0.0
		var art_worst := 0.0
		var visible := true
		var wall_error := 0.0
		var physics_usec := 0
		var frame_count := 0
		for frame in 1500:
			if frame % 55 == 0:
				var level := rng.randi_range(0, 2) if merging else rng.randi_range(0, 5)
				world.add_animal(level, Vector2(rng.randf_range(163, 363), 90), Vector2(0, 900))
			var start := Time.get_ticks_usec()
			world.step(1.0 / 60.0)
			physics_usec += Time.get_ticks_usec() - start
			frame_count += 1
			worst = maxf(worst, worst_overlap(world))
			art_worst = maxf(art_worst, worst_overlap(world, true))
			for body in world.bodies:
				visible = visible and not Geometry2D.triangulate_polygon(world.render_outline(body)).is_empty()
				for point in body.points:
					if body.cup_side == 0:
						wall_error = maxf(wall_error, point.distance_to(world.constrain_to_cup(point, 0)))
			if world.has_grounded_spill():
				break
		var mode := "merging" if merging else "mixed-size overflow"
		print("METRIC: ", mode, " ", frame_count, " frames; physical overlap=", worst,
			", art overlap=", art_worst, "; physics=", physics_usec / (frame_count * 1000.0), " ms/frame")
		check(worst < 0.01 and art_worst < 0.01, mode + " stays non-overlapping through maximum-speed drops")
		check(visible and wall_error < 0.01, mode + " preserves drawable animals and hard cup walls")
