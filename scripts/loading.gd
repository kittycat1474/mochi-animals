extends Node2D
## A static illustration remains visible until gameplay is ready.
const COVER = preload("res://assets/loading/static-cover.webp")
const GAME_PATH := "res://scenes/main.tscn"
var progress := 0.0
var load_error := false
var changing := false
var capture_path := ""
var capture_frames := 0
var capture_loading := false
var notice: Label
var progress_bar: ProgressBar

func _ready() -> void:
	get_window().title = "Mochi Animals — v2.9"
	var foreground := TextureRect.new()
	foreground.texture = COVER
	foreground.size = Vector2(540, 960)
	foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foreground)
	# The Web shell owns its download bar; never stack a second bar beneath it.
	if not OS.has_feature("web"):
		progress_bar = ProgressBar.new()
		progress_bar.position = Vector2(75, 860)
		progress_bar.size = Vector2(390, 16)
		progress_bar.show_percentage = false
		progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kind in ["background", "fill"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("fff0e9" if kind == "background" else "f397b4")
			style.set_corner_radius_all(8)
			progress_bar.add_theme_stylebox_override(kind, style)
		add_child(progress_bar)
	notice = Label.new()
	notice.position = Vector2(25, 820)
	notice.size = Vector2(490, 70)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.text = "Unable to load. Please reopen the game."
	notice.add_theme_color_override("font_color", Color("713b27"))
	notice.add_theme_color_override("font_outline_color", Color("fff7e8"))
	notice.add_theme_constant_override("outline_size", 5)
	notice.hide()
	add_child(notice)
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-mode=loading":
			capture_loading = true
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	load_error = ResourceLoader.load_threaded_request(GAME_PATH) != OK

func _process(_delta: float) -> void:
	if not load_error and not changing:
		var measured: Array = []
		var status := ResourceLoader.load_threaded_get_status(GAME_PATH, measured)
		if not measured.is_empty():
			progress = clampf(float(measured[0]), 0.0, 1.0)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			progress = 1.0
			if not capture_loading:
				changing = true
				enter_game.call_deferred()
		elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			load_error = true
	notice.visible = load_error
	if progress_bar != null:
		progress_bar.value = progress * 100.0
		progress_bar.visible = not load_error
	if load_error and OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new Event('mochi-load-error'))")
		set_process(false)
	if capture_loading and not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 90:
			capture.call_deferred()

func enter_game() -> void:
	var scene := ResourceLoader.load_threaded_get(GAME_PATH) as PackedScene
	if scene == null or get_tree().change_scene_to_packed(scene) != OK:
		load_error = true
		changing = false

func capture() -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	print("LOADING CAPTURE ", result, " ", capture_path)
	get_tree().quit(result)
