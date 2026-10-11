extends Node2D

const Data = preload("res://scripts/animal_data.gd")
const World = preload("res://scripts/soft_world.gd")
const Painter = preload("res://scripts/sprite_painter.gd")
const Art = preload("res://scripts/asset_art.gd")
const Sound = preload("res://scripts/sound.gd")
const PointerRouter = preload("res://scripts/pointer_router.gd")
const RewardGateway = preload("res://scripts/reward_gateway.gd")
const INK := Color("703719")
const CREAM := Color("fff0d9")
const HOME_RECT := Rect2(10, 80, 50, 50)
const HAMMER_RECT := Rect2(5, 149, 60, 56)
const BOMB_RECT := Rect2(5, 217, 60, 56)
# Keep NEXT's top/right anchors and height, matching the new capsule's aspect.
const NEXT_RECT := Rect2(528.0 - 106.0 * 836.0 / 1470.0, 80, 106.0 * 836.0 / 1470.0, 106)
const CHAIN_RECT := Rect2(12, 894, 516, 516.0 * 238.0 / 2156.0)
const COIN_RECT := Rect2(14, 10, 162, 49)
const SCORE_RECT := Rect2(188, 10, 162, 53)
const BEST_RECT := Rect2(363, 10, 162, 44)
const DROP_TOP := 72.0
const PLAY_RECT := Rect2(5, 65, 475, 792)
const GIFT_RECT := Rect2(483, 207, 45, 46)
const STATS_RECT := Rect2(483, 258, 45, 46)
const SOUND_RECT := Rect2(483, 309, 45, 46)
const MUSIC_RECT := Rect2(483, 360, 45, 46)
const PRIMARY_RECT := Rect2(119, 550, 302, 109)
const SECONDARY_RECT := Rect2(145, 670, 250, 76)
const SHOP_HAMMER_RECT := Rect2(145, 423, 105, 97)
const SHOP_BOMB_RECT := Rect2(289, 423, 105, 97)
const SHOP_PRIMARY_RECT := Rect2(119, 580, 302, 109)
const TOOL_PRICES := {"hammer": [200, 300, 400, 500], "bomb": [350, 500, 750, 900]}
const REVIVE_LIMIT := 3
const SETTLE_SECONDS := 1.0
const SAVE_PATH := "user://mochi_save.cfg"

var world := World.new()
var sound: Node
var rng := RandomNumberGenerator.new()
var font := SystemFont.new()
var score := 0
var best := 0
var top_scores: Array[int] = []
var round_recorded := false
var coins := 0
var lifetime_merges := 0
var highest_level := 0
var current_level := Data.FIRST_DROP
var next_level := 0
var aim_x := 265.0
var cooldown := 0.0
var elapsed := 0.0
var overlay := ""
var particles: Array = []
var popups: Array = []
var toast := ""
var toast_time := 0.0
var combo := 0
var combo_timer := 0.0
var total_drops := 0
var pointer_down := false
var input_router := PointerRouter.new()
var rewards := RewardGateway.new()
var reward_rng := RandomNumberGenerator.new()
var revives_used := 0
var gifts_claimed := 0
var settle_time := 0.0
var failed_body_id := -1
var scores_before_loss: Array[int] = []
var web_input: JavaScriptObject
var web_input_callback: JavaScriptObject
var web_bridge_active := false
var web_debug := false
var web_debug_timer := 0.0
var input_counts := {"native_touch": 0, "native_mouse": 0, "bridge": 0, "accepted_down": 0}
var pointer := Vector2(265, 500)
var show_capture := false
var capture_path := ""
var capture_frames := 0
var persistence_enabled := true
var save_path := SAVE_PATH
var hammers := 0
var bombs := 0
var tool_purchases := {"hammer": 0, "bomb": 0}
var selected_tool := ""
var previous_overlay := ""
var capture_mode := ""

