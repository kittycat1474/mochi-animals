extends RefCounted
## Deterministic, fixed-step 2D soft-body solver. No external physics plugin.

const Body = preload("res://scripts/soft_body.gd")
const Data = preload("res://scripts/animal_data.gd")
const Layout = preload("res://scripts/cup_layout.gd")
const CUP_TOP := 358.0 + Layout.SHIFT_Y
const FLOOR_Y := 756.0 + Layout.SHIFT_Y
const LEFT_TOP := 68.0
const RIGHT_TOP := 458.0
const TAPER := 0.125
const GROUND_Y := 808.0 + Layout.SHIFT_Y
const WALL_RADIUS := 4.0
const WALL_NORMAL_LENGTH := 1.00778221854 # sqrt(1 + TAPER * TAPER)
const MERGE_UPWARD_SPEED := 0.0
const CONTACT_GAP := 1.2
const CONTACT_SLOP := 0.002
const SEPARATION_PASSES := 32
const RELAXATION_TOLERANCE := 0.04
var bodies: Array[Body] = []
var contacts: Array = []
var next_id := 1
var allow_merges := true
var squeeze := 0.0
var contact_normals: Dictionary = {}
var validated_contacts: Dictionary = {}
var contact_epoch := 0
var largest_correction := 0.0
var sat_tests := 0
var warm_contacts := 0
var relaxation_passes := 0
var candidate_members: Array[Body] = []
var candidate_envelopes: Array[Rect2] = []
var candidate_pairs: Array = []

func add_animal(level: int, position: Vector2, velocity := Vector2.ZERO) -> Body:
	contact_epoch += 1
	var body := Body.new(next_id, level, position, velocity)
	next_id += 1
	body.cup_side = -1 if position.x < left_at(position.y) else (1 if position.x > right_at(position.y) else 0)
	# A newborn can be larger than the free space left by its parents. Apply the
	# solid cup before exposing even its first frame to physics or rendering.
	walls(body)
	update_spill_state(body)
	bodies.append(body)
	# Merges and drops must be valid before their very first rendered frame.
	separate_contacts()
	return body

func clear() -> void:
	bodies.clear()
	contacts.clear()
	next_id = 1
	squeeze = 0.0
	contact_normals.clear()
	validated_contacts.clear()
	candidate_members.clear()
	candidate_envelopes.clear()
	candidate_pairs.clear()

func left_at(y: float) -> float:
	return LEFT_TOP + maxf(0.0, y - CUP_TOP) * TAPER + squeeze

func right_at(y: float) -> float:
	return RIGHT_TOP - maxf(0.0, y - CUP_TOP) * TAPER - squeeze

func step(delta: float) -> Array:
	contacts.clear()
	contact_epoch += 1
	var frame_points: Dictionary = {}
	var frame_centers: Dictionary = {}
	var active := false
	for body in bodies:
		frame_points[body.id] = body.points.duplicate()
		frame_centers[body.id] = body.center
		active = active or not body.sleeping
	if not active:
		return []
	var contacted_pairs := {}
	var dt := delta * 0.5
	for substep in 2:
		for body in bodies:
			body.integrate(dt)
		for iteration in 5:
			for body in bodies:
				body.solve_shape()
			# Rebuild from the actual deformed bounds, including shape/area changes.
			for pair in contact_candidates():
				if collide(pair[0], pair[1]):
					pair[0].contacted = true
					pair[1].contacted = true
					var pair_key := Vector2i(pair[0].id, pair[1].id)
					if not contacted_pairs.has(pair_key):
						contacted_pairs[pair_key] = true
						contacts.append(pair)
			for body in bodies:
				walls(body)
		# Shape recovery and another neighbour can reopen an earlier contact.
		# Finish with unilateral constraints only, never a subsequent shape pass.
		separate_contacts()
		for body in bodies:
			body.damp_contact_motion()
	for body in bodies:
		body.update_expression(delta)
		update_spill_state(body)
	update_sleep(delta, frame_points, frame_centers)
	return merge_contacts() if allow_merges else []

