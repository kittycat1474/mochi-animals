extends RefCounted
## A closed deformable particle ring, with edge, shape and area constraints.
## These same particles are the collision outline AND the rendered silhouette.

const Data = preload("res://scripts/animal_data.gd")
const COUNT := 20
const SHAPE_STIFFNESS := 0.005
const EDGE_STIFFNESS := 0.075
const AREA_STIFFNESS := 0.65
var id: int
var level: int
var radius: float
var inverse_mass: float
var points := PackedVector2Array()
var previous := PackedVector2Array()
var rest := PackedVector2Array()
var center := Vector2.ZERO
var geometry_points := PackedVector2Array()
var geometry_bounds := Rect2()
var rest_area: float
var edge_length: float
var age := 0.0
var pressure := 0.0
var expression := 0
var spilled := false
# Boundary ownership is independent of Verlet history. Only passage above the
# rim may change it: -1 = outside left, 0 = inside, +1 = outside right.
var cup_side := 0
var boundary_center := Vector2.ZERO
var contacted := false
var dead := false
var born_scale := 1.0
var sleeping := false
var quiet_time := 0.0
# A body owns its artwork cache, so merging/removing it releases the mesh too.
var artwork_mesh: ArrayMesh
var artwork_points := PackedVector2Array()
var artwork_expression := -1
var artwork_side := 0
var artwork_squeeze := 0.0

func _init(body_id: int = 0, tier: int = 0, origin: Vector2 = Vector2.ZERO, velocity: Vector2 = Vector2.ZERO) -> void:
	id = body_id
	level = clampi(tier, 0, Data.LAST_LEVEL)
	radius = Data.RADII[level]
	inverse_mass = 1.0 / pow(radius / 39.0, 2.0)
	center = origin
	boundary_center = origin
	for i in COUNT:
		var offset := Vector2.from_angle(TAU * float(i) / COUNT) * radius
		rest.append(offset)
		points.append(origin + offset)
		previous.append(origin + offset - velocity / 120.0)
	rest_area = signed_area()
	edge_length = rest[0].distance_to(rest[1])

func signed_area() -> float:
	var total := 0.0
	for i in COUNT:
		total += points[i].cross(points[(i + 1) % COUNT])
	return total * 0.5

func update_center() -> void:
	if geometry_points == points:
		return
	center = Vector2.ZERO
	geometry_bounds = Rect2(points[0], Vector2.ZERO)
	for p in points:
		center += p
		geometry_bounds = geometry_bounds.expand(p)
	center /= COUNT
	geometry_points = points.duplicate()

func integrate(dt: float) -> void:
	age += dt
	if sleeping:
		return
	contacted = false
	var average_motion := Vector2.ZERO
	for i in COUNT:
		average_motion += points[i] - previous[i]
	average_motion /= COUNT
	for i in COUNT:
		var current := points[i]
		var motion := (current - previous[i]).lerp(average_motion, 0.18) * 0.997
		motion = motion.limit_length(900.0 * dt)
		points[i] += motion + Vector2(0.0, 1150.0 * dt * dt)
		previous[i] = current
	update_center()

func solve_shape() -> void:
	if sleeping:
		return
	update_center()
	# Rotation-invariant shape memory: it restores a circle without pinning it.
	var dot_sum := 0.0
	var cross_sum := 0.0
	for i in COUNT:
		var offset := points[i] - center
		dot_sum += rest[i].dot(offset)
		cross_sum += rest[i].cross(offset)
	var angle := atan2(cross_sum, dot_sum)
	var rotation := Transform2D(angle, center)
	for i in COUNT:
		points[i] += (rotation * rest[i] - points[i]) * SHAPE_STIFFNESS
	# Stretchable edges keep the contour closed, while permitting local dents.
	for i in COUNT:
		var j := (i + 1) % COUNT
		var edge := points[j] - points[i]
		var length := edge.length()
		if length > 0.001:
			var correction := edge * ((length - edge_length) / length) * EDGE_STIFFNESS
			points[i] += correction
			points[j] -= correction
	# Area preservation supplies the soft, incompressible mochi response.
	var gradients := PackedVector2Array()
	var denominator := 0.0
	for i in COUNT:
		var tangent := points[(i + 1) % COUNT] - points[(i + COUNT - 1) % COUNT]
		var gradient := Vector2(tangent.y, -tangent.x) * 0.5
		gradients.append(gradient)
		denominator += gradient.length_squared()
	if denominator > 0.001:
		var multiplier := clampf((rest_area - signed_area()) / denominator, -0.8, 0.8) * AREA_STIFFNESS
		for i in COUNT:
			points[i] += gradients[i] * multiplier

func damp_contact_motion() -> void:
	if sleeping or not contacted:
		return
	var average_motion := Vector2.ZERO
	for i in COUNT:
		average_motion += points[i] - previous[i]
	average_motion /= COUNT
	for i in COUNT:
		# Keep bulk sliding, but retain no oscillating per-vertex velocity after
		# contact. Shape/area constraints still freely deform the silhouette.
		previous[i] = points[i] - average_motion

func update_expression(dt: float) -> void:
	update_center()
	var shortest := radius
	var longest := radius
	for p in points:
		var distance := p.distance_to(center)
		shortest = minf(shortest, distance)
		longest = maxf(longest, distance)
	var strain := maxf(1.0 - shortest / radius, (longest / radius - 1.0) * 0.65)
	pressure = lerpf(pressure, strain, 1.0 - exp(-dt * 14.0))
	# Hysteresis avoids rapid blinking between two adjacent expression states.
	if pressure > 0.235:
		expression = 2
	elif pressure > 0.09 and (expression != 2 or pressure < 0.19):
		expression = 1
	elif pressure < 0.065:
		expression = 0
	born_scale = move_toward(born_scale, 1.0, dt * 2.5)

func bounds() -> Rect2:
	update_center()
	return geometry_bounds

func smooth_outline() -> PackedVector2Array:
	var smooth := PackedVector2Array()
	for i in COUNT:
		var a := points[(i + COUNT - 1) % COUNT]
		var b := points[i]
		var c := points[(i + 1) % COUNT]
		# Bezier corner rounding is a convex combination of physics vertices.
		# Unlike Catmull-Rom, it cannot bulge through a separating contact plane.
		var start := b.lerp(a, 0.18)
		var end := b.lerp(c, 0.18)
		for step in 4:
			var t := float(step) / 3.0
			smooth.append(start.lerp(b, t).lerp(b.lerp(end, t), t))
	return smooth
