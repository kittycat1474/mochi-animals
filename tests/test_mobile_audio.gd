extends SceneTree

const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func touch(game: Node, position: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = index
	game._input(event)

func mouse(game: Node, position: Vector2, pressed: bool, emulated := true) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	game._input(event)

func tap_with_compatibility_mouse(game: Node, position: Vector2, mouse_first: bool) -> void:
	if mouse_first:
		mouse(game, position, true)
		mouse(game, position, false)
	touch(game, position, true)
	touch(game, position, false)
	if not mouse_first:
		mouse(game, position, true)
		mouse(game, position, false)
	# Browser compatibility clicks can arrive without Godot's emulation ID.
	mouse(game, position, true, false)
	mouse(game, position, false, false)

func test_tools(game: Node) -> void:
	for tool in ["hammer", "bomb"]:
		for mouse_first in [false, true]:
			game.reset_game()
			game.input_router.cancel()
			game.coins = 600
			game.world.add_animal(0, Vector2(250, 700))
			game.world.add_animal(1, Vector2(320, 700))
			var button: Vector2 = (Main.HAMMER_RECT if tool == "hammer" else Main.BOMB_RECT).get_center()
			var shop_button: Vector2 = (Main.SHOP_HAMMER_RECT if tool == "hammer" else Main.SHOP_BOMB_RECT).get_center()
			tap_with_compatibility_mouse(game, button, mouse_first)
			check(game.overlay == "shop", "empty %s opens shop via touch" % tool)
			tap_with_compatibility_mouse(game, shop_button, mouse_first)
			check(game.coins == 600 - Main.TOOL_PRICES[tool][0] and game.tool_purchases[tool] == 1, "%s purchase charges once per touch" % tool)
			tap_with_compatibility_mouse(game, Main.SHOP_PRIMARY_RECT.get_center(), mouse_first)
			check(game.overlay.is_empty(), "shop closes without unwanted action")
			tap_with_compatibility_mouse(game, button, mouse_first)
			check(game.selected_tool == tool, "%s stays selected despite compatibility mouse" % tool)
			tap_with_compatibility_mouse(game, Vector2(270, 500), mouse_first)
			check(game.selected_tool == tool and (game.hammers if tool == "hammer" else game.bombs) == 1, "empty-space touch preserves tool and inventory")
			tap_with_compatibility_mouse(game, Vector2(250, 700), mouse_first)
			check(game.world.bodies.size() == (1 if tool == "hammer" else 0), "%s touch removes the intended animal(s)" % tool)
			check(game.selected_tool.is_empty() and (game.hammers if tool == "hammer" else game.bombs) == 0, "%s consumes exactly one charge" % tool)
			check(game.total_drops == 0, "using %s never drops an extra animal" % tool)

func run() -> void:
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	print("Touch mouse emulation: ", ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	for music in [false, true]:
		var position: Vector2 = (Main.MUSIC_RECT if music else Main.SOUND_RECT).get_center()
		var label := "music" if music else "sound"
		for mouse_first in [false, true]:
			game.input_router.cancel()
			game.sound.enabled = true
			game.sound.set_music(true)
			if mouse_first:
				mouse(game, position, true)
				mouse(game, position, false)
			touch(game, position, true)
			touch(game, position, false)
			if not mouse_first:
				mouse(game, position, true)
				mouse(game, position, false)
			check(not (game.sound.music_enabled if music else game.sound.enabled), "%s stays off with emulated mouse %s touch" % [label, "before" if mouse_first else "after"])
			check(game.sound.enabled if music else game.sound.music_enabled, "other audio setting stays on")
			if music:
				check(not game.sound.music_player.playing, "music really stops without being restarted")
			# Deliberate second tap enables once; additional finger cannot toggle.
			touch(game, position, true)
			touch(game, position, true, 1)
			touch(game, position, false, 1)
			touch(game, position, false)
			check(game.sound.music_enabled if music else game.sound.enabled, "second tap enables %s; extra finger ignored" % label)
			game.input_router.last_finished = -1000
			mouse(game, position, true, false)
			mouse(game, position, false, false)
			check(not (game.sound.music_enabled if music else game.sound.enabled), "physical mouse still toggles %s" % label)
	game.reset_game()
	var before: int = game.total_drops
	touch(game, Vector2(260, 180), true)
	touch(game, Vector2(260, 180), false)
	game.cooldown = 0.0
	mouse(game, Vector2(260, 180), true)
	mouse(game, Vector2(260, 180), false)
	check(game.total_drops == before + 1, "one touch plus compatibility mouse drops only one animal")
	test_tools(game)
	game.free()
	print("MOBILE AUDIO: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