func _ready() -> void:
	get_window().title = "Mochi Animals — v3.0"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Rounded MT", "Arial"])
	font.font_weight = 700
	sound = Sound.new()
	add_child(sound)
	rng.randomize()
	reward_rng.randomize()
	rewards.completed.connect(on_reward_completed)
	# Parse developer options before touching a save. Previews never change records.
	for arg in OS.get_cmdline_user_args():
		if arg == "--showcase":
			show_capture = true
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-mode="):
			capture_mode = arg.trim_prefix("--capture-mode=")
	if show_capture or not capture_path.is_empty() or not capture_mode.is_empty():
		persistence_enabled = false
	load_settings()
	reset_game()
	if show_capture:
		seed_showcase()
	if capture_mode == "home":
		overlay = "home"
	if capture_mode == "expressions":
		overlay = "gallery"
	if capture_mode == "wall-regression":
		seed_wall_regression()
	if capture_mode == "overflow-layout":
		seed_overflow_layout()
	if capture_mode == "overlap-regression":
		seed_overlap_regression()
	if capture_mode == "sliding-regression":
		seed_sliding_regression()
	if capture_mode == "ten-animals":
		seed_ten_animals()
	if capture_mode == "fresh-cup":
		reset_game()
	if capture_mode == "top-three":
		top_scores.assign([4380, 2260, 1480])
		overlay = "stats"
	if capture_mode == "top-three-empty":
		top_scores.clear()
		overlay = "stats"
	if capture_mode == "shop":
		reset_game()
		overlay = "shop"
	if capture_mode == "shop-limit":
		reset_game()
		coins = 9000
		for i in 4:
			buy_tool("hammer")
			buy_tool("bomb")
		overlay = "shop"
		toast_time = 0.0
	if capture_mode == "revive":
		seed_revive_preview()
	get_window().focus_exited.connect(on_focus_lost)
	if OS.has_feature("web"):
		setup_web_input()
		announce_web_ready.call_deferred()

func announce_web_ready() -> void:
	await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("window.dispatchEvent(new Event('mochi-ready'))")

func reset_game() -> void:
	world.clear()
	round_recorded = false
	revives_used = 0
	gifts_claimed = 0
	settle_time = 0.0
	failed_body_id = -1
	scores_before_loss.clear()
	rewards.cancel()
	score = 0
	coins = 0
	highest_level = 0
	total_drops = 0
	current_level = Data.FIRST_DROP
	next_level = Data.random_drop(rng)
	aim_x = 265.0
	cooldown = 0.0
	combo = 0
	combo_timer = 0.0
	particles.clear()
	popups.clear()
	toast = ""
	toast_time = 0.0
	pointer_down = false
	hammers = 0
	bombs = 0
	tool_purchases = {"hammer": 0, "bomb": 0}
	selected_tool = ""
	overlay = ""
	queue_redraw()

func load_settings() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	var result := config.load(save_path)
	if result != OK and save_path == SAVE_PATH:
		# Read the v1 save once when migrating to the English application name.
		result = config.load(OS.get_user_data_dir().get_base_dir().path_join("Mochi Animals · 麻薯动物杯/mochi_save.cfg"))
	if result == OK:
		best = maxi(0, int(config.get_value("game", "best", 0)))
		top_scores.clear()
		if config.has_section_key("game", "top_scores"):
			var stored: Variant = config.get_value("game", "top_scores", [])
			if stored is Array:
				for entry in stored:
					if entry is int and entry >= 0:
						top_scores.append(entry)
		elif best > 0:
			# Older versions saved only BEST, not a complete round history.
			top_scores.append(best)
		normalize_top_scores()
		if not top_scores.is_empty():
			best = maxi(best, top_scores[0])
		# Coins and tools now belong to a single cup. Ignore legacy balances.
		lifetime_merges = maxi(0, int(config.get_value("game", "merges", 0)))
		sound.enabled = bool(config.get_value("game", "sound", true))
		sound.restore_music(config)

func save_settings() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("game", "best", best)
	config.set_value("game", "top_scores", top_scores)
	config.set_value("game", "merges", lifetime_merges)
	config.set_value("game", "sound", sound.enabled)
	sound.store_music(config)
	config.save(save_path)

func normalize_top_scores() -> void:
	top_scores.sort()
	top_scores.reverse()
	if top_scores.size() > 3:
		top_scores.resize(3)

func finish_round() -> void:
	# Exactly one entry per completed cup, even if the result UI is revisited.
	if round_recorded:
		return
	round_recorded = true
	top_scores.append(maxi(0, score))
	normalize_top_scores()
	best = maxi(best, score)
	save_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		on_focus_lost()

func on_focus_lost() -> void:
	input_router.cancel()
	pointer_down = false
	if overlay.is_empty() and total_drops > 0 and not show_capture and capture_path.is_empty():
		overlay = "pause"

