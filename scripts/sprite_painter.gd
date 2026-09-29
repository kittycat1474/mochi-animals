extends RefCounted
## Original 7 × 3 expression sheet, sampled directly through a deforming mesh.
const SHEET = preload("res://assets/source/animals.png")
const REGIONS := [
	Rect2(19, 38, 263, 261), Rect2(287, 44, 252, 255), Rect2(541, 34, 265, 269), Rect2(812, 39, 269, 260), Rect2(1086, 35, 270, 267), Rect2(1358, 37, 269, 265), Rect2(1629, 34, 272, 269),
	Rect2(19, 307, 260, 251), Rect2(286, 306, 253, 251), Rect2(542, 305, 263, 253), Rect2(812, 307, 269, 252), Rect2(1087, 306, 269, 252), Rect2(1360, 305, 267, 253), Rect2(1631, 306, 270, 253),
	Rect2(19, 559, 257, 245), Rect2(287, 558, 250, 248), Rect2(542, 558, 263, 248), Rect2(812, 558, 268, 247), Rect2(1088, 558, 267, 247), Rect2(1362, 558, 263, 247), Rect2(1631, 558, 266, 247)
]
static var edge_cache: Dictionary = {}
static var source_pixels: Image

static func edge_uv(region_index: int, angle: float) -> Vector2:
	# The sheet's hand-drawn outlines are almost, but not mathematically, circles.
	# Sample the original outline per angle so its white sheet never leaks in.
	if not edge_cache.has(region_index):
		if source_pixels == null:
			source_pixels = SHEET.get_image()
		var region: Rect2 = REGIONS[region_index]
		var values := PackedVector2Array()
		for i in 360:
			var direction := Vector2.from_angle(TAU * i / 360.0)
			var edge := region.get_center() + direction * region.size * 0.48
			for step in 70:
				var fraction := 0.509 - step * 0.001
				var at := region.get_center() + direction * region.size * fraction
				var color := source_pixels.get_pixelv(Vector2i(at))
				if minf(color.r, minf(color.g, color.b)) < 0.79:
					edge = at - direction * 0.4
					break
			values.append(edge / SHEET.get_size())
		edge_cache[region_index] = values
	var fraction := fposmod(angle, TAU) / TAU * 360.0
	var index := int(fraction)
	var cached: PackedVector2Array = edge_cache[region_index]
	return cached[index].lerp(cached[(index + 1) % 360], fraction - index)

static func paint(c: CanvasItem, level: int, center: Vector2, radius: float, expression := 0, contour := PackedVector2Array(), opacity := 1.0) -> void:
	var outline := contour
	if outline.is_empty():
		for i in 60:
			outline.append(center + Vector2.from_angle(TAU * i / 60.0) * radius)
	# Keep faces upright when the round bodies roll; deformation follows physics.
	var polar: Array[Vector2] = []
	polar.assign(outline)
	polar.sort_custom(func(a: Vector2, b: Vector2): return (a - center).angle() < (b - center).angle())
	var region_index := clampi(expression, 0, 2) * 7 + level
	var region: Rect2 = REGIONS[region_index]
	var vertices := PackedVector3Array([Vector3(center.x, center.y, 0.0)])
	var uv := PackedVector2Array([region.get_center() / SHEET.get_size()])
	var indices := PackedInt32Array()
	var colors := PackedColorArray([Color(1, 1, 1, opacity)])
	for p in polar:
		vertices.append(Vector3(p.x, p.y, 0.0))
		var direction := (p - center).normalized()
		uv.append(edge_uv(region_index, direction.angle()))
		colors.append(Color(1, 1, 1, opacity))
	for i in polar.size():
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % polar.size() + 1]))
	# An alpha fringe anti-aliases the clipped original border on every renderer.
	var ring_count := polar.size()
	for i in ring_count:
		var p := polar[i] + (polar[i] - center).normalized() * 0.8
		vertices.append(Vector3(p.x, p.y, 0.0))
		uv.append(uv[i + 1])
		colors.append(Color(1, 1, 1, 0))
		var j := (i + 1) % ring_count
		indices.append_array(PackedInt32Array([i + 1, ring_count + i + 1, ring_count + j + 1, i + 1, ring_count + j + 1, j + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var retained: Array = c.get_meta("animal_meshes", [])
	retained.append(mesh)
	c.set_meta("animal_meshes", retained)
	c.draw_mesh(mesh, SHEET)
