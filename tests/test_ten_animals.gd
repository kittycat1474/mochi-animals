extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Body = preload("res://scripts/soft_body.gd")
const Data = preload("res://scripts/animal_data.gd")
const Painter = preload("res://scripts/sprite_painter.gd")
const Art = preload("res://scripts/asset_art.gd")
const Main = preload("res://scripts/main.gd")
const Sound = preload("res://scripts/sound.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)

func overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var result := 0.0
	for polygon in Geometry2D.intersect_polygons(a, b):
		var area := 0.0
		for i in polygon.size():
			area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
		result += absf(area) * 0.5
	return result

func run() -> void:
	check(World.CUP_TOP == 401 and World.FLOOR_Y == 799 and World.GROUND_Y == 851 and Art.CUP_RECT.position.y == 311, "art, rim, solid floor and spill ground share the 43-unit cup translation")
	check(not Main.CHAIN_RECT.intersects(Main.NEXT_RECT) and Main.CHAIN_RECT.position.y > World.GROUND_Y, "complete evolution strip clears both the lowered cup and NEXT")
	check(absf(Main.CHAIN_RECT.size.aspect() - Art.CHAIN_REGION.size.aspect()) < 0.001, "new evolution strip keeps its artwork aspect ratio without transparent padding")
	check(Sound.MERGE_NOTES.size() == Data.NAMES.size(), "all ten merge levels have a valid sound")
	var regions := {}
	var atlas_ok := true
	for level in Data.NAMES.size():
		for expression in 3:
			var sheet := Painter.sheet_for(level)
			var region := Painter.region_for(level, expression)
			var arrays := Painter.mesh_arrays(level, Vector2(250, 250), Data.RADII[level], expression)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var expected := region.get_center() / sheet.get_size()
			atlas_ok = atlas_ok and uvs[-1].distance_to(expected) < 0.00001
			for uv in uvs:
				atlas_ok = atlas_ok and region.grow(4).has_point(uv * sheet.get_size())
			regions[str(sheet.resource_path) + str(region)] = true
	check(atlas_ok and regions.size() == 30, "all 30 expressions sample distinct correct atlas regions and keep the face anchor")
	check(Painter.sheet_for(6) == Painter.NEW_SHEET and Painter.sheet_for(7) == Painter.NEW_SHEET and Painter.sheet_for(8) == Painter.NEW_SHEET and Painter.region_for(9, 0) == Painter.REGIONS[6], "new animals and original unicorn map to the approved artwork")
	for level in [6, 7, 8]:
		var world := World.new()
		var radius: float = Data.RADII[level]
		# Make the parents touch vertically inside the cup, above an older support.
		var support = world.add_animal(4, Vector2(263, World.FLOOR_Y - 85))
		var a = world.add_animal(level, Vector2(263, World.FLOOR_Y - 220))
		var b = world.add_animal(level, Vector2(263, World.FLOOR_Y - 220 - radius * 2 + 1))
		a.age = 1.0
		b.age = 1.0
		world.contacts = [[a, b]]
		var events := world.merge_contacts()
		var newborn = world.bodies.back()
		check(events.size() == 1 and newborn.level == level + 1 and newborn.radius == Data.RADII[level + 1], "%s merge produces the approved %s size" % [Data.NAMES[level], Data.NAMES[level + 1]])
		check((newborn.radius < radius) == (level < 8), "shrink/shrink/grow transition is correct at level %d" % level)
		check(overlap(world.render_outline(newborn), world.render_outline(support)) < 0.01, "newborn is non-overlapping before its first rendered frame")
		world.allow_merges = false
		var worst := 0.0
		var wall_error := 0.0
		var origin_y: float = newborn.center.y
		for frame in 420:
			world.step(1.0 / 60.0)
			worst = maxf(worst, overlap(world.render_outline(newborn), world.render_outline(support)))
			for body in world.bodies:
				for p in body.points:
					wall_error = maxf(wall_error, p.distance_to(world.constrain_to_cup(p, body.cup_side)))
		check(worst < 0.01 and wall_error < 0.01, "late-game %s remains non-overlapping inside the lowered hard cup" % Data.NAMES[level + 1])
		check(newborn.center.y > origin_y + 10 and newborn.signed_area() > newborn.rest_area * 0.97, "late-game newborn falls into available space while retaining its new target area")
	var crowded := World.new()
	crowded.allow_merges = false
	for seed in [[9, 257, 663], [0, 145, 746], [1, 376, 742], [8, 175, 481], [7, 354, 477], [6, 260, 277]]:
		crowded.add_animal(seed[0], Vector2(seed[1], seed[2]))
	var worst_overlap := 0.0
	var worst_wall := 0.0
	var visible := true
	for frame in 480:
		crowded.step(1.0 / 60.0)
		var outlines: Array[PackedVector2Array] = []
		for body in crowded.bodies:
			var outline := crowded.render_outline(body)
			outlines.append(outline)
			visible = visible and not Geometry2D.triangulate_polygon(outline).is_empty()
			for p in body.points:
				worst_wall = maxf(worst_wall, p.distance_to(crowded.constrain_to_cup(p, body.cup_side)))
		for i in outlines.size():
			for j in range(i + 1, outlines.size()):
				worst_overlap = maxf(worst_overlap, overlap(outlines[i], outlines[j]))
	print("METRIC: all late animals crowded together: overlap=", worst_overlap, "; wall error=", worst_wall)
	check(worst_overlap < 0.01 and visible, "all new animals and largest unicorn stack with drawable, non-overlapping artwork")
	check(worst_wall < 0.01, "late-game crowding cannot push through the lowered cup")
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.sound.set_music(false)
	game.sound.enabled = false
	var no_greetings := true
	for level in range(1, Data.NAMES.size()):
		game.on_merge({"level": level, "points": Data.POINTS[level], "position": Vector2(263, 550)})
		no_greetings = no_greetings and game.toast.is_empty() and game.toast_time == 0
	check(no_greetings and game.highest_level == 9 and game.score == 2250, "every discovery including Unicorn scores normally without a greeting banner")
	game.free()
	await process_frame
	print("RESULT: ", checks - failures, "/", checks, " ten-animal checks passed")
	quit(1 if failures else 0)