func _physics_process(delta: float) -> void:
	if not overlay.is_empty():
		return
	var settling := settle_time > 0.0
	settle_time = maxf(0.0, settle_time - delta)
	cooldown = maxf(0.0, cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo = 0
	var axis := float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	if not settling:
		set_aim(aim_x + axis * 310.0 * delta)
	for event in world.step(delta):
		on_merge(event)
	# No countdown at the rim. Only an escaped animal touching ground ends play.
	if not settling:
		var spill_id := world.grounded_spill_id()
		if spill_id != -1:
			enter_game_over(spill_id)

func enter_game_over(spill_id: int) -> void:
	if overlay == "gameover":
		return
	failed_body_id = spill_id
	overlay = "gameover"
	selected_tool = ""
	pointer_down = false
	scores_before_loss = top_scores.duplicate()
	finish_round()
	sound.play_tone(196.0, 0.35)

func request_revive() -> void:
	if overlay == "gameover" and revives_used < REVIVE_LIMIT and failed_body_id != -1:
		rewards.request("revive")

func on_reward_completed(placement: String, _request_id: int) -> void:
	if placement == "revive":
		revive()
	elif placement == "gift" and overlay.is_empty() and settle_time <= 0.0:
		var tool := "hammer" if reward_rng.randf() < 0.6 else "bomb"
		if tool == "hammer":
			hammers += 1
		else:
			bombs += 1
		gifts_claimed += 1
		show_toast("A little gift: +1 " + tool.to_upper() + "!")
		sound.tap()

func revive() -> bool:
	if overlay != "gameover" or revives_used >= REVIVE_LIMIT or failed_body_id == -1:
		return false
	world.clear_for_revive(failed_body_id)
	revives_used += 1
	failed_body_id = -1
	settle_time = SETTLE_SECONDS
	cooldown = maxf(cooldown, SETTLE_SECONDS)
	# The same cup may fail several times, but earns only one Top 3 entry.
	top_scores = scores_before_loss.duplicate()
	round_recorded = false
	selected_tool = ""
	pointer_down = false
	overlay = ""
	save_settings()
	queue_redraw()
	return true

func _process(delta: float) -> void:
	elapsed += delta
	toast_time = maxf(0.0, toast_time - delta)
	if overlay.is_empty():
		for p in particles:
			p.life -= delta
			p.position += p.velocity * delta
			p.velocity.y += 180.0 * delta
		particles = particles.filter(func(p): return p.life > 0.0)
		for p in popups:
			p.life -= delta
			p.position.y -= 28.0 * delta
		popups = popups.filter(func(p): return p.life > 0.0)
	queue_redraw()
	if web_debug:
		web_debug_timer += delta
		if web_debug_timer >= 0.15:
			web_debug_timer = 0.0
			web_input.report(JSON.stringify(debug_state()))
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 90:
			capture_frame.call_deferred()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURE ", result, " ", capture_path, " FPS ", Engine.get_frames_per_second())
	get_tree().quit(result)

func set_aim(x: float) -> void:
	var radius: float = Data.RADII[current_level]
	# Reserve the top-right NEXT card's width even for the larger capybara.
	var right_edge := minf(World.RIGHT_TOP - 8.0, NEXT_RECT.position.x - 10.0)
	aim_x = clampf(x, World.LEFT_TOP + radius + 8.0, right_edge - radius)

func drop_position() -> Vector2:
	# Keep every droppable species just below the top status row, fully visible.
	return Vector2(aim_x, DROP_TOP + Data.RADII[current_level])

func is_play_position(at: Vector2) -> bool:
	if not PLAY_RECT.has_point(at):
		return false
	for rect in [HOME_RECT, HAMMER_RECT, BOMB_RECT, COIN_RECT, SCORE_RECT, BEST_RECT, GIFT_RECT, STATS_RECT, SOUND_RECT, MUSIC_RECT, NEXT_RECT, CHAIN_RECT]:
		if rect.has_point(at):
			return false
	return true

func drop_animal() -> void:
	if cooldown > 0.0 or not overlay.is_empty() or not selected_tool.is_empty() or settle_time > 0.0:
		return
	world.add_animal(current_level, drop_position(), Vector2(0.0, 35.0))
	total_drops += 1
	current_level = next_level
	next_level = Data.random_drop(rng)
	cooldown = 0.55
	set_aim(aim_x)
	sound.drop()

func on_merge(event: Dictionary) -> void:
	combo += 1
	combo_timer = 1.2
	score += event.points
	coins += maxi(1, event.points / 10)
	lifetime_merges += 1
	best = maxi(best, score)
	highest_level = maxi(highest_level, event.level)
	save_settings()
	sound.merge(event.level)
	popups.append({"position": event.position + Vector2(0, -20), "text": "+%d" % event.points, "life": 1.1})
	burst(event.position, Data.COLORS[event.level])

func burst(position: Vector2, color: Color) -> void:
	for i in 18:
		particles.append({"position": position, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(45.0, 150.0), "life": rng.randf_range(0.45, 0.9), "color": color if i % 2 == 0 else Color("fff0c8"), "radius": rng.randf_range(2.0, 4.5)})

func show_toast(message: String, seconds := 2.3) -> void:
	toast = message
	toast_time = seconds

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		input_counts.native_touch += 1
	elif event is InputEventMouseButton:
		input_counts.native_mouse += 1
	if web_bridge_active and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if settle_time > 0.0:
			return
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER:
				if overlay in ["home", "pause", "stats", "help"]:
					overlay = ""
				elif overlay in ["gameover", "restart"]:
					reset_game()
				elif overlay.is_empty():
					drop_animal()
			KEY_ESCAPE, KEY_P:
				if not selected_tool.is_empty():
					selected_tool = ""
				elif overlay in ["pause", "home", "stats", "shop", "help", "restart"]:
					overlay = ""
				elif overlay.is_empty():
					overlay = "pause"
			KEY_R:
				if overlay != "gameover":
					overlay = "restart"
			KEY_M:
				toggle_sound()
	if event is InputEventMouseMotion:
		route_pointer("move", event.position, "mouse", 0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		route_pointer("down" if event.pressed else "up", event.position, "mouse-emulated" if event.device == InputEvent.DEVICE_ID_EMULATION else "mouse", 0)
	elif event is InputEventScreenTouch:
		route_pointer("cancel" if event.canceled else ("down" if event.pressed else "up"), event.position, "touch", event.index)
	elif event is InputEventScreenDrag:
		route_pointer("move", event.position, "touch", event.index)

func route_pointer(phase: String, at: Vector2, source: String, id: int) -> void:
	var action: String = input_router.feed(phase, at, source, id)
	if action == "cancel":
		pointer_down = false
		return
	if settle_time > 0.0:
		pointer_down = false
		return
	match action:
		"down":
			input_counts.accepted_down += 1
			handle_press(at)
		"up":
			handle_release(at)
		"move":
			pointer = at
			if overlay.is_empty() and is_play_position(at):
				set_aim(at.x)

func setup_web_input() -> void:
	web_input = JavaScriptBridge.get_interface("mochiInput")
	if web_input != null:
		web_input_callback = JavaScriptBridge.create_callback(on_web_pointer)
		web_input.connectGame(web_input_callback)
		web_bridge_active = true
		web_debug = bool(web_input.debug)

func on_web_pointer(args: Array) -> void:
	if args.size() < 5:
		return
	input_counts.bridge += 1
	if str(args[0]) == "blur":
		on_focus_lost()
		return
	# The browser supplies current canvas backing pixels; invert Godot's own
	# stretch/letterbox transform instead of assuming fixed CSS dimensions.
	var screen := Vector2(float(args[1]), float(args[2]))
	var local := (get_viewport().get_screen_transform() * get_global_transform_with_canvas()).affine_inverse() * screen
	route_pointer(str(args[0]), local, str(args[3]), int(args[4]))

func debug_state() -> Dictionary:
	var animals: Array = []
	for body in world.bodies:
		animals.append({"id": body.id, "x": body.center.x, "y": body.center.y, "bottom": body.bounds().end.y, "spilled": body.spilled})
	return {"version": "3.0", "inputs": input_counts, "bridge": web_bridge_active, "overlay": overlay, "selected": selected_tool, "coins": coins, "hammers": hammers, "bombs": bombs, "revives": revives_used, "settling": settle_time, "drops": total_drops, "score": score, "music": sound.music_enabled, "sound": sound.enabled, "animals": animals}

func handle_press(position: Vector2) -> void:
	if settle_time > 0.0:
		return
	pointer_down = false
	pointer = position
	if not overlay.is_empty():
		modal_press(position)
		return
	if HOME_RECT.has_point(position):
		overlay = "home"
	elif GIFT_RECT.has_point(position):
		rewards.request("gift")
	elif STATS_RECT.has_point(position):
		overlay = "stats"
	elif SOUND_RECT.has_point(position):
		toggle_sound()
	elif MUSIC_RECT.has_point(position):
		sound.set_music(not sound.music_enabled)
		save_settings()
	elif HAMMER_RECT.has_point(position):
		select_tool("hammer")
	elif BOMB_RECT.has_point(position):
		select_tool("bomb")
	elif COIN_RECT.has_point(position):
		overlay = "shop"
	elif is_play_position(position):
		set_aim(position.x)
		pointer_down = true

func handle_release(position: Vector2) -> void:
	if pointer_down and settle_time <= 0.0 and overlay.is_empty() and is_play_position(position):
		if selected_tool.is_empty():
			set_aim(position.x)
			drop_animal()
		else:
			use_tool(position)
	pointer_down = false

func select_tool(tool: String) -> void:
	if (tool == "hammer" and hammers <= 0) or (tool == "bomb" and bombs <= 0):
		overlay = "shop"
		return
	selected_tool = "" if selected_tool == tool else tool
	if not selected_tool.is_empty():
		show_toast("Tap an animal to " + ("remove it" if tool == "hammer" else "clear nearby friends"))
	sound.tap()

func use_tool(position: Vector2) -> void:
	var target = null
	var closest := INF
	for body in world.bodies:
		var distance: float = body.center.distance_to(position)
		if distance < body.radius + 8.0 and distance < closest:
			closest = distance
			target = body
	if target == null:
		return
	if selected_tool == "hammer" and hammers > 0:
		burst(target.center, Data.COLORS[target.level])
		world.bodies.erase(target)
		world.wake_all()
		hammers -= 1
	elif selected_tool == "bomb" and bombs > 0:
		burst(target.center, Color("d6c3fa"))
		world.remove_near(target.center, 115.0)
		bombs -= 1
	selected_tool = ""
	sound.merge(1)

func modal_press(position: Vector2) -> void:
	if overlay == "shop":
		if SHOP_HAMMER_RECT.has_point(position):
			buy_tool("hammer")
		elif SHOP_BOMB_RECT.has_point(position):
			buy_tool("bomb")
	var primary := SHOP_PRIMARY_RECT if overlay == "shop" else PRIMARY_RECT
	if primary.has_point(position):
		sound.tap()
		if overlay in ["gameover", "restart"]:
			reset_game()
		else:
			overlay = ""
	elif SECONDARY_RECT.has_point(position):
		if overlay in ["home", "pause"]:
			overlay = "restart"
		elif overlay == "restart":
			overlay = "pause"
		elif overlay == "gameover":
			request_revive()

func tool_price(tool: String, after_purchase := false) -> int:
	if not TOOL_PRICES.has(tool):
		return -1
	var index := mini(int(tool_purchases.get(tool, 0)) + int(after_purchase), TOOL_PRICES[tool].size() - 1)
	return TOOL_PRICES[tool][index]

func buy_tool(tool: String) -> bool:
	if not TOOL_PRICES.has(tool):
		return false
	var price := tool_price(tool)
	if coins < price:
		show_toast("Keep merging to earn more coins!")
		return false
	coins -= price
	tool_purchases[tool] += 1
	if tool == "hammer":
		hammers += 1
	else:
		bombs += 1
	save_settings()
	show_toast("One more " + tool + " for this cup!")
	sound.tap()
	return true

func toggle_sound() -> void:
	sound.enabled = not sound.enabled
	save_settings()
	sound.tap()

func label(value: String, center: Vector2, size: int, color := INK, outline := true) -> void:
	var p := center - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0)
	if outline:
		draw_string_outline(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color("fff1d8"))
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color := Color("fff0db")) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d7a27a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	style.shadow_color = Color(0.34, 0.14, 0.06, 0.14)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	draw_style_box(style, rect)

