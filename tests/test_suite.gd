extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Body = preload("res://scripts/soft_body.gd")
const Data = preload("res://scripts/animal_data.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func run() -> void:
	var started := Time.get_ticks_msec()
	test_evolution()
	test_merge_rules()
	test_gentle_merge()
	test_squash_and_recovery()
	test_soft_load()
	test_rigid_cup_regressions()
	test_stacking()
	test_overflow()
	test_original_assets()
	test_game_flow()
	test_top_drop_controls()
	await test_music()
	print("RESULT: ", checks - failures, "/", checks, " passed in ", Time.get_ticks_msec() - started, " ms")
	quit(1 if failures else 0)

func test_evolution() -> void:
	check(Data.NAMES == ["Hamster", "Chick", "Bunny", "Capybara", "Cat", "Dog", "Fox", "Sheep", "Penguin", "Unicorn"], "fixed ten-animal order in English")
	check(Data.RADII[0] == 39.0, "hamster equals the previous bunny size")
	check(Data.RADII == [39.0, 48.0, 59.0, 72.0, 86.0, 102.0, 120.0, 95.0, 83.0, 138.0], "approved sizes include both late shrink stages and largest final unicorn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 720
	var drop_counts := [0, 0, 0, 0]
	for i in 10000:
		drop_counts[Data.random_drop(rng)] += 1
	var weights_ok := true
	for level in 4:
		weights_ok = weights_ok and abs(drop_counts[level] - (1000 if level == 3 else 3000)) < 200
	check(weights_ok, "four-species drop pool uses 30 / 30 / 30 / 10 probabilities")

func test_merge_rules() -> void:
	for level in Data.NAMES.size():
		var world := World.new()
		var r: float = Data.RADII[level]
		var a = world.add_animal(level, Vector2(270 - r + 1, 150))
		var b = world.add_animal(level, Vector2(270 + r - 1, 150))
		a.age = 2.0
		b.age = 2.0
		var events: Array = []
		for i in 4:
			events.append_array(world.step(1.0 / 60.0))
		if level < Data.LAST_LEVEL:
			check(events.size() == 1 and world.bodies.size() == 1 and world.bodies[0].level == level + 1, "two " + Data.NAMES[level] + " merge exactly once")
			if not events.is_empty():
				check(events[0].points == Data.POINTS[level + 1], "correct score for " + Data.NAMES[level + 1])
		else:
			check(events.is_empty() and world.bodies.size() == 2, "unicorn is the terminal level")
	var world := World.new()
	for x in [193, 270, 347]:
		world.add_animal(0, Vector2(x, 240)).age = 2.0
	var events: Array = world.step(1.0 / 60.0)
	check(events.size() == 1 and world.bodies.size() == 2, "three-way contact cannot consume an animal twice")
	world.clear()
	world.add_animal(0, Vector2(248, 630)).age = 2.0
	world.add_animal(1, Vector2(295, 630)).age = 2.0
	check(world.step(1.0 / 60.0).is_empty() and world.bodies.size() == 2, "different species do not merge")
	world.clear()
	for position in [Vector2(231, 670), Vector2(308, 670), Vector2(269, 585)]:
		world.add_animal(0 if position.y == 670 else 1, position).age = 2.0
	var chain := 0
	for i in 180:
		chain += world.step(1.0 / 60.0).size()
	check(chain == 2 and world.bodies.size() == 1 and world.bodies[0].level == 2, "chain reaction creates a rabbit")

func test_gentle_merge() -> void:
	var world := World.new()
	var a = world.add_animal(0, Vector2(231, 300))
	var b = world.add_animal(0, Vector2(309, 300))
	a.age = 1.0
	b.age = 1.0
	world.contacts = [[a, b]]
	world.merge_contacts()
	var baby = world.bodies[0]
	var speed := Vector2.ZERO
	for i in Body.COUNT:
		speed += (baby.points[i] - baby.previous[i]) * 120.0 / Body.COUNT
	check(speed.length() < 0.02, "merge creates no upward impulse in the zero-bounce version")
	var origin_y: float = baby.center.y
	var highest_y := origin_y
	for frame in 10:
		world.step(1.0 / 60.0)
		highest_y = minf(highest_y, baby.center.y)
	check(origin_y - highest_y < 0.001, "free newborn never hops upward before falling")
	world.clear()
	a = world.add_animal(0, Vector2(224, World.FLOOR_Y - 43))
	b = world.add_animal(0, Vector2(301, World.FLOOR_Y - 43))
	a.age = 1.0
	b.age = 1.0
	world.contacts = [[a, b]]
	world.merge_contacts()
	baby = world.bodies[0]
	check(baby.center.y > World.FLOOR_Y - 45 and cup_penetration(world, baby) < 0.01, "floor merge flattens in place instead of snapping upward to fit a rigid circle")

func test_squash_and_recovery() -> void:
	var body := Body.new(1, 4, Vector2(270, 600))
	var circular := true
	for p in body.points:
		circular = circular and absf(p.distance_to(body.center) - body.radius) < 0.001
	check(circular, "resting silhouette is a perfect circle")
	for i in Body.COUNT:
		var relative := body.points[i] - body.center
		body.points[i] = body.center + relative * Vector2(1.2, 0.72)
	for i in 60:
		body.update_expression(1.0 / 60.0)
	check(body.expression == 2, "extreme compression triggers spiral eyes and tears")
	# Recovery is deliberately slower; still require a circular, happy rest state.
	for i in 600:
		body.solve_shape()
		body.update_expression(1.0 / 60.0)
	check(body.pressure < 0.02 and body.expression == 0, "elastic recovery restores circle and happy face")
	check(absf(body.signed_area() / body.rest_area - 1.0) < 0.015, "area retained after deformation")
	for i in Body.COUNT:
		body.points[i] = body.center + (body.points[i] - body.center) * Vector2(0.86, 1.1)
	for i in 60:
		body.update_expression(1.0 / 60.0)
	check(body.expression == 1, "moderate side compression triggers strained face")
	var world := World.new()
	var squeezed = world.add_animal(6, Vector2(270, 500))
	for frame in 150:
		squeezed.integrate(1.0 / 120.0)
		var half_gap := lerpf(125.0, 85.0, minf(1.0, frame / 90.0))
		for iteration in 5:
			squeezed.solve_shape()
			# Frictionless walls no longer slow the fall. Keep this isolated
			# squeeze fixture's walls long enough for the entire 1.25-second drop.
			world.segment_collision(squeezed, Vector2(270 - half_gap, 100), Vector2(270 - half_gap, 3000))
			world.segment_collision(squeezed, Vector2(270 + half_gap, 100), Vector2(270 + half_gap, 3000))
		squeezed.update_expression(1.0 / 120.0)
	check(squeezed.bounds().size.x < squeezed.radius * 1.5 and squeezed.expression > 0, "actual opposing wall collisions deform the soft body")

func test_soft_load() -> void:
	var world := World.new()
	world.allow_merges = false
	var cat = world.add_animal(4, Vector2(263, 658))
	world.add_animal(6, Vector2(263, 450))
	var min_y := INF
	var max_y := -INF
	for frame in 600:
		world.step(1.0 / 60.0)
		if frame > 480:
			min_y = minf(min_y, cat.center.y)
			max_y = maxf(max_y, cat.center.y)
	# The v2.1 material's strain in this same fixture measured 0.1031.
	check(cat.pressure > 0.12, "cat deforms under the fox load (old unicorn size)")
	check(cat.radius == 86.0 and cat.signed_area() / cat.rest_area > 0.98, "extra squash preserves the original radius and at least 98 percent of area")
	check(max_y - min_y < 2.0, "settled soft stack does not keep bouncing vertically")

func test_stacking() -> void:
	var world := World.new()
	world.allow_merges = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 8017
	var valid := true
	var wall_error := 0.0
	var max_strain := 0.0
	var start := Time.get_ticks_usec()
	for frame in 720:
		if frame % 60 == 0 and frame < 480:
			var level := (frame / 60 as int) % 3
			world.add_animal(level, Vector2(rng.randf_range(160, 360), 269))
		world.step(1.0 / 60.0)
		for body in world.bodies:
			max_strain = maxf(max_strain, body.pressure)
			for p in body.points:
				valid = valid and is_finite(p.x) and is_finite(p.y)
				if p.y > World.CUP_TOP + 12 and not body.spilled:
					wall_error = maxf(wall_error, p.y - World.FLOOR_Y)
					wall_error = maxf(wall_error, world.left_at(p.y) - p.x)
					wall_error = maxf(wall_error, p.x - world.right_at(p.y))
	var ms_per_step := float(Time.get_ticks_usec() - start) / 720000.0
	check(valid, "enlarged-animal stacking remains numerically stable")
	check(wall_error < 0.01, "no body penetrates the tapered cup or floor")
	check(max_strain > 0.09, "stacking dynamically triggers pressure expressions")
	var min_area := 1.0
	for body in world.bodies:
		min_area = minf(min_area, body.signed_area() / body.rest_area)
	check(min_area > 0.97, "stacked animals retain at least 97 percent of their volume")
	print("METRIC: physics mean ", snappedf(ms_per_step, 0.01), " ms/frame; maximum strain ", snappedf(max_strain, 0.01), "; minimum area ratio ", snappedf(min_area, 0.01))

func cup_penetration(world, body) -> float:
	return outline_penetration(world, body.points)

func outline_penetration(world, outline: PackedVector2Array) -> float:
	var worst := 0.0
	for p in outline:
		if p.y >= World.CUP_TOP:
			worst = maxf(worst, world.left_at(p.y) - p.x)
			worst = maxf(worst, p.x - world.right_at(p.y))
			worst = maxf(worst, p.y - World.FLOOR_Y)
	return worst

func test_rigid_cup_regressions() -> void:
	var world := World.new()
	world.allow_merges = false
	var body = world.add_animal(1, Vector2(360, 699))
	# Regression: a constraint/merge can place both Verlet positions past a wall.
	# A proximity test plus previous-frame sweep alone cannot recover this.
	for i in 4:
		body.points[i].x = world.right_at(body.points[i].y) + 24.0
		body.previous[i] = body.points[i]
	world.walls(body)
	check(cup_penetration(world, body) < 0.01, "deep penetration is recovered even when both Verlet positions are outside")
	world.clear()
	body = world.add_animal(4, Vector2(398, 725))
	check(cup_penetration(world, body) < 0.01, "a larger newborn touching the bottom corner is contained immediately")
	check(outline_penetration(world, world.render_outline(body)) < 0.01, "newborn smoothed artwork cannot overshoot the hard cup corner")
	world.clear()
	world.allow_merges = true
	world.add_animal(0, Vector2(395, 640)).age = 2.0
	world.add_animal(0, Vector2(395, 715)).age = 2.0
	var merge_count := 0
	var worst := 0.0
	for frame in 180:
		merge_count += world.step(1.0 / 60.0).size()
		for animal in world.bodies:
			worst = maxf(worst, cup_penetration(world, animal))
	check(merge_count >= 1 and worst < 0.01, "side-wall merge cannot spawn its larger animal through the cup")
	for side in [-1, 1]:
		world.clear()
		world.allow_merges = false
		body = world.add_animal(1, Vector2(270, 696))
		worst = 0.0
		var incorrectly_spilled := false
		for frame in 120:
			for i in Body.COUNT:
				body.points[i].x += side * 7.0
				body.previous[i].x += side * 7.0
			world.step(1.0 / 60.0)
			worst = maxf(worst, cup_penetration(world, body))
			incorrectly_spilled = incorrectly_spilled or body.spilled
		check(worst < 0.01 and not incorrectly_spilled, "sustained lateral pressure cannot escape through side %d" % side)
	world.clear()
	body = world.add_animal(4, Vector2(270, 670))
	worst = 0.0
	for frame in 120:
		for i in Body.COUNT:
			body.points[i].y += 9.0
			body.previous[i].y += 9.0
		world.step(1.0 / 60.0)
		worst = maxf(worst, cup_penetration(world, body))
	check(worst < 0.01 and not body.spilled, "sustained downward pressure cannot push an animal through the floor")
	var fast_impact_leak := false
	for velocity in [Vector2(-900, 0), Vector2(900, 0), Vector2(0, 900)]:
		world.clear()
		body = world.add_animal(2, Vector2(270, 615), velocity)
		for frame in 120:
			world.step(1.0 / 60.0)
			fast_impact_leak = fast_impact_leak or cup_penetration(world, body) > 0.01 or body.spilled
	check(not fast_impact_leak, "maximum-speed impacts cannot tunnel through either wall or the floor")
	world.clear()
	world.allow_merges = false
	for seed in [[0, 158, 615], [1, 164, 704], [4, 275, 669], [1, 387, 712]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	worst = 0.0
	var leaked := false
	var artwork_leaked := false
	for frame in 600:
		world.step(1.0 / 60.0)
		for animal in world.bodies:
			worst = maxf(worst, cup_penetration(world, animal))
			leaked = leaked or animal.spilled
			artwork_leaked = artwork_leaked or outline_penetration(world, world.render_outline(animal)) > 0.01
	check(worst < 0.01 and not leaked, "reported cat-and-chicks bottom-corner arrangement stays entirely in the cup")
	check(not artwork_leaked, "reported arrangement also keeps every smoothed artwork vertex inside the cup")

func test_overflow() -> void:
	var world := World.new()
	var body = world.add_animal(0, Vector2(270, 320))
	body.age = 100.0
	world.update_spill_state(body)
	check(not world.has_grounded_spill(), "remaining above the rim never triggers a countdown loss")
	world.clear()
	body = world.add_animal(0, Vector2(30, World.GROUND_Y - 208))
	world.update_spill_state(body)
	check(body.spilled and not world.has_grounded_spill(), "outside animal still airborne does not end the game")
	for i in Body.COUNT:
		body.points[i].y += 200.0
	check(world.has_grounded_spill(), "outside animal touching cup-bottom height ends the game")
	world.clear()
	body = world.add_animal(0, Vector2(270, World.FLOOR_Y - 40))
	for i in 120:
		world.step(1.0 / 60.0)
	check(not body.spilled and not world.has_grounded_spill(), "resting inside on cup floor is safe")
	world.clear()
	body = world.add_animal(0, Vector2(50, 260), Vector2(-100, 0))
	for i in 10:
		world.step(1.0 / 60.0)
	check(body.center.x < 45, "no invisible side wall above the rim")
	var lost := false
	var premature := false
	for i in 240:
		world.step(1.0 / 60.0)
		if world.has_grounded_spill():
			premature = body.bounds().end.y < World.GROUND_Y
			lost = true
			break
	check(lost and not premature, "full rim escape and fall ends only at outside ground contact")
	world.clear()
	world.allow_merges = false
	# Softer bodies can settle into different stable arrangements. Keep adding
	# animals until the cup truly overflows, without requiring a six-drop quota.
	for frame in 2160:
		if frame % 150 == 0 and frame < 1500:
			world.add_animal(5 if frame % 300 == 0 else 4, Vector2(195 if frame % 300 == 0 else 335, 210))
		world.step(1.0 / 60.0)
		if world.has_grounded_spill():
			break
	check(world.has_grounded_spill(), "overfilled stack naturally spills over finite cup walls")

func test_original_assets() -> void:
	var painter = load("res://scripts/sprite_painter.gd")
	check(painter.REGIONS.size() == 21 and painter.NEW_REGIONS.size() == 9, "all ten animals have three supplied expression rows")
	check(painter.SHEET.get_width() == 1916 and painter.SHEET.get_height() == 821, "unmodified original animal atlas is loaded")
	var art = load("res://scripts/asset_art.gd")
	check(art.UI.get_width() == 1536 and art.CUP.get_width() == 1122, "original button and cup artwork is loaded")

func test_game_flow() -> void:
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.sound.enabled = false
	game.set_aim(-1000)
	check(game.aim_x > World.LEFT_TOP + Data.RADII[0], "aim is clamped to safe release bounds")
	game.drop_animal()
	game.drop_animal()
	check(game.world.bodies.size() == 1 and game.total_drops == 1, "rapid clicks respect drop cooldown")
	game.cooldown = 0.0
	game.overlay = "pause"
	game.drop_animal()
	check(game.world.bodies.size() == 1, "paused games do not accept a drop")
	var old_position: Vector2 = game.world.bodies[0].center
	game._physics_process(1.0 / 60.0)
	check(game.world.bodies[0].center == old_position, "pause freezes simulation")
	game.overlay = ""
	game.on_merge({"level": 6, "points": 250, "position": Vector2(270, 600)})
	check(game.score == 250 and game.highest_level == 6 and game.toast_time == 0, "score and discoveries update without first-merge greetings")
	game.reset_game()
	check(game.world.bodies.is_empty() and game.score == 0 and game.overlay.is_empty(), "restart clears the game state")
	check(game.best == 250, "restart preserves best score")
	check(game.coins == 0 and game.hammers == 0 and game.bombs == 0, "restart clears coins and tool inventory")
	game.coins = 550
	game.buy_tool("hammer")
	game.world.add_animal(0, Vector2(270, 600))
	game.select_tool("hammer")
	game.use_tool(Vector2(270, 600))
	check(game.world.bodies.is_empty() and game.hammers == 0, "asset hammer button removes one animal and consumes one charge")
	game.buy_tool("bomb")
	check(game.coins == 0 and game.bombs == 1, "200-coin hammer and 350-coin bomb update balance and inventory")
	game.selected_tool = "bomb"
	game.world.add_animal(0, Vector2(240, 600))
	game.world.add_animal(1, Vector2(310, 600))
	game.use_tool(Vector2(240, 600))
	check(game.world.bodies.is_empty() and game.bombs == 0, "bomb clears nearby animals")
	game.free()

func test_top_drop_controls() -> void:
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.sound.enabled = false
	game.sound.set_music(false)
	var piled = game.world.add_animal(2, Vector2(270, 290))
	game.current_level = 1
	var move := InputEventMouseMotion.new()
	move.position = Vector2(270, 110)
	game._input(move)
	check(absf(game.aim_x - 270.0) < 0.01, "pointer can aim in the new top launch area")
	game.handle_press(move.position)
	game.handle_release(move.position)
	var launched = game.world.bodies.back()
	check(game.total_drops == 1 and launched.center.y < 140.0 and not launched.bounds().intersects(piled.bounds()), "top release creates a real animal above the overflowing stack")
	game.cooldown = 0.0
	game.handle_press(Vector2(250, 180))
	game.handle_release(Main.NEXT_RECT.get_center())
	check(game.total_drops == 1, "releasing a drag over the NEXT card does not accidentally drop")
	game.handle_press(Main.NEXT_RECT.get_center())
	game.handle_release(Main.NEXT_RECT.get_center())
	check(game.total_drops == 1, "the relocated NEXT card is display-only")
	game.free()

func test_music() -> void:
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.overlay = "pause"
	game.sound.enabled = false
	var player: AudioStreamPlayer = game.sound.music_player
	check(game.sound.music_enabled and player.playing, "supplied MP3 starts automatically on a fresh launch")
	check(player.stream is AudioStreamMP3 and player.stream.get_length() > 52.0 and player.stream.get_length() < 53.0, "music uses the supplied 52-second MP3")
	check(absf(db_to_linear(player.volume_db) - 0.30) < 0.0001, "initial music amplitude is 30 percent")
	check(player.stream.loop and player.stream.loop_offset == 0.0, "MP3 is configured to loop from the beginning")
	game.overlay = ""
	game.handle_press(Main.MUSIC_RECT.get_center())
	check(not game.sound.music_enabled and not player.playing, "existing music button stops the MP3 independently of effects")
	var saved := ConfigFile.new()
	game.sound.store_music(saved)
	game.sound.set_music(true)
	game.sound.restore_music(saved)
	check(not player.playing, "music off preference survives save and restore")
	var legacy := ConfigFile.new()
	legacy.set_value("game", "music", false)
	game.sound.restore_music(legacy)
	check(player.playing, "old synthesized-music default migrates to MP3 autoplay")
	game.handle_press(Main.MUSIC_RECT.get_center())
	game.handle_press(Main.MUSIC_RECT.get_center())
	check(player.playing and game.sound.music_enabled, "existing music button restarts the MP3")
	# Give the audio thread time to apply the queued stop/start operations before
	# seeking. A seek in the same frame can be superseded by the queued play.
	await create_timer(0.20).timeout
	player.seek(player.stream.get_length() - 0.10)
	await create_timer(0.40).timeout
	check(player.playing and player.get_playback_position() < 1.5, "playback actually wraps to the start after reaching the MP3 end")
	game.sound.set_music(false)
	game.free()
	await create_timer(0.15).timeout
