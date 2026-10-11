extends SceneTree

const Main = preload("res://scripts/main.gd")
const Art = preload("res://scripts/asset_art.gd")
const Data = preload("res://scripts/animal_data.gd")
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

func run() -> void:
	check(Art.NEXT_CAPSULE.get_size() == Vector2(977, 1610), "approved NEXT capsule texture is loaded")
	check(absf(Main.NEXT_RECT.size.aspect() - Art.NEXT_REGION.size.aspect()) < 0.00001, "capsule is uniformly scaled without distortion")
	check(Main.NEXT_RECT.end.x == 528 and Main.NEXT_RECT.position.y == 80 and Main.NEXT_RECT.size.y == 106, "NEXT retains the previous top/right anchors and height")
	check(Main.NEXT_RECT.size.x < 61 and Main.NEXT_RECT.end.y < Main.GIFT_RECT.position.y, "narrow capsule and hit area stay above the gift button")
	var img := Art.NEXT_CAPSULE.get_image()
	if img.is_compressed():
		img.decompress()
	check(img.get_pixel(0, 0).a < 0.01 and img.get_pixelv(Art.NEXT_PREVIEW_CENTER).a < 0.01, "outside background and animal window retain transparent alpha")
	var preview_fits := true
	for i in 48:
		var p: Vector2 = Art.NEXT_PREVIEW_CENTER + Vector2.from_angle(TAU * i / 48.0) * Art.NEXT_PREVIEW_RADIUS
		preview_fits = preview_fits and img.get_pixelv(Vector2i(p)).a < 0.1
	check(preview_fits, "dynamic animal outline fits within the transparent window")
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.sound.set_music(false)
	var aiming_clear := true
	for level in 4:
		game.current_level = level
		game.set_aim(1000)
		var radius: float = Data.RADII[level]
		var bounds := Rect2(game.drop_position() - Vector2.ONE * radius, Vector2.ONE * 2 * radius)
		aiming_clear = aiming_clear and absf(bounds.end.x - 450.0) < 0.001 and not bounds.intersects(Main.NEXT_RECT)
	check(aiming_clear, "unchanged aim logic clears the narrower NEXT across all four drop species")
	game.handle_press(Main.NEXT_RECT.get_center())
	game.handle_release(Main.NEXT_RECT.get_center())
	check(game.total_drops == 0, "capsule remains display-only")
	game.reset_game()
	check(game.current_level == 1 and game.coins == 0 and game.hammers == 0 and game.bombs == 0 and game.tool_price("hammer") == 200 and game.tool_price("bomb") == 350, "opening animal and zero-balance economy start correctly")
	game.free()
	await process_frame
	print("NEXT CAPSULE: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