func _draw() -> void:
	set_meta("animal_meshes", [])
	draw_texture_rect(Art.ROOM, Rect2(0, 0, 540, 960), false)
	Art.cup_back(self)
	draw_aim()
	for body in world.bodies:
		if not body.spilled:
			Painter.paint_body(self, body, world)
	Art.cup_front(self)
	for body in world.bodies:
		if body.spilled:
			Painter.paint_body(self, body, world)
	for p in particles:
		draw_circle(p.position, p.radius, Color(p.color, minf(p.life * 2.0, 1.0)), true, -1, true)
	for p in popups:
		label(p.text, p.position, 26, Color("934718"))
	draw_header()
	Art.asset(self, "chain", CHAIN_RECT)
	if total_drops == 0 and overlay.is_empty():
		label("A little cup of happiness", Vector2(265, 480 + World.Layout.SHIFT_Y), 19, Color("a86c4a"))
		label("Match two friends. Meet someone new.", Vector2(265, 505 + World.Layout.SHIFT_Y), 12, Color("a86c4a"))
	if not selected_tool.is_empty() and overlay.is_empty():
		draw_circle(pointer, 115.0 if selected_tool == "bomb" else 28.0, Color(1.0, 0.82, 0.51, 0.22))
		draw_arc(pointer, 115.0 if selected_tool == "bomb" else 28.0, 0, TAU, 64, Color("ffeab1"), 2.0, true)
	if not overlay.is_empty():
		draw_overlay()
	if settle_time > 0.0:
		panel(Rect2(115, 240, 310, 44), Color("fff0d9"))
		label("Getting everyone settled...", Vector2(270, 268), 17)
	if toast_time > 0.0:
		var toast_rect := Rect2(90, 715, 360, 32) if overlay == "shop" else Rect2(18, 284, 386, 30)
		panel(toast_rect, Color("fff0d9"))
		label(toast, toast_rect.get_center() + Vector2(0, 4), 12, INK, false)

