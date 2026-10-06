extends SceneTree

const World = preload("res://scripts/soft_world.gd")
const Painter = preload("res://scripts/sprite_painter.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for side in [-1, 1]:
		var world := World.new()
		world.allow_merges = false
		var x := world.left_at(430) + 41 if side < 0 else world.right_at(430) - 41
		var slider = world.add_animal(0, Vector2(x, 430), Vector2(side * 100, 100))
		var at_half_second := 0.0
		var arrival := -1.0
		for frame in 240:
			world.step(1.0 / 60.0)
			if frame == 29:
				at_half_second = slider.center.y
			if arrival < 0 and slider.center.y >= 700:
				arrival = (frame + 1) / 60.0
		print("WALL side=", side, " y@0.5s=", at_half_second, " time to y700=", arrival)
	for count in [10, 20, 30]:
		var world := World.new()
		world.allow_merges = false
		for i in count:
			world.add_animal(i % 2, Vector2(109 + (i % 5) * 76, 705 - (i / 5) * 84))
		var samples: Array[float] = []
		var total := 0.0
		for frame in 240:
			var start := Time.get_ticks_usec()
			world.step(1.0 / 60.0)
			var ms := (Time.get_ticks_usec() - start) / 1000.0
			samples.append(ms)
			total += ms
		samples.sort()
		print("PERF bodies=", count, " mean_ms=", total / samples.size(), " p95_ms=", samples[int(samples.size() * 0.95)], " asleep=", world.bodies.filter(func(b): return b.sleeping).size(), " SAT=", world.sat_tests, " warm=", world.warm_contacts, " relaxation=", world.relaxation_passes)
	quit()
