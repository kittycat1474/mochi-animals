extends Node2D
## Startup-only artwork; the gameplay renderer never references this sheet.
const SHEET = preload("res://assets/loading/sheet.png")
const GAME_PATH := "res://scenes/main.tscn"
const BACKGROUND := Rect2(12, 377, 448, 910)
const LOGO := Rect2(1, 43, 498, 265)
const BRIDGE := Rect2(478, 416, 727, 313)
const BAR_EMPTY := Rect2(480, 976, 263, 64)
const BAR_FILL := Rect2(756, 990, 198, 31)
const UNICORNS := [Rect2(481, 774, 170, 130), Rect2(652, 774, 163, 130), Rect2(829, 774, 165, 130), Rect2(998, 774, 183, 130)]
const BAR_RECT := Rect2(65, 735, 410, 100)
const FILL_RECT := Rect2(92, 763, 276, 42)

var progress := 0.0
var elapsed := 0.0
var ready_elapsed := 0.0
var load_error := false
var changing := false
var capture_path := ""
var capture_frames := 0
var capture_loading := false
var font := SystemFont.new()

func _ready() -> void:
	get_window().title = "Mochi Animals — v2.9"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial"])
	font.font_weight = 700
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-mode=loading":
			capture_loading = true
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	load_error = ResourceLoader.load_threaded_request(GAME_PATH) != OK

func _process(delta: float) -> void:
	elapsed += delta
	if not load_error and not changing:
		var measured: Array = []
		var status := ResourceLoader.load_threaded_get_status(GAME_PATH, measured)
		if not measured.is_empty():
			progress = maxf(progress, clampf(float(measured[0]), 0.0, 1.0))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			progress = 1.0
			ready_elapsed += delta
			# Brief presentation hold, never fabricated loading percentages.
			if elapsed >= 1.2 and ready_elapsed >= 0.25 and not capture_loading:
				changing = true
				enter_game.call_deferred()
		elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			load_error = true
	queue_redraw()
	if capture_loading and not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 90:
			capture.call_deferred()

func enter_game() -> void:
	var scene := ResourceLoader.load_threaded_get(GAME_PATH) as PackedScene
	if scene == null or get_tree().change_scene_to_packed(scene) != OK:
		load_error = true
		changing = false
		queue_redraw()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	print("LOADING CAPTURE ", result, " ", capture_path)
	get_tree().quit(result)

func atlas(region: Rect2, destination: Rect2) -> void:
	draw_texture_rect_region(SHEET, destination, region)

func _draw() -> void:
	# Sample the supplied combined sheet directly; no asset pixels are modified.
	atlas(BACKGROUND, Rect2(0, 0, 540, 960))
	atlas(LOGO, Rect2(74, 106, 392, 209))
	atlas(BRIDGE, Rect2(-5, 499, 550, 237))
	atlas(BAR_EMPTY, BAR_RECT)
	if progress > 0.0:
		atlas(Rect2(BAR_FILL.position, Vector2(BAR_FILL.size.x * progress, BAR_FILL.size.y)), Rect2(FILL_RECT.position, Vector2(FILL_RECT.size.x * progress, FILL_RECT.size.y)))
	var frame := int(elapsed * 7.0) % UNICORNS.size()
	var hop := absf(sin(elapsed * 5.0)) * 5.0
	atlas(UNICORNS[frame], Rect2(55 + progress * 291, 696 - hop, 112, 86))
	var message := "Loading..." if not load_error else "Unable to load. Please reopen the game."
	var size := 23 if not load_error else 16
	var at := Vector2(270 - font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 848)
	draw_string_outline(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color("713b27"))
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff7e8"))