func draw_header() -> void:
	Art.asset(self, "home", HOME_RECT)
	Art.asset(self, "hammer", HAMMER_RECT)
	Art.asset(self, "bomb", BOMB_RECT)
	badge(HAMMER_RECT, hammers)
	badge(BOMB_RECT, bombs)
	if selected_tool == "hammer":
		draw_arc(HAMMER_RECT.get_center(), 41, 0, TAU, 64, Color("fff1bd"), 3, true)
	if selected_tool == "bomb":
		draw_arc(BOMB_RECT.get_center(), 41, 0, TAU, 64, Color("fff1bd"), 3, true)
	Art.asset(self, "coin", COIN_RECT)
	Art.patch(self, "coin", COIN_RECT, Rect2(1280, 83, 129, 47), Rect2(1408, 83, 7, 47))
	label(str(coins), COIN_RECT.position + COIN_RECT.size * Vector2(0.50, 0.69), 20)
	Art.asset(self, "score", SCORE_RECT)
	Art.patch(self, "score", SCORE_RECT, Rect2(1133, 258, 264, 73), Rect2(1106, 258, 6, 73))
	label(str(score), SCORE_RECT.position + SCORE_RECT.size * Vector2(0.51, 0.77), 23)
	Art.asset(self, "best", BEST_RECT)
	Art.patch(self, "best", BEST_RECT, Rect2(1220, 429, 185, 57), Rect2(1396, 429, 6, 57))
	label(str(best), BEST_RECT.position + BEST_RECT.size * Vector2(0.63, 0.74), 19)
	Art.asset(self, "next", NEXT_RECT)
	Painter.paint(self, next_level, Art.next_preview_center(NEXT_RECT), Art.next_preview_radius(NEXT_RECT))
	draw_texture_rect(Art.GIFT, GIFT_RECT.grow(2.0), false)
	Art.asset(self, "stats", STATS_RECT)
	Art.asset(self, "sound_on" if sound.enabled else "sound_off", SOUND_RECT)
	Art.asset(self, "music_on" if sound.music_enabled else "music_off", MUSIC_RECT)

