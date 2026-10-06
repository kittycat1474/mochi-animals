extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Body = preload("res://scripts/soft_body.gd")
const Painter = preload("res://scripts/sprite_painter.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func sample_uv(at: Vector2, arrays: Array) -> Vector2:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var av: Vector3 = vertices[indices[i]]
		var bv: Vector3 = vertices[indices[i + 1]]
		var cv: Vector3 = vertices[indices[i + 2]]
		var a := Vector2(av.x, av.y)
		var b := Vector2(bv.x, bv.y)
		var c := Vector2(cv.x, cv.y)
		var determinant := (b - a).cross(c - a)
		if absf(determinant) < 0.00001:
			continue
		var v := (at - a).cross(c - a) / determinant
		var w := (b - a).cross(at - a) / determinant
		if v >= -0.0001 and w >= -0.0001 and v + w <= 1.0001:
			return uv[indices[i]] * (1.0 - v - w) + uv[indices[i + 1]] * v + uv[indices[i + 2]] * w
	return Vector2.INF

func run() -> void:
	var world := World.new()
	world.allow_merges = false
	# Measured from the user's recording: a cat with chicks and hamsters on
	# both sides. Check live deformation, before sleeping can hide a defect.
	for seed in [[4, 282, 687], [1, 170, 708], [0, 142, 625], [1, 199, 585], [1, 353, 570], [0, 397, 640]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	var anchor_error := 0.0
	var old_error := 0.0
	var unanchored := 0
	var physical_step := 0.0
	var old_previous := {}
	var old_uv_jump := 0.0
	for frame in 360:
		var before := {}
		for body in world.bodies:
			before[body.id] = body.points.duplicate()
		world.step(1.0 / 60.0)
		for body in world.bodies:
			var outline: PackedVector2Array = world.render_outline(body)
			var arrays := Painter.mesh_arrays(body.level, body.center, body.radius, 0, outline)
			var region: Rect2 = Painter.REGIONS[body.level]
			var expected := region.get_center() / Painter.SHEET.get_size()
			anchor_error = maxf(anchor_error, ((sample_uv(body.center, arrays) - expected) * Painter.SHEET.get_size()).length())
			if not Painter.supports_center_fan(outline, body.center):
				unanchored += 1
			# Reconstruct v2.4's rendering to expose UV jumps, independently of
			# physics, on exactly the same small contour movements.
			var old_arrays := arrays.duplicate()
			old_arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
			var old_uv := sample_uv(body.center, old_arrays) * Painter.SHEET.get_size()
			old_error = maxf(old_error, old_uv.distance_to(region.get_center()))
			if old_previous.has(body.id):
				old_uv_jump = maxf(old_uv_jump, old_uv.distance_to(old_previous[body.id]))
			old_previous[body.id] = old_uv
			if frame > 180:
				for i in Body.COUNT:
					physical_step = maxf(physical_step, body.points[i].distance_to(before[body.id][i]))
	print("METRIC: face anchor error=", anchor_error, " atlas pixels; v2.4 error=", old_error,
		"; v2.4 largest face UV jump=", old_uv_jump, "; unanchored frames=", unanchored, "; late contour step=", physical_step)
	check(anchor_error < 0.01 and unanchored == 0, "face stays pinned throughout the recorded arrangement's live deformation")
	check(physical_step < 0.05, "recorded arrangement has no persistent physical chatter")
	test_gliding()
	test_no_restitution()
	print("RESULT: ", checks - failures, "/", checks, " sliding/render checks passed")
	quit(1 if failures else 0)

func test_gliding() -> void:
	var world := World.new()
	world.allow_merges = false
	world.add_animal(6, Vector2(263, 620))
	for frame in 300:
		world.step(1.0 / 60.0)
	var slider = world.add_animal(0, Vector2(310, 425), Vector2(0, 250))
	var start_x: float = slider.center.x
	var upward_step := 0.0
	var overlap := 0.0
	for frame in 180:
		var previous_y: float = slider.center.y
		world.step(1.0 / 60.0)
		upward_step = maxf(upward_step, previous_y - slider.center.y)
		for polygon in Geometry2D.intersect_polygons(slider.points, world.bodies[0].points):
			var area := 0.0
			for i in polygon.size():
				area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
			overlap = maxf(overlap, absf(area) * 0.5)
	print("METRIC: side glide distance=", slider.center.x - start_x, "; largest upward step=", upward_step, "; intersection=", overlap)
	check(slider.center.x > start_x + 30.0, "off-centre landing slides past the other animal instead of sticking")
	check(upward_step < 0.2 and overlap < 0.01, "sliding contact has no visible upward bounce or overlap")

func test_no_restitution() -> void:
	var world := World.new()
	var body := Body.new(1, 0, Vector2(263, World.FLOOR_Y - 40))
	for i in Body.COUNT:
		body.previous[i] = body.points[i] - Vector2(3, 2)
	world.segment_collision(body, Vector2(110, World.FLOOR_Y), Vector2(420, World.FLOOR_Y))
	var velocity: Vector2 = body.points[5] - body.previous[5]
	check(absf(velocity.y) < 0.001 and velocity.x > 2.7, "glass contact keeps tangential sliding and reflects zero normal velocity")
	body.contacted = true
	for i in Body.COUNT:
		body.previous[i] = body.points[i] - Vector2(2, sin(i * 0.7) * 5)
	body.damp_contact_motion()
	var first: Vector2 = body.points[0] - body.previous[0]
	var local_error := 0.0
	for i in Body.COUNT:
		local_error = maxf(local_error, (body.points[i] - body.previous[i]).distance_to(first))
	check(local_error < 0.001 and first.x > 1.8, "contact removes all local vibration velocity without freezing bulk sliding")