func walls(body: Body) -> void:
	if body.sleeping:
		return
	# Finite, two-sided walls have round tips at the rim. There is NO invisible
	# guide above the rim: a loaded cup can push an animal up and over either lip.
	body.update_center()
	advance_cup_side(body)
	var bounds := body.bounds()
	var bottom := bounds.end.y
	if body.cup_side == 0 and bottom <= FLOOR_Y - WALL_RADIUS and bounds.position.x >= left_at(bottom) + WALL_RADIUS * WALL_NORMAL_LENGTH and bounds.end.x <= right_at(bottom) - WALL_RADIUS * WALL_NORMAL_LENGTH:
		body.boundary_center = body.center
		return
	# Away from the open rim, the ownership-preserving half-spaces below are
	# already the exact hard constraints (including arbitrarily deep sweeps).
	# Only tips/exterior motion need the more expensive finite capsule sweeps.
	if body.cup_side != 0 or bounds.position.y <= CUP_TOP + WALL_RADIUS:
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
		body.previous[i] = corrected - motion
		largest_correction = maxf(largest_correction, correction.length())
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
	# The rounding stays inside the physics hull; it cannot overshoot a contact.
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
		largest_correction = maxf(largest_correction, body.points[i].distance_to(p))
		body.contacted = true
		var velocity := p - old
		var vn := velocity.dot(normal)
		if vn < 0.0:
			velocity -= normal * vn # Zero restitution: slide along glass, no bounce.
		body.previous[i] = body.points[i] - velocity

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
	if a.sleeping and b.sleeping:
		return false
	if not a.bounds().grow(CONTACT_GAP).intersects(b.bounds()):
		return false
	a.update_center()
	b.update_center()
	var direction := b.center - a.center
	var pair_key := Vector2i(a.id, b.id)
	var cached_normal: Vector2 = contact_normals.get(pair_key, Vector2.ZERO)
	# Test the last separating axis before building any hulls. Warm contacts
	# may reuse their plane only after a full SAT validation this physics frame,
	# and only for small corrections; impacts/deep changes still use full SAT.
	var cached_a := -INF
	var cached_b := INF
	if cached_normal.dot(direction) > 0.0:
		for p in a.points:
			cached_a = maxf(cached_a, p.dot(cached_normal))
		for p in b.points:
			cached_b = minf(cached_b, p.dot(cached_normal))
		var cached_depth := cached_a - cached_b + CONTACT_GAP
		if cached_depth < -CONTACT_SLOP:
			return false
		if validated_contacts.get(pair_key, -1) == contact_epoch and cached_depth <= 2.0:
			warm_contacts += 1
			resolve_contact(a, b, cached_normal, cached_a, cached_b)
			return true
	sat_tests += 1
	var axes := PackedVector2Array([direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT])
	# Hull support intervals remain valid even when the soft contour is concave.
	# A shared separating plane also catches edge/edge crossings and containment;
	# vertex-inside tests cannot provide that guarantee for a squashed ring.
	for body in [a, b]:
		var hull := Geometry2D.convex_hull(body.points)
		for i in range(hull.size() - 1):
			var edge := hull[i + 1] - hull[i]
			if edge.length_squared() > 0.001:
				axes.append(Vector2(edge.y, -edge.x).normalized())
	var normal := Vector2.ZERO
	var best_depth := INF
	var best_a := 0.0
	var best_b := 0.0
	if cached_normal != Vector2.ZERO:
		axes.insert(0, cached_normal)
	for axis in axes:
		if axis.dot(direction) < 0.0:
			axis = -axis
		var support_a := -INF
		var support_b := INF
		for p in a.points:
			support_a = maxf(support_a, p.dot(axis))
		for p in b.points:
			support_b = minf(support_b, p.dot(axis))
		var depth := support_a - support_b + CONTACT_GAP
		if depth < -CONTACT_SLOP:
			# Cache separating axes as well as touching ones. Dense bounds often
			# overlap at empty corners; do not rebuild both hulls for each pass.
			contact_normals[pair_key] = axis
			validated_contacts.erase(pair_key)
			return false
		if axis == cached_normal:
			cached_a = support_a
			cached_b = support_b
		if depth < best_depth:
			best_depth = depth
			normal = axis
			best_a = support_a
			best_b = support_b
	# Retain an existing contact plane through tiny hull-edge changes. Choosing
	# a different minimum axis every iteration makes a soft pile chatter.
	if cached_normal != Vector2.ZERO and cached_normal.dot(direction) > 0.0 and cached_a - cached_b + CONTACT_GAP < best_depth + 0.1:
		normal = cached_normal
		best_a = cached_a
		best_b = cached_b
		best_depth = best_a - best_b + CONTACT_GAP
	contact_normals[pair_key] = normal
	validated_contacts[pair_key] = contact_epoch
	resolve_contact(a, b, normal, best_a, best_b)
	return true

