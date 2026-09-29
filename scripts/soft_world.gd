extends RefCounted
## Deterministic, fixed-step 2D soft-body solver. No external physics plugin.

const Body = preload("res://scripts/soft_body.gd")
const Data = preload("res://scripts/animal_data.gd")
const CUP_TOP := 358.0
const FLOOR_Y := 756.0
const LEFT_TOP := 68.0
const RIGHT_TOP := 458.0
const TAPER := 0.125
const GROUND_Y := 808.0
const WALL_RADIUS := 4.0
const WALL_NORMAL_LENGTH := 1.00778221854 # sqrt(1 + TAPER * TAPER)
var bodies: Array[Body] = []
var contacts: Array = []
var next_id := 1
var allow_merges := true
var squeeze := 0.0

func add_animal(level: int, position: Vector2, velocity := Vector2.ZERO) -> Body:
	var body := Body.new(next_id, level, position, velocity)
	next_id += 1
	body.cup_side = -1 if position.x < left_at(position.y) else (1 if position.x > right_at(position.y) else 0)
	# A newborn can be larger than the free space left by its parents. Apply the
	# solid cup before exposing even its first frame to physics or rendering.
	walls(body)
	update_spill_state(body)
	bodies.append(body)
	return body

func clear() -> void:
	bodies.clear()
	contacts.clear()
	next_id = 1
	squeeze = 0.0

func left_at(y: float) -> float:
	return LEFT_TOP + maxf(0.0, y - CUP_TOP) * TAPER + squeeze

func right_at(y: float) -> float:
	return RIGHT_TOP - maxf(0.0, y - CUP_TOP) * TAPER - squeeze

func step(delta: float) -> Array:
	contacts.clear()
	var contacted_pairs := {}
	var dt := delta * 0.5
	for substep in 2:
		for body in bodies:
			body.integrate(dt)
		var pairs: Array = []
		for i in bodies.size():
			for j in range(i + 1, bodies.size()):
				var a: Body = bodies[i]
				var b: Body = bodies[j]
				if a.center.distance_squared_to(b.center) < pow((a.radius + b.radius) * 1.28, 2.0):
					pairs.append([a, b])
		for iteration in 5:
			for body in bodies:
				body.solve_shape()
			for pair in pairs:
				if collide(pair[0], pair[1]):
					pair[0].contacted = true
					pair[1].contacted = true
					var pair_key := Vector2i(pair[0].id, pair[1].id)
					if not contacted_pairs.has(pair_key):
						contacted_pairs[pair_key] = true
						contacts.append(pair)
			for body in bodies:
				walls(body)
	for body in bodies:
		body.update_expression(delta)
		update_spill_state(body)
	return merge_contacts() if allow_merges else []

func walls(body: Body) -> void:
	# Finite, two-sided walls have round tips at the rim. There is NO invisible
	# guide above the rim: a loaded cup can push an animal up and over either lip.
	body.update_center()
	advance_cup_side(body)
	var left_start := Vector2(LEFT_TOP + squeeze, CUP_TOP)
	var right_start := Vector2(RIGHT_TOP - squeeze, CUP_TOP)
	var left_end := Vector2(left_at(FLOOR_Y), FLOOR_Y)
	var right_end := Vector2(right_at(FLOOR_Y), FLOOR_Y)
	segment_collision(body, left_start, left_end)
	segment_collision(body, right_start, right_end)
	segment_collision(body, left_end, right_end)
	# Proximity/sweeps handle the rounded rim, while this unilateral constraint
	# recovers ANY penetration depth. Never infer the wall side from a point that
	# an animal collision or a merge may already have pushed through the wall.
	for i in Body.COUNT:
		var p := body.points[i]
		var corrected := constrain_to_cup(p, body.cup_side)
		var correction := corrected - p
		if correction.length_squared() < 0.0000001:
			continue
		var normal := correction.normalized()
		var motion := p - body.previous[i]
		var normal_motion := motion.dot(normal)
		if normal_motion < 0.0:
			motion -= normal * normal_motion
		body.points[i] = corrected
		# Shift both Verlet states to avoid injecting energy during deep recovery.
		body.previous[i] = corrected - motion * 0.94
		body.contacted = true
	body.update_center()
	body.boundary_center = body.center

