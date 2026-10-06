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

func run() -> void:
	for side in [-1, 1]:
		var world := World.new()
		world.allow_merges = false
		var x := world.left_at(430) + 41 if side < 0 else world.right_at(430) - 41
		var slider = world.add_animal(0, Vector2(x, 430), Vector2(side * 100, 100))
		var arrival := -1.0
		var wall_error := 0.0
		for frame in 90:
			world.step(1.0 / 60.0)
			if arrival < 0 and slider.center.y >= 700:
				arrival = (frame + 1) / 60.0
			for p in slider.points:
				wall_error = maxf(wall_error, p.distance_to(world.constrain_to_cup(p, 0)))
		print("METRIC: wall ", side, " arrival=", arrival, "s; boundary error=", wall_error)
		check(arrival > 0 and arrival < 0.8, "side %d permits immediate gravity-driven sliding without wall drag" % side)
		check(wall_error < 0.01 and not slider.spilled, "side %d remains a solid barrier during fast sliding" % side)
	var body := Body.new(1, 0, Vector2(263, 500))
	body.contacted = true
	for i in Body.COUNT:
		body.previous[i] = body.points[i] - Vector2(2, 4)
	for iteration in 100:
		body.damp_contact_motion()
	check((body.points[0] - body.previous[0]).distance_to(Vector2(2, 4)) < 0.001, "contact smoothing never repeatedly brakes bulk sliding velocity")
	var bounds := body.bounds()
	body.points[0].x += 50
	check(body.bounds().end.x > bounds.end.x + 49 and body.center.x > 264, "cached bounds and center invalidate on actual particle changes")
	var world := World.new()
	world.allow_merges = false
	var cat = world.add_animal(4, Vector2(263, 658))
	world.add_animal(6, Vector2(263, 450))
	for frame in 600:
		world.step(1.0 / 60.0)
	print("METRIC: slime load strain=", cat.pressure, "; retained area=", cat.signed_area() / cat.rest_area)
	check(cat.pressure > 0.15 and cat.radius == 86 and cat.signed_area() > cat.rest_area * 0.98, "slime spreads under load without shrinking its nominal size or area")
	check(cat.sleeping, "more compliant material still settles completely")
	world.remove_near(cat.center, 1)
	check(world.contact_normals.is_empty() and world.validated_contacts.is_empty(), "removed/merged bodies leave no stale contact caches")
	print("RESULT: ", checks - failures, "/", checks, " slime regressions passed")
	quit(1 if failures else 0)
