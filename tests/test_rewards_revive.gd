extends SceneTree

const Main = preload("res://scripts/main.gd")
const World = preload("res://scripts/soft_world.gd")
const Router = preload("res://scripts/pointer_router.gd")
const Gateway = preload("res://scripts/reward_gateway.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", description)

func fixture(world, id: int, tier: int, at: Vector2):
	var body := World.Body.new(id, tier, at)
	body.update_center()
	world.bodies.append(body)
	return body

func test_outline() -> void:
	var world := World.new()
	var failed = fixture(world, 1, 0, Vector2(505, World.GROUND_Y))
	failed.spilled = true
	fixture(world, 2, 1, Vector2(220, World.CUP_TOP - 100)) # Fully above.
	var dog = fixture(world, 3, 5, Vector2(300, World.CUP_TOP - 30)) # Partly inside.
	fixture(world, 4, 0, Vector2(160, World.CUP_TOP - 39)) # Exactly touching.
	fixture(world, 5, 0, Vector2(280, 720)) # Normal in-cup ball.
	var squished = fixture(world, 6, 5, Vector2(310, World.CUP_TOP - 70))
	for i in World.Body.COUNT:
		squished.points[i].y = squished.center.y + sin(TAU * i / World.Body.COUNT) * 40
	# Nominal dog radius reaches below the rim, but its actual squashed shape does not.
	var removed: Array = world.clear_for_revive(1)
	check(removed == [1, 2, 6], "remove failed ID + fully-above actual outlines, not nominal radii")
	check(world.bodies.size() == 3 and dog in world.bodies, "partly inside large dog, touching rim, and normal ball survive")
	check(world.contacts.is_empty() and world.validated_contacts.is_empty(), "revive invalidates stale collision caches")
	check(world.grounded_spill_id() == -1, "the specific grounded escapee is gone")

func test_router() -> void:
	for origin in ["mouse", "mouse-emulated", "touch", "pointer-touch", "pointer-mouse", "pointer-pen"]:
		var router := Router.new()
		var at := Vector2(100, 100)
		check(router.feed("down", at, origin, 7, 100) == "down" and router.feed("up", at, origin, 7, 105) == "up", origin + " works alone, with no other event stream")
		check(router.feed("down", at, origin, 7, 120) == "down" and router.feed("up", at, origin, 7, 125) == "up", origin + " allows a rapid second genuine tap")
	var router := Router.new()
	var at := Vector2(200, 200)
	check(router.feed("down", at, "pointer-touch", 2, 100) == "down", "pointer starts a gesture")
	check(router.feed("down", at, "touch", 4, 101).is_empty(), "parallel touch is deduplicated")
	check(router.feed("down", at, "pointer-touch", 3, 101).is_empty(), "second finger is ignored")
	check(router.feed("up", at, "pointer-touch", 2, 110) == "up", "primary finger completes once")
	check(router.feed("up", at, "touch", 4, 111).is_empty() and router.feed("up", at, "pointer-touch", 3, 112).is_empty(), "ignored releases do not act")
	check(router.feed("down", at, "mouse", 0, 115).is_empty() and router.feed("up", at, "mouse", 0, 120).is_empty(), "compatibility mouse is deduplicated")
	check(router.feed("down", at, "pointer-touch", 2, 130) == "down", "primary stream accepts next rapid tap")
	check(router.feed("cancel", at, "pointer-touch", 2, 140) == "cancel", "cancel never becomes a release/drop")
	router.cancel()
	check(router.feed("down", at, "mouse", 0, 141) == "down", "focus reset cannot leave a stuck finger")