func constrain_to_cup(point: Vector2, side: int) -> Vector2:
	var p := point
	if p.y < CUP_TOP:
		return p
	if side == 0:
		# Floor first; the inward wall normals also point upward, so corner
		# correction cannot reintroduce floor penetration.
		p.y = minf(p.y, FLOOR_Y - WALL_RADIUS)
		var left_distance := (p.x - left_at(p.y)) / WALL_NORMAL_LENGTH
		if left_distance < WALL_RADIUS:
			p += Vector2(1.0, -TAPER) / WALL_NORMAL_LENGTH * (WALL_RADIUS - left_distance)
		var right_distance := (right_at(p.y) - p.x) / WALL_NORMAL_LENGTH
		if right_distance < WALL_RADIUS:
			p += Vector2(-1.0, -TAPER) / WALL_NORMAL_LENGTH * (WALL_RADIUS - right_distance)
	elif p.y <= FLOOR_Y:
		# A legitimate spill stays on the exterior face of the finite wall and
		# can fall below the cup. It is never pulled back through the glass.
		if side < 0:
			var distance := (left_at(p.y) - p.x) / WALL_NORMAL_LENGTH
			if distance < WALL_RADIUS:
				p += Vector2(-1.0, TAPER) / WALL_NORMAL_LENGTH * (WALL_RADIUS - distance)
		else:
			var distance := (p.x - right_at(p.y)) / WALL_NORMAL_LENGTH
			if distance < WALL_RADIUS:
				p += Vector2(1.0, TAPER) / WALL_NORMAL_LENGTH * (WALL_RADIUS - distance)
	return p

func crosses_above_rim(before: Vector2, after: Vector2, rim_x: float) -> bool:
	if before.y < CUP_TOP - WALL_RADIUS and after.y < CUP_TOP - WALL_RADIUS:
		return true
	var dx := after.x - before.x
	if absf(dx) < 0.00001:
		return false
	var t := (rim_x - before.x) / dx
	return t >= 0.0 and t <= 1.0 and lerpf(before.y, after.y, t) < CUP_TOP - WALL_RADIUS

func advance_cup_side(body: Body) -> void:
	var before := body.boundary_center
	var after := body.center
	var left := LEFT_TOP + squeeze
	var right := RIGHT_TOP - squeeze
	if body.cup_side < 0 and after.x >= left and crosses_above_rim(before, after, left):
		body.cup_side = 0
	elif body.cup_side > 0 and after.x <= right and crosses_above_rim(before, after, right):
		body.cup_side = 0
	if body.cup_side == 0:
		if after.x < left and crosses_above_rim(before, after, left):
			body.cup_side = -1
		elif after.x > right and crosses_above_rim(before, after, right):
			body.cup_side = 1

func render_outline(body: Body) -> PackedVector2Array:
	# Cubic smoothing can overshoot valid particles at a hard contact. Limit only
	# that interpolation overshoot using the same solid boundary as physics.
	var outline := body.smooth_outline()
	for i in outline.size():
		outline[i] = constrain_to_cup(outline[i], body.cup_side)
	return outline

func segment_collision(body: Body, start: Vector2, end: Vector2) -> void:
	var axis := end - start
	var axis_length := axis.length_squared()
	var perpendicular := Vector2(-axis.y, axis.x).normalized()
	for i in Body.COUNT:
		var p: Vector2 = body.points[i]
		var old: Vector2 = body.previous[i]
		var t := (p - start).dot(axis) / axis_length
		var closest := start + axis * clampf(t, 0.0, 1.0)
		var separation := p - closest
		var distance := separation.length()
		var signed_now := (p - start).dot(perpendicular)
		var signed_before := (old - start).dot(perpendicular)
		var crossed := signed_now * signed_before < 0.0 and t > 0.0 and t < 1.0
		# Check the swept intersection, so a particle can travel around a rim tip.
		if crossed:
			var crossing_fraction := signed_before / (signed_before - signed_now)
			var crossing := old.lerp(p, crossing_fraction)
			var crossing_t := (crossing - start).dot(axis) / axis_length
			crossed = crossing_t > 0.0 and crossing_t < 1.0
		if distance >= WALL_RADIUS and not crossed:
			continue
		var normal := separation.normalized() if distance > 0.001 else perpendicular
		if crossed:
			normal = perpendicular * (1.0 if signed_before >= 0.0 else -1.0)
		body.points[i] = closest + normal * WALL_RADIUS
		body.contacted = true
		var velocity := p - old
		var vn := velocity.dot(normal)
		if vn < 0.0:
			velocity -= normal * vn * 1.04
		body.previous[i] = body.points[i] - velocity * 0.94

