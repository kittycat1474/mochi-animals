extends SceneTree

const Main = preload("res://scripts/main.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--render-output="):
			output = arg.trim_prefix("--render-output=")
	if output.is_empty():
		printerr("Pass -- --showcase --render-output=/absolute/existing/directory")
		quit(1)
		return
	var game := Main.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.seed_sliding_regression()
	game.aim_x = 200
	var resting: Image
	var resting_meshes: Array = []
	for frame in 480:
		game.world.step(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [30, 90, 180, 359, 479]:
			var shot := root.get_texture().get_image()
			if shot.save_png(output.path_join("frame-%03d.png" % frame)) != OK:
				printerr("Could not save rendered frame")
				quit(1)
				return
			# Compare the whole cup region, excluding HUD and mouse-driven aim.
			var scale_by := Vector2(shot.get_size()) / Vector2(540, 960)
			var crop := shot.get_region(Rect2i(Vector2(90, 485 + game.world.Layout.SHIFT_Y) * scale_by, Vector2(365, 300) * scale_by))
			if frame == 359:
				resting = crop
				for body in game.world.bodies:
					resting_meshes.append(body.artwork_mesh)
			elif frame == 479:
				var same := resting.get_data() == crop.get_data()
				print("RENDER CHECK: resting cup pixels identical over 120 more physics frames: ", same)
				if not same:
					quit(1)
					return
				for i in game.world.bodies.size():
					if resting_meshes[i] != game.world.bodies[i].artwork_mesh:
						printerr("Static animal rebuilt its cached mesh")
						quit(1)
						return
				print("RENDER CHECK: all stationary animals reuse their GPU meshes")
	game.queue_free()
	await process_frame
	print("RESULT: actual Compatibility-renderer frame sequence saved; stationary pixels are identical")
	quit(0)