func badge(rect: Rect2, count: int) -> void:
	var at := rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.17)
	draw_circle(at, rect.size.x * 0.135, Color("703512"), true, -1, true)
	label(str(count), at + Vector2(0, 4.4), 13, Color.WHITE, false)

func draw_aim() -> void:
	if overlay == "gameover" or cooldown > 0.27 or not selected_tool.is_empty():
		return
	var radius: float = Data.RADII[current_level]
	var endpoint := World.FLOOR_Y
	for body in world.bodies:
		if body.spilled:
			continue
		for i in body.points.size():
			var a: Vector2 = body.points[i]
			var b: Vector2 = body.points[(i + 1) % body.points.size()]
			if aim_x >= minf(a.x, b.x) and aim_x <= maxf(a.x, b.x) and absf(a.x - b.x) > 0.001:
				endpoint = minf(endpoint, lerpf(a.y, b.y, (aim_x - a.x) / (b.x - a.x)))
	var origin := drop_position()
	var line_start := origin.y + radius + 8.0
	# Stop at the first animal even above the rim; never draw a line backwards
	# through an overflowing stack or connect it to the relocated NEXT card.
	if endpoint - 4.0 > line_start:
		draw_dashed_line(Vector2(aim_x, line_start), Vector2(aim_x, endpoint - 4.0), Color(1.0, 0.97, 0.89, 0.8), 2.8, 10.0)
	Painter.paint(self, current_level, origin, radius)
	if combo >= 2 and combo_timer > 0:
		label("%d x COMBO!" % combo, Vector2(265, 203), 17)

