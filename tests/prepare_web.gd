extends SceneTree

func _initialize() -> void:
	var directory := "res://builds/Web-v3"
	var base := directory.path_join("mochi-v30")
	assert(FileAccess.file_exists(base + ".html"))
	assert(DirAccess.copy_absolute(base + ".html", directory.path_join("index.html")) == OK)
	assert(DirAccess.copy_absolute("res://assets/loading/static-cover.webp", directory.path_join("loading-static-v2.webp")) == OK)
	assert(DirAccess.copy_absolute("res://web/input-v3.js", directory.path_join("input-v3.js")) == OK)
	# Browsers need a tiny favicon, not the full-resolution artwork from Godot.
	var icon := Image.load_from_file("res://assets/app-icon-512.png")
	assert(icon != null)
	icon.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	assert(icon.save_png(base + ".icon.png") == OK)
	print("Web shell, optimized cover and 64px favicon prepared.")
	quit()