func update_spill_state(body: Body) -> void:
	body.spilled = body.cup_side != 0

func has_grounded_spill() -> bool:
	for body in bodies:
		if not body.spilled:
			continue
		for p in body.points:
			if p.y >= GROUND_Y and (p.x < left_at(FLOOR_Y) or p.x > right_at(FLOOR_Y)):
				return true
	return false

func collide(a: Body, b: Body) -> bool:
	if not a.bounds().grow(1.5).intersects(b.bounds()):
		return false
	var hit := collide_vertices(a, b)
	return collide_vertices(b, a) or hit

func collide_vertices(a: Body, b: Body) -> bool:
	var touched := false
	var bounds: Rect2 = b.bounds().grow(0.8)
	# The polygon's outward normals are shared by all point queries.
	var normals := PackedVector2Array()
	for j in Body.COUNT:
		var edge: Vector2 = b.points[(j + 1) % Body.COUNT] - b.points[j]
		normals.append(Vector2(edge.y, -edge.x).normalized())
	for i in Body.COUNT:
		var p: Vector2 = a.points[i]
		if not bounds.has_point(p):
			continue
		var best_distance := -INF
		var best_edge := 0
		var best_normal := Vector2.ZERO
		var outside := false
		for j in Body.COUNT:
			var normal := normals[j]
			var distance: float = (p - b.points[j]).dot(normal)
			if distance > 0.6:
				outside = true
				break
			if distance > best_distance:
				best_distance = distance
				best_edge = j
				best_normal = normal
		if outside:
			continue
		touched = true
		if best_distance >= 0.4:
			continue
		var next_edge := (best_edge + 1) % Body.COUNT
		var edge: Vector2 = b.points[next_edge] - b.points[best_edge]
		var t := clampf((p - b.points[best_edge]).dot(edge) / maxf(edge.length_squared(), 0.001), 0.0, 1.0)
		var wa: float = a.inverse_mass
		var wb: float = b.inverse_mass
		var denominator: float = wa + wb * ((1.0 - t) * (1.0 - t) + t * t)
		var correction := best_normal * minf(0.5 - best_distance, 14.0) * 0.97 / denominator
		a.points[i] += correction * wa
		b.points[best_edge] -= correction * wb * (1.0 - t)
		b.points[next_edge] -= correction * wb * t
	return touched

func merge_contacts() -> Array:
	var events: Array = []
	for pair in contacts:
		var a: Body = pair[0]
		var b: Body = pair[1]
		if a.dead or b.dead or a.spilled or b.spilled or a.level != b.level or a.level >= Data.LAST_LEVEL:
			continue
		if a.age < 0.16 or b.age < 0.16:
			continue
		a.dead = true
		b.dead = true
		var position: Vector2 = (a.center + b.center) * 0.5
		var new_level: int = a.level + 1
		var r: float = Data.RADII[new_level]
		position.y = minf(position.y, FLOOR_Y - r)
		events.append({"level": new_level, "position": position, "points": Data.POINTS[new_level]})
	if not events.is_empty():
		bodies = bodies.filter(func(body: Body): return not body.dead)
		for event in events:
			var baby = add_animal(event.level, event.position, Vector2(0.0, -65.0))
			baby.born_scale = 0.85
	return events

func remove_near(position: Vector2, radius: float) -> int:
	var count := bodies.size()
	bodies = bodies.filter(func(body: Body): return body.center.distance_to(position) > radius)
	return count - bodies.size()