func resolve_contact(a: Body, b: Body, normal: Vector2, best_a: float, best_b: float) -> void:
	if best_a - best_b + CONTACT_GAP <= CONTACT_SLOP:
		return
	if a.sleeping or b.sleeping:
		# A new load wakes the entire supported pile, not just its top animal.
		wake_all()
	# Only contacting particles flatten against the shared plane. Non-contacting
	# particles remain free to bulge sideways through the area constraint.
	var plane := lerpf(best_a, best_b, a.inverse_mass / (a.inverse_mass + b.inverse_mass))
	var half_gap := CONTACT_GAP * 0.5
	# Balance the mass-weighted correction of ALL contacting particles. Using
	# only the two extreme points makes a many-to-one soft contact seesaw.
	var projections_a := PackedFloat32Array()
	var projections_b := PackedFloat32Array()
	for i in Body.COUNT:
		projections_a.append(a.points[i].dot(normal))
		projections_b.append(b.points[i].dot(normal))
	for iteration in 8:
		var balance := 0.0
		var weight := 0.0
		for i in Body.COUNT:
			var da := projections_a[i] - plane + half_gap
			var db := plane + half_gap - projections_b[i]
			if da > 0.0:
				balance += da / a.inverse_mass
				weight += 1.0 / a.inverse_mass
			if db > 0.0:
				balance -= db / b.inverse_mass
				weight += 1.0 / b.inverse_mass
		var adjustment := balance / maxf(weight, 0.001)
		plane += adjustment
		if absf(adjustment) < 0.0001:
			break
	for i in Body.COUNT:
		var da := projections_a[i] - plane + half_gap
		var db := plane + half_gap - projections_b[i]
		if da > 0.0:
			project_contact(a, i, -normal, da)
		if db > 0.0:
			project_contact(b, i, normal, db)
	a.contacted = true
	b.contacted = true

func project_contact(body: Body, index: int, normal: Vector2, depth: float) -> void:
	if depth <= 0.0:
		return
	largest_correction = maxf(largest_correction, depth)
	var motion := body.points[index] - body.previous[index]
	# Deep recovery is positional, not an extra launch impulse. Remove inward
	# velocity while retaining sliding along the contact surface.
	var inward := motion.dot(normal)
	if inward < 0.0:
		motion -= normal * inward
	body.points[index] += normal * depth
	body.previous[index] = body.points[index] - motion

