extends RefCounted
## Both approved expression sheets, sampled directly through deforming meshes.
const Data = preload("res://scripts/animal_data.gd")
const SHEET = preload("res://assets/source/animals.png")
const NEW_SHEET = preload("res://assets/source/new_animals.png")
const REGIONS := [
	Rect2(19, 38, 263, 261), Rect2(287, 44, 252, 255), Rect2(541, 34, 265, 269), Rect2(812, 39, 269, 260), Rect2(1086, 35, 270, 267), Rect2(1358, 37, 269, 265), Rect2(1629, 34, 272, 269),
	Rect2(19, 307, 260, 251), Rect2(286, 306, 253, 251), Rect2(542, 305, 263, 253), Rect2(812, 307, 269, 252), Rect2(1087, 306, 269, 252), Rect2(1360, 305, 267, 253), Rect2(1631, 306, 270, 253),
	Rect2(19, 559, 257, 245), Rect2(287, 558, 250, 248), Rect2(542, 558, 263, 248), Rect2(812, 558, 268, 247), Rect2(1088, 558, 267, 247), Rect2(1362, 558, 263, 247), Rect2(1631, 558, 266, 247)
]
const NEW_REGIONS := [
	Rect2(24, 37, 393, 381), Rect2(435, 38, 399, 380), Rect2(848, 37, 392, 381),
	Rect2(24, 429, 393, 382), Rect2(435, 429, 399, 382), Rect2(848, 429, 392, 382),
	Rect2(24, 820, 393, 382), Rect2(435, 820, 399, 382), Rect2(848, 820, 392, 382)
]
static var edge_cache: Dictionary = {}
static var source_pixels: Dictionary = {}
static var circle_meshes: Dictionary = {}
static var fan_indices: Dictionary = {}

static func is_new_animal(level: int) -> bool:
	return level >= 6 and level <= 8

static func sheet_for(level: int) -> Texture2D:
	return NEW_SHEET if is_new_animal(level) else SHEET

static func region_for(level: int, expression: int) -> Rect2:
	var row := clampi(expression, 0, 2)
	if is_new_animal(level):
		return NEW_REGIONS[row * 3 + level - 6]
	return REGIONS[row * 7 + (6 if level == Data.LAST_LEVEL else level)]

static func paint_body(c: CanvasItem, body, world) -> void:
	# Sleeping contours and unchanged expressions reuse the same GPU resource.
	# Compare the 20 physics points before rounding/building the 80-point mesh.
	if body.artwork_mesh == null or body.artwork_points != body.points or body.artwork_expression != body.expression or body.artwork_side != body.cup_side or body.artwork_squeeze != world.squeeze:
		var arrays := mesh_arrays(body.level, body.center, body.radius, body.expression, world.render_outline(body))
		if arrays.is_empty():
			return
		body.artwork_mesh = ArrayMesh.new()
		body.artwork_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		body.artwork_points = body.points.duplicate()
		body.artwork_expression = body.expression
		body.artwork_side = body.cup_side
		body.artwork_squeeze = world.squeeze
	c.draw_mesh(body.artwork_mesh, sheet_for(body.level))

static func edge_uv(level: int, expression: int, angle: float) -> Vector2:
	# The sheet's hand-drawn outlines are almost, but not mathematically, circles.
	# Sample the original outline per angle so its white sheet never leaks in.
	var key := clampi(expression, 0, 2) * Data.NAMES.size() + level
	var sheet := sheet_for(level)
	var new_animal := is_new_animal(level)
	if not edge_cache.has(key):
		if not source_pixels.has(new_animal):
			source_pixels[new_animal] = sheet.get_image()
		var pixels: Image = source_pixels[new_animal]
		var region := region_for(level, expression)
		var values := PackedVector2Array()
		for i in 360:
			var direction := Vector2.from_angle(TAU * i / 360.0)
			var edge := region.get_center() + direction * region.size * 0.48
			for step in 70:
				var fraction := 0.509 - step * 0.001
				var at := region.get_center() + direction * region.size * fraction
				var color := pixels.get_pixelv(Vector2i(at))
				# Approved new sprites have alpha: sample the opaque body, not
				# stray colored pixels outside it. Old white atlas uses its ink edge.
				var on_body := color.a > 0.98 if new_animal else minf(color.r, minf(color.g, color.b)) < 0.79
				if on_body:
					edge = at - direction * (1.5 if new_animal else 0.4)
					break
			values.append(edge / sheet.get_size())
		edge_cache[key] = values
	var fraction := fposmod(angle, TAU) / TAU * 360.0
	var index := int(fraction)
	var cached: PackedVector2Array = edge_cache[key]
	return cached[index].lerp(cached[(index + 1) % 360], fraction - index)

static func paint(c: CanvasItem, level: int, center: Vector2, radius: float, expression := 0, contour := PackedVector2Array(), opacity := 1.0) -> void:
	if contour.is_empty():
		var key := clampi(expression, 0, 2) * Data.NAMES.size() + level
		if not circle_meshes.has(key):
			var circle := ArrayMesh.new()
			circle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays(level, Vector2.ZERO, 1.0, expression))
			circle_meshes[key] = circle
		c.draw_mesh(circle_meshes[key], sheet_for(level), Transform2D(Vector2(radius, 0), Vector2(0, radius), center), Color(1, 1, 1, opacity))
		return
	var arrays := mesh_arrays(level, center, radius, expression, contour, opacity)
	if arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var retained: Array = c.get_meta("animal_meshes", [])
	retained.append(mesh)
	c.set_meta("animal_meshes", retained)
	c.draw_mesh(mesh, sheet_for(level))

static func mesh_arrays(level: int, center: Vector2, radius: float, expression := 0, contour := PackedVector2Array(), opacity := 1.0) -> Array:
	var outline := contour
	if outline.is_empty():
		for i in 60:
			outline.append(center + Vector2.from_angle(TAU * i / 60.0) * radius)
	# Pin the face to a stable centre vertex. Re-ear-clipping a soft outline on
	# every frame changes the UV diagonals and visibly jumps the eyes/mouth even
	# when the physical contour barely moves. Never sort the physical outline.
	var use_fan := supports_center_fan(outline, center)
	var indices := PackedInt32Array() if use_fan else Geometry2D.triangulate_polygon(outline)
	if not use_fan and indices.is_empty():
		return []
	var region := region_for(level, expression)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	for p in outline:
		vertices.append(Vector3(p.x, p.y, 0.0))
		var direction := (p - center).normalized()
		uv.append(edge_uv(level, expression, direction.angle()))
		colors.append(Color(1, 1, 1, opacity))
	if use_fan:
		var anchor := outline.size()
		vertices.append(Vector3(center.x, center.y, 0.0))
		uv.append(region.get_center() / sheet_for(level).get_size())
		colors.append(Color(1, 1, 1, opacity))
		if not fan_indices.has(anchor):
			var triangles := PackedInt32Array()
			for i in anchor:
				triangles.append_array(PackedInt32Array([anchor, i, (i + 1) % anchor]))
			fan_indices[anchor] = triangles
		indices = fan_indices[anchor]
	# No outward alpha fringe: the rendered silhouette stays inside the same
	# collision envelope, including when using the Compatibility renderer.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func supports_center_fan(outline: PackedVector2Array, center: Vector2) -> bool:
	# A centre fan is safe only if the centre can see every contour edge. This
	# also allows ordinary concave dents, but never paints across a deep fold.
	for i in outline.size():
		if (outline[i] - center).cross(outline[(i + 1) % outline.size()] - center) < -0.0001:
			return false
	return true