func draw_overlay() -> void:
	if overlay == "gallery":
		draw_gallery()
		return
	draw_rect(Rect2(0, 0, 540, 960), Color(0.30, 0.15, 0.09, 0.32))
	panel(Rect2(72, 247, 396, 518))
	var title := "TAKE A LITTLE PAWS"
	var subtitle := "Your little friends can wait."
	match overlay:
		"home":
			title = "MOCHI ANIMALS"
			subtitle = "A little cup of happiness."
		"gameover":
			title = "OOPS! A LITTLE SPILL"
			subtitle = "A friend landed outside the cup."
		"restart":
			title = "A FRESH CUP?"
			subtitle = "Best stays. Coins and tools reset."
		"stats":
			title = "YOUR TOP 3"
			subtitle = "Best cups on this device."
		"shop":
			title = "A LITTLE HELP"
			subtitle = "Trade your coins for a little help."
	Painter.paint(self, 0, Vector2(270, 293), 31, 2 if overlay == "gameover" else 0)
	label(title, Vector2(270, 353), 23)
	label(subtitle, Vector2(270, 382), 13, Color("a47050"), false)
	if overlay == "shop":
		label("%d COINS" % coins, Vector2(270, 418), 21)
		for tool in ["hammer", "bomb"]:
			var rect: Rect2 = SHOP_HAMMER_RECT if tool == "hammer" else SHOP_BOMB_RECT
			Art.asset(self, tool, rect)
			badge(rect, hammers if tool == "hammer" else bombs)
			var price := tool_price(tool)
			var next_price := tool_price(tool, true)
			label("%d coins" % price, Vector2(rect.get_center().x, 539), 15)
			label("Next: %d" % next_price if next_price != price else "Price stays %d" % price, Vector2(rect.get_center().x, 561), 12, Color("a47050"))
	elif overlay == "stats":
		for rank in 3:
			var y := 425.0 + rank * 43.0
			panel(Rect2(118, y - 26, 304, 37), Color("fff7e8"))
			label("#%d" % (rank + 1), Vector2(151, y), 19, Color("bb8049"))
			label(str(top_scores[rank]) if rank < top_scores.size() else "--", Vector2(295, y), 23)
	else:
		label("SCORE", Vector2(181, 429), 15)
		label("BEST", Vector2(359, 429), 15)
		label(str(score), Vector2(181, 467), 30)
		label(str(best), Vector2(359, 467), 30)
		label("Only a friend falling outside", Vector2(270, 506), 13, Color("a47050"), false)
		label("and touching the table ends your game.", Vector2(270, 526), 13, Color("a47050"), false)
	Art.asset(self, "restart" if overlay in ["gameover", "restart"] else "play", SHOP_PRIMARY_RECT if overlay == "shop" else PRIMARY_RECT)
	if overlay in ["pause", "home"]:
		Art.asset(self, "restart", SECONDARY_RECT)
	elif overlay == "gameover":
		var left := REVIVE_LIMIT - revives_used
		panel(SECONDARY_RECT, Color("e4c6f4") if left > 0 else Color("dfd7d0"))
		label("REVIVE" if left > 0 else "NO REVIVES LEFT", SECONDARY_RECT.get_center() + Vector2(0, -2), 25 if left > 0 else 17)
		label("%d LEFT" % left if left > 0 else "Start a fresh cup", SECONDARY_RECT.get_center() + Vector2(0, 22), 12, Color("895c76"), false)
	elif overlay == "restart":
		Art.asset(self, "home_long", SECONDARY_RECT)
	elif overlay == "stats":
		label("Saved after each completed cup.", Vector2(270, 698), 13, Color("ac7958"), false)
		label("%d lifetime merges" % lifetime_merges, Vector2(270, 722), 12, Color("ac7958"), false)
	elif overlay != "shop":
		label("Soft friends. Big little moments.", Vector2(270, 709), 14, Color("ac7958"), false)