func contact_candidates() -> Array:
	var bounds: Array[Rect2] = []
	var reusable := candidate_members == bodies
	for body in bodies:
		bounds.append(body.bounds().grow(CONTACT_GAP))
	if reusable:
		for i in bodies.size():
			if not candidate_envelopes[i].encloses(bounds[i]):
				reusable = false
				break
	if reusable:
		return candidate_pairs
	# Fat bounds are conservative, not stale: test containment on every query.
	# Rebuild immediately after a large deformation, new body or removal.
	# This avoids an O(n²) pair-list allocation on every solver iteration.
	candidate_members = bodies.duplicate()
	candidate_envelopes.clear()
	candidate_pairs.clear()
	for rect in bounds:
		candidate_envelopes.append(rect.grow(6.0))
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			if candidate_envelopes[i].intersects(candidate_envelopes[j]):
				candidate_pairs.append([bodies[i], bodies[j]])
	return candidate_pairs

func separate_contacts() -> void:
	for iteration in SEPARATION_PASSES:
		relaxation_passes += 1
		largest_correction = 0.0
		for pair in contact_candidates():
			collide(pair[0], pair[1])
		for body in bodies:
			walls(body)
		if largest_correction < RELAXATION_TOLERANCE:
			break

func wake_all() -> void:
	# IDs are never reused within a game. Discard retired pair caches after
	# merges/tools, so long games do not accumulate obsolete contact records.
	var live_ids := {}
	for body in bodies:
		live_ids[body.id] = true
		body.sleeping = false
		body.quiet_time = 0.0
	for key in contact_normals.keys():
		if not live_ids.has(key.x) or not live_ids.has(key.y):
			contact_normals.erase(key)
			validated_contacts.erase(key)

func update_sleep(delta: float, frame_points: Dictionary, frame_centers: Dictionary) -> void:
	# Sleep a connected, floor-supported island only after every animal in it
	# is quiet. Airborne animals and unsupported piles must never freeze.
	var neighbours: Dictionary = {}
	for body in bodies:
		neighbours[body.id] = []
	for pair in contacts:
		neighbours[pair[0].id].append(pair[1])
		neighbours[pair[1].id].append(pair[0])
	var visited: Dictionary = {}
	for root in bodies:
		if visited.has(root.id) or root.sleeping:
			continue
		var island: Array[Body] = [root]
		visited[root.id] = true
		var cursor := 0
		while cursor < island.size():
			for neighbour in neighbours[island[cursor].id]:
				if not visited.has(neighbour.id):
					visited[neighbour.id] = true
					island.append(neighbour)
			cursor += 1
		var supported := false
		var quiet := true
		var quiet_duration := INF
		for body in island:
			quiet_duration = minf(quiet_duration, body.quiet_time)
			quiet = quiet and not body.spilled and body.age > 0.8 and body.signed_area() > body.rest_area * 0.97
			quiet = quiet and body.center.distance_to(frame_centers[body.id]) < 1.5 * delta
			var before: PackedVector2Array = frame_points[body.id]
			for i in Body.COUNT:
				quiet = quiet and body.points[i].distance_to(before[i]) < 9.0 * delta
				if body.cup_side == 0 and body.points[i].y >= FLOOR_Y - WALL_RADIUS - 0.1:
					supported = true
		quiet_duration = quiet_duration + delta if quiet and supported else 0.0
		for body in island:
			body.quiet_time = quiet_duration
			if quiet_duration >= 0.8:
				body.sleeping = true
				body.previous = body.points.duplicate()

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
		# Keep the parents' midpoint. A soft newborn can flatten against the floor;
		# snapping it up by its full circular radius causes an artificial jump.
		events.append({"level": new_level, "position": position, "points": Data.POINTS[new_level]})
	if not events.is_empty():
		bodies = bodies.filter(func(body: Body): return not body.dead)
		wake_all()
		for event in events:
			var baby = add_animal(event.level, event.position, Vector2(0.0, -MERGE_UPWARD_SPEED))
			baby.born_scale = 0.85
	return events

func remove_near(position: Vector2, radius: float) -> int:
	var count := bodies.size()
	bodies = bodies.filter(func(body: Body): return body.center.distance_to(position) > radius)
	if bodies.size() != count:
		wake_all()
	return count - bodies.size()