func test_rewards(game) -> void:
	game.reset_game()
	game.reward_rng.seed = 301060
	# Stop tiny synthesized effects while sampling; no world/score/save mutations.
	for i in 10000:
		game.rewards.request("gift")
	check(game.hammers + game.bombs == 10000 and abs(game.hammers - 6000) < 160, "10,000 seeded gifts give one tool each with 60/40 distribution (%d/%d)" % [game.hammers, game.bombs])
	check(game.coins == 0 and game.score == 0 and game.tool_price("hammer") == 200 and game.tool_price("bomb") == 350, "gifts do not spend coins, award points or raise purchase prices")
	var inventory: int = game.hammers + game.bombs
	game.rewards.complete(game.rewards.next_id, true)
	check(game.hammers + game.bombs == inventory, "duplicate earned-reward callback cannot award twice")
	game.rewards.pending_id = 99999
	game.rewards.pending_placement = "gift"
	game.rewards.complete(99999, false)
	check(game.hammers + game.bombs == inventory, "cancelled/failed future ad awards nothing")
	game.rewards.pending_id = 99998
	game.rewards.pending_placement = "gift"
	game.reset_game()
	game.rewards.complete(99998, true)
	check(game.hammers + game.bombs == 0, "new round invalidates late reward callbacks")

func test_revive(game) -> void:
	game.reset_game()
	game.top_scores.assign([1200, 1000, 500])
	game.seed_revive_preview()
	game.top_scores.assign([1500, 1200, 1000])
	game.scores_before_loss.assign([1200, 1000, 500])
	game.tool_purchases = {"hammer": 2, "bomb": 1}
	var current: int = game.current_level
	var next: int = game.next_level
	var doomed: int = game.failed_body_id
	game.request_revive()
	check(game.overlay.is_empty() and game.revives_used == 1 and game.settle_time == 1.0, "test REVIVE immediately starts one-second settling")
	var release := InputEventScreenTouch.new()
	release.position = Main.SECONDARY_RECT.get_center()
	release.pressed = false
	game.input_router.feed("down", release.position, "touch", 0)
	game._input(release)
	check(game.input_router.source.is_empty(), "native touch release is consumed while settling; no stuck first tap")
	check(game.world.bodies.size() == 3 and not game.world.bodies.any(func(b): return b.id == doomed), "revive removes escaped hamster and fully-above chick only")
	check(game.score == 1500 and game.coins == 150 and game.hammers == 2 and game.bombs == 1 and game.tool_purchases == {"hammer": 2, "bomb": 1}, "revive retains score, coins, inventory and purchase stages")
	check(game.current_level == current and game.next_level == next, "revive retains current and NEXT animals")
	check(game.top_scores == [1200, 1000, 500] and not game.round_recorded, "reviving retracts provisional Top 3 entry for this same cup")
	var drops: int = game.total_drops
	game.drop_animal()
	game.handle_press(Main.GIFT_RECT.get_center())
	check(game.total_drops == drops and game.hammers + game.bombs == 3, "settling blocks drops and gift clicks")
	var old_y: float = game.world.bodies[0].center.y
	game._physics_process(0.016)
	check(game.world.bodies[0].center.y != old_y and game.overlay.is_empty(), "physics continues during settling; game-over checks are suspended")
	for i in 65:
		game._physics_process(1.0 / 60.0)
	check(game.settle_time == 0, "settling ends without a blocking timer")
	for cycle in 2:
		var body = fixture(game.world, 100 + cycle, 0, Vector2(505, World.GROUND_Y))
		body.spilled = true
		game.enter_game_over(body.id)
		game.request_revive()
		game.settle_time = 0
	check(game.revives_used == 3, "exactly three revives are available per cup")
	game.enter_game_over(game.world.bodies[0].id)
	var before: int = game.world.bodies.size()
	game.request_revive()
	check(game.overlay == "gameover" and game.world.bodies.size() == before and game.revives_used == 3, "fourth revive is unavailable and leaves the result unchanged")
	check(game.top_scores == [1500, 1200, 1000], "repeated game overs do not create duplicate Top 3 records")
	game.reset_game()
	check(game.revives_used == 0 and game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.tool_price("hammer") == 200, "new cup resets revives, economy and prices")

func run() -> void:
	test_outline()
	test_router()
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.sound.set_music(false)
	test_rewards(game)
	test_revive(game)
	game.free()
	await process_frame
	print("REWARDS / REVIVE / INPUT: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