func draw_gallery() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("fff1dd"))
	label("ORIGINAL ASSET EXPRESSIONS", Vector2(270, 48), 20)
	for row in 3:
		label(["HAPPY", "SQUEEZED", "SPIRAL EYES + TEARS"][row], Vector2(270, 107 + row * 274), 18)
		for level in Data.NAMES.size():
			var col := level % 5
			var y := 162.0 + row * 274 + (105 if level >= 5 else 0)
			var x := 54.0 + col * 108
			Painter.paint(self, level, Vector2(x, y), 40, row)
			label(Data.NAMES[level], Vector2(x, y + 56), 12)

func seed_sliding_regression() -> void:
	world.clear()
	world.allow_merges = false
	for seed in [[4, 282, 687], [1, 170, 708], [0, 142, 625], [1, 199, 585], [1, 353, 570], [0, 397, 640]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	total_drops = 20
	score = 310
	best = 4380
	current_level = 2
	next_level = 2
	aim_x = 200.0

func seed_revive_preview() -> void:
	# Developer-only fixture; never enabled by a production URL or a saved game.
	world.clear()
	world.allow_merges = false
	for entry in [[5, 280, 415], [1, 200, 330], [3, 200, 730], [2, 340, 720], [0, 505, 850]]:
		var body := World.Body.new(world.next_id, entry[0], Vector2(entry[1], entry[2]))
		world.next_id += 1
		world.bodies.append(body)
	world.bodies[-1].spilled = true
	world.bodies[-1].cup_side = 1
	total_drops = 30
	score = 1500
	coins = 150
	hammers = 2
	bombs = 1
	enter_game_over(world.bodies[-1].id)

func seed_ten_animals() -> void:
	world.clear()
	world.allow_merges = false
	# All new species, final unicorn and earlier species in an actual soft pile.
	for seed in [[9, 257, 663], [0, 145, 746], [1, 376, 742], [8, 175, 481], [7, 354, 477], [6, 260, 277]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	total_drops = 30
	score = 2260
	best = 4380
	current_level = 0
	next_level = 2
	aim_x = 260.0

func seed_overlap_regression() -> void:
	world.clear()
	world.allow_merges = false
	for seed in [[0, 158, 710], [1, 220, 708], [2, 169, 615], [4, 297, 641], [5, 300, 467], [6, 263, 262]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	for frame in 180:
		world.step(1.0 / 60.0)
	total_drops = 20
	score = 860
	best = 4380
	current_level = 1
	next_level = 0
	aim_x = 265.0

func seed_overflow_layout() -> void:
	world.clear()
	world.allow_merges = false
	for seed in [[6, 240, 662], [5, 355, 463], [4, 175, 436], [1, 382, 705], [2, 253, 285], [1, 118, 309]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	for frame in 90:
		world.step(1.0 / 60.0)
	total_drops = 20
	score = 860
	best = 4380
	current_level = 1
	next_level = 0
	aim_x = 265.0

func seed_wall_regression() -> void:
	world.clear()
	world.allow_merges = false
	for seed in [[0, 158, 615], [1, 164, 704], [4, 275, 669], [1, 387, 712]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	for frame in 180:
		world.step(1.0 / 60.0)
	total_drops = 10
	aim_x = 410.0

func seed_showcase() -> void:
	world.allow_merges = false
	for seed in [[5, 255, 646], [4, 349, 459], [3, 176, 471], [1, 272, 360], [0, 143, 354]]:
		world.add_animal(seed[0], Vector2(seed[1], seed[2]))
	for i in 100:
		world.step(1.0 / 60.0)
	world.allow_merges = true
	score = 480
	best = 1480
	coins = 48
	highest_level = 5
	total_drops = 14
	current_level = 0
	next_level = 2
	aim_x = 265
