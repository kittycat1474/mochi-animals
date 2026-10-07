extends SceneTree

const Main = preload("res://scripts/main.gd")
const Loading = preload("res://scripts/loading.gd")
const World = preload("res://scripts/soft_world.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func make_game(path := "") -> Node2D:
	var game := Main.new()
	game.persistence_enabled = not path.is_empty()
	if not path.is_empty():
		game.save_path = path
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.sound.set_music(false)
	return game

func run() -> void:
	var game = make_game()
	check(game.top_scores.is_empty(), "fresh install has three empty positions, not invented scores")
	for points in [100, 500, 300, 200, 500]:
		game.reset_game()
		game.score = points
		game.finish_round()
	check(game.top_scores == [500, 500, 300], "top three are descending and equal scores from different cups count")
	game.finish_round()
	check(game.top_scores == [500, 500, 300], "repeated finish cannot record the same cup twice")
	game.reset_game()
	game.score = 9999
	game.reset_game()
	check(game.top_scores == [500, 500, 300], "abandoned/restarted cups do not enter completed-cup records")
	game.score = 700
	game.on_merge({"level": 1, "points": 10, "position": Vector2(270, 600)})
	check(game.top_scores == [500, 500, 300] and game.best == 710, "live BEST still updates but leaderboard waits for round completion")
	# Exercise the actual overflow loss route, not only the helper.
	var escaped = game.world.add_animal(0, Vector2(15, World.GROUND_Y + 80))
	escaped.spilled = true
	game._physics_process(1.0 / 60.0)
	check(game.overlay == "gameover" and game.top_scores == [710, 500, 500], "outside-ground game over records a result automatically")
	game._physics_process(1.0 / 60.0)
	check(game.top_scores == [710, 500, 500], "further game-over frames never duplicate a score")
	game.reset_game()
	check(game.top_scores == [710, 500, 500] and game.coins == 0 and game.current_level == 1, "restart preserves records while clearing round economy")
	check(Main.CHAIN_RECT.end.y < 952 and Main.CHAIN_RECT.position.y > World.GROUND_Y + 10, "bottom strip has safe margin and clears translated cup ground")
	check(World.CUP_TOP == 425 and World.FLOOR_Y == 823 and World.GROUND_Y == 875, "rim, floor and outside ground all moved down 24 pixels")
	game.free()

	var path := "/private/tmp/mochi-top3-%d.cfg" % Time.get_ticks_usec()
	var legacy := ConfigFile.new()
	legacy.set_value("game", "best", 5432)
	legacy.set_value("game", "music", false)
	check(legacy.save(path) == OK, "isolated legacy fixture created")
	game = make_game(path)
	check(game.top_scores == [5432] and game.best == 5432, "legacy BEST is migrated as one known record")
	game.score = 6000
	game.finish_round()
	game.free()
	game = make_game(path)
	check(game.top_scores == [6000, 5432] and game.best == 6000, "top three and BEST survive a fresh game instance")
	game.reset_game()
	game.finish_round()
	check(game.top_scores == [6000, 5432, 0], "zero-point completed cup is a valid score")
	game.free()
	legacy.set_value("game", "top_scores", [200, "bad", -8, 700, 900, 400])
	legacy.save(path)
	game = make_game(path)
	check(game.top_scores == [900, 700, 400] and game.best == 5432, "malformed entries are ignored and valid entries sorted and capped")
	game.free()
	DirAccess.remove_absolute(path)

	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/loading.tscn", "normal startup opens the loading scene")
	check(Loading.SHEET.get_size() == Vector2(1206, 1305), "original supplied loading sheet is used")
	for rect in [Loading.BACKGROUND, Loading.LOGO, Loading.BRIDGE, Loading.BAR_EMPTY, Loading.BAR_FILL]:
		check(Rect2(Vector2.ZERO, Loading.SHEET.get_size()).encloses(rect), "loading atlas region fits inside original sheet")
	var loader := Loading.new()
	root.add_child(loader)
	loader.set_process(false)
	loader.capture_loading = true
	for i in 300:
		await process_frame
		loader._process(1.0 / 60.0)
		if loader.progress == 1.0 or loader.load_error:
			break
	check(loader.progress == 1.0 and not loader.load_error, "threaded main-scene loading reaches real completion")
	check(not loader.changing, "loading screenshot mode does not change scenes or touch saves")
	loader.free()
	await process_frame
	print("LOADING / RECORDS: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
