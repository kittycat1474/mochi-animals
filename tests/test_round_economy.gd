extends SceneTree

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/animal_data.gd")
const Art = preload("res://scripts/asset_art.gd")
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

func new_game() -> Node2D:
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.sound.set_music(false)
	return game

func run() -> void:
	test_layout_and_spawning()
	test_economy()
	test_reset_paths()
	test_persistence()
	await process_frame
	print("ROUND ECONOMY: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func test_layout_and_spawning() -> void:
	check(Main.NEXT_RECT.end.y < Main.GIFT_RECT.position.y and Main.NEXT_RECT.end.x == Main.GIFT_RECT.end.x, "NEXT is directly above the right-hand gift column")
	check(Main.CHAIN_RECT.position.x == 12 and Main.CHAIN_RECT.end.x == 528 and Main.CHAIN_RECT.end.y < 952, "evolution strip spans the bottom width with a safe screen margin")
	check(Art.CHAIN.get_size() == Vector2(2172, 724) and absf(Main.CHAIN_RECT.size.aspect() - Art.CHAIN_REGION.size.aspect()) < 0.001, "latest attachment is sampled without stretching the animals")
	var game = new_game()
	check(game.current_level == 1 and game.world.bodies.is_empty(), "new game always starts with one waiting chick and an empty cup")
	var opening_ok := true
	var saw_capybara := false
	for i in 500:
		game.reset_game()
		opening_ok = opening_ok and game.current_level == 1 and game.next_level in [0, 1, 2, 3]
		saw_capybara = saw_capybara or game.next_level == 3
	check(opening_ok and saw_capybara, "every restart keeps the opening chick but NEXT includes capybaras")
	var rng := RandomNumberGenerator.new()
	rng.seed = 280010
	var counts := [0, 0, 0, 0]
	for i in 100000:
		counts[Data.random_drop(rng)] += 1
	for level in 4:
		check(abs(counts[level] - (10000 if level == 3 else 30000)) < 600, "%s probability is correct in 100,000 seeded rolls (%d)" % [Data.NAMES[level], counts[level]])
	var aim_clear := true
	for level in 4:
		game.current_level = level
		for side in [-1000, 1000]:
			game.set_aim(side)
			var radius: float = Data.RADII[level]
			var bounds := Rect2(game.drop_position() - Vector2.ONE * radius, Vector2.ONE * radius * 2)
			aim_clear = aim_clear and not bounds.intersects(Main.NEXT_RECT) and bounds.position.y >= Main.DROP_TOP
	check(aim_clear, "all four waiting species clear NEXT at both aim extremes")
	game.reset_game()
	game.next_level = 3
	game.drop_animal()
	check(game.world.bodies[0].level == 1 and game.current_level == 3, "opening chick drops first and capybara advances from NEXT")
	game.cooldown = 0.0
	game.drop_animal()
	check(game.world.bodies[1].level == 3 and game.world.bodies[1].radius == 72, "capybara is dropped at its unchanged physical size")
	game.reset_game()
	for rect in [Main.NEXT_RECT, Main.CHAIN_RECT]:
		game.handle_press(Vector2(250, 180))
		game.handle_release(rect.get_center())
		game.handle_press(rect.get_center())
		game.handle_release(rect.get_center())
	check(game.total_drops == 0, "NEXT and bottom strip never accidentally release an animal")
	game.handle_press(Main.GIFT_RECT.get_center())
	check(game.overlay.is_empty() and game.hammers + game.bombs == 1, "gift below NEXT awards exactly one tool without pausing")
	game.free()

func test_economy() -> void:
	var game = new_game()
	check(game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.tool_purchases == {"hammer": 0, "bomb": 0}, "fresh round has no coins or tools and fresh price stages")
	game.handle_press(Main.HAMMER_RECT.get_center())
	check(game.overlay == "shop" and game.selected_tool.is_empty(), "empty hammer button opens the exchange shop")
	game.coins = 99
	game.modal_press(Main.SHOP_HAMMER_RECT.get_center())
	check(game.coins == 99 and game.hammers == 0 and game.tool_price("hammer") == 200, "failed hammer purchase changes neither coins nor price stage")
	game.coins = 179
	game.modal_press(Main.SHOP_BOMB_RECT.get_center())
	check(game.coins == 179 and game.bombs == 0 and game.tool_price("bomb") == 350, "failed bomb purchase changes neither coins nor price stage")
	check(not game.buy_tool("unknown") and game.coins == 179, "invalid tool cannot deduct coins")
	game.coins = 200
	game.modal_press(Main.SHOP_HAMMER_RECT.get_center())
	check(game.coins == 0 and game.hammers == 1 and game.tool_price("hammer") == 300, "shop hammer costs exactly 200 and advances its price")
	game.coins = 350
	game.modal_press(Main.SHOP_BOMB_RECT.get_center())
	check(game.coins == 0 and game.bombs == 1 and game.tool_price("bomb") == 500, "shop bomb costs exactly 350 and advances its price")
	game.modal_press(Main.SHOP_PRIMARY_RECT.get_center())
	check(game.overlay.is_empty(), "shop PLAY resumes the same cup without resetting inventory")
	for tool in ["hammer", "bomb"]:
		game.world.clear()
		game.world.add_animal(0, Vector2(270, 600))
		game.select_tool(tool)
		game.use_tool(Vector2(270, 600))
		check(game.world.bodies.is_empty() and game.tool_purchases[tool] == 1, "using the purchased %s does not reset its price" % tool)
	game.reset_game()
	var total_reward := 0
	for level in range(1, Data.NAMES.size()):
		var before: int = game.coins
		game.on_merge({"level": level, "points": Data.POINTS[level], "position": Vector2(270, 600)})
		var reward: int = maxi(1, Data.POINTS[level] / 10)
		total_reward += reward
		check(game.coins - before == reward, "merging %s keeps its %d-coin reward" % [Data.NAMES[level], reward])
	check(game.coins == total_reward and game.best == game.score, "merge rewards accumulate during the cup and BEST still updates")
	game.reset_game()
	game.coins = 10000
	for tool in ["hammer", "bomb"]:
		var all_bought := true
		for i in 6:
			check(game.tool_price(tool) == Main.TOOL_PRICES[tool][mini(i, 3)], "%s purchase %d has the correct capped price" % [tool, i + 1])
			all_bought = game.buy_tool(tool) and all_bought
		var balance: int = game.coins
		check(all_bought and game.tool_purchases[tool] == 6, "six %s purchases succeed, no per-round quota" % tool)
		for i in 6:
			game.world.clear()
			game.world.add_animal(0, Vector2(270, 600))
			game.select_tool(tool)
			game.use_tool(Vector2(270, 600))
		check(game.coins == balance and (game.hammers if tool == "hammer" else game.bombs) == 0, "all six %s items can be used without changing coins" % tool)
	check(game.coins == 3300, "six of each tool charge exactly 6700 coins")
	game.free()

func test_reset_paths() -> void:
	var game = new_game()
	game.best = 5000
	for mode in ["restart", "gameover"]:
		for keyboard in [false, true]:
			game.coins = 999
			game.hammers = 2
			game.bombs = 1
			game.tool_purchases = {"hammer": 3, "bomb": 3}
			game.overlay = mode
			if keyboard:
				var event := InputEventKey.new()
				event.pressed = true
				event.physical_keycode = KEY_ENTER
				game._input(event)
			else:
				game.modal_press(Main.PRIMARY_RECT.get_center())
			check(game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.tool_price("hammer") == 200 and game.tool_price("bomb") == 350 and game.current_level == 1 and game.best == 5000, "%s via %s starts a zero-balance chick round and keeps BEST" % [mode, "keyboard" if keyboard else "button"])
	game.coins = 80
	game.overlay = "home"
	game.modal_press(Main.PRIMARY_RECT.get_center())
	check(game.coins == 80 and game.overlay.is_empty(), "resuming the current cup from HOME does not reset earned coins")
	game.free()

func test_persistence() -> void:
	# A unique or caller-provided test save never touches the player's real save.
	var path := OS.get_environment("MOCHI_TEST_SAVE_PATH")
	if path.is_empty():
		path = OS.get_user_data_dir().path_join("round-economy-test-%d.cfg" % Time.get_ticks_usec())
	var legacy := ConfigFile.new()
	legacy.set_value("game", "best", 5432)
	legacy.set_value("game", "coins", 99999)
	legacy.set_value("game", "sound", false)
	check(legacy.save(path) == OK, "isolated legacy-save fixture was created")
	var game := Main.new()
	game.save_path = path
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.set_music(false)
	check(game.best == 5432 and game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.current_level == 1, "legacy saved coins are ignored while BEST is restored on launch")
	game.best = 6789
	game.coins = 450
	game.buy_tool("hammer")
	game.save_settings()
	var saved := ConfigFile.new()
	saved.load(path)
	check(saved.get_value("game", "best") == 6789 and not saved.has_section_key("game", "coins") and not saved.has_section_key("game", "hammers"), "save persists BEST without carrying a round balance or inventory forward")
	game.free()
	game = Main.new()
	game.save_path = path
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.set_music(false)
	check(game.best == 6789 and game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.tool_price("hammer") == 200, "relaunch keeps the latest BEST but resets all round economy")
	game.free()
	DirAccess.remove_absolute(path)
