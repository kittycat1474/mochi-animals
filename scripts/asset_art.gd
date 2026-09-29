extends RefCounted
## Original raster assets through atlas UVs and native clipping polygons.
## Source PNGs remain unmodified. The cup is assembled as back/front layers.
const UI = preload("res://assets/source/buttons.png")
const CUP = preload("res://assets/source/cup.png")
const REFERENCE = preload("res://assets/source/layout-reference.png")
const ROOM = preload("res://assets/room.png")
const CUP_RECT := Rect2(26, 268, 468, 585)
const RECTS := {
	"play": Rect2(43, 59, 553, 199), "restart": Rect2(49, 282, 539, 164),
	"home_long": Rect2(49, 468, 539, 165),
	"gear": Rect2(628, 34, 118, 120), "stats": Rect2(762, 34, 118, 120),
	"shop": Rect2(896, 34, 118, 120), "sound": Rect2(1032, 34, 118, 120),
	"coin": Rect2(1177, 59, 334, 100), "next": Rect2(626, 170, 350, 358),
	"score": Rect2(1004, 194, 493, 160), "best": Rect2(1004, 372, 493, 133),
	"music_on": Rect2(628, 543, 112, 115), "music_off": Rect2(775, 543, 111, 115),
	"sound_on": Rect2(922, 543, 111, 115), "sound_off": Rect2(1070, 543, 112, 115),
	"bomb": Rect2(67, 649, 192, 176), "hammer": Rect2(299, 649, 190, 176),
	"chain": Rect2(29, 848, 1030, 148)
}

static func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [rect.position + Vector2(radius, radius), rect.position + Vector2(rect.size.x - radius, radius), rect.end - Vector2(radius, radius), rect.position + Vector2(radius, rect.size.y - radius)]
	for corner in 4:
		for i in 10:
			var angle := PI + corner * PI * 0.5 + float(i) / 9.0 * PI * 0.5
			points.append(centers[corner] + Vector2.from_angle(angle) * radius)
	return points

static func textured_polygon(c: CanvasItem, texture: Texture2D, source: PackedVector2Array, source_rect: Rect2, destination: Rect2) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in source:
		vertices.append(destination.position + (p - source_rect.position) / source_rect.size * destination.size)
		uv.append(p / texture.get_size())
	c.draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)

static func asset(c: CanvasItem, name: String, destination: Rect2) -> void:
	if name == "home":
		var region := Rect2(38, 23, 119, 115)
		textured_polygon(c, REFERENCE, rounded(region, 34), region, destination)
		return
	var region: Rect2 = RECTS[name]
	var radius := minf(region.size.x, region.size.y) * 0.36
	if name in ["gear", "stats", "shop", "sound"]:
		radius = region.size.x * 0.5
	if name in ["play", "next", "hammer", "bomb"]:
		var contours := {
			"play": PackedVector2Array([Vector2(45,139),Vector2(57,111),Vector2(60,83),Vector2(76,63),Vector2(96,62),Vector2(119,76),Vector2(521,76),Vector2(544,63),Vector2(562,63),Vector2(580,81),Vector2(589,114),Vector2(596,156),Vector2(590,207),Vector2(576,229),Vector2(549,250),Vector2(104,255),Vector2(73,242),Vector2(52,218),Vector2(44,185)]),
			"next": PackedVector2Array([Vector2(628,254),Vector2(643,218),Vector2(655,210),Vector2(660,187),Vector2(674,175),Vector2(691,175),Vector2(716,192),Vector2(885,192),Vector2(901,178),Vector2(916,179),Vector2(933,193),Vector2(942,213),Vector2(960,231),Vector2(974,263),Vector2(974,465),Vector2(963,494),Vector2(938,514),Vector2(914,520),Vector2(686,520),Vector2(656,510),Vector2(636,488),Vector2(628,465)]),
			"hammer": PackedVector2Array([Vector2(303,712),Vector2(313,679),Vector2(339,661),Vector2(428,660),Vector2(444,650),Vector2(470,651),Vector2(487,670),Vector2(487,699),Vector2(475,714),Vector2(477,773),Vector2(465,800),Vector2(442,816),Vector2(345,817),Vector2(319,804),Vector2(303,781)]),
			"bomb": PackedVector2Array([Vector2(72,709),Vector2(84,680),Vector2(112,661),Vector2(198,659),Vector2(212,650),Vector2(236,651),Vector2(253,667),Vector2(255,692),Vector2(245,707),Vector2(243,775),Vector2(230,800),Vector2(207,814),Vector2(113,817),Vector2(88,806),Vector2(73,781)])
		}
		textured_polygon(c, UI, contours[name], region, destination)
	else:
		textured_polygon(c, UI, rounded(region, radius), region, destination)

static func patch(c: CanvasItem, name: String, target: Rect2, area: Rect2, clean_strip: Rect2) -> void:
	var region: Rect2 = RECTS[name]
	var mapped := Rect2(target.position + (area.position - region.position) / region.size * target.size, area.size / region.size * target.size)
	c.draw_texture_rect_region(UI, mapped, clean_strip)

static func cup_piece(c: CanvasItem, points: PackedVector2Array) -> void:
	textured_polygon(c, CUP, points, Rect2(0, 0, 1122, 1402), CUP_RECT)

static func cup_back(c: CanvasItem) -> void:
	var rim := PackedVector2Array()
	for i in 41:
		var x := 67.0 + i * 24.75
		var u := (x - 562.0) / 495.0
		rim.append(Vector2(x, 133.0 + 29.0 * u * u))
	for i in range(40, -1, -1):
		var x := 67.0 + i * 24.75
		var u := (x - 562.0) / 495.0
		rim.append(Vector2(x, 141.0 + 29.0 * u * u))
	cup_piece(c, rim)
	cup_piece(c, PackedVector2Array([Vector2(88,160),Vector2(101,122),Vector2(122,91),Vector2(149,74),Vector2(177,69),Vector2(207,76),Vector2(231,94),Vector2(250,124),Vector2(263,188),Vector2(218,194),Vector2(151,181)]))
	cup_piece(c, PackedVector2Array([Vector2(858,188),Vector2(869,133),Vector2(888,98),Vector2(914,77),Vector2(944,68),Vector2(974,73),Vector2(1001,88),Vector2(1023,120),Vector2(1035,160),Vector2(998,181),Vector2(925,194)]))
	c.draw_colored_polygon(PackedVector2Array([Vector2(63,366),Vector2(462,366),Vector2(413,758),Vector2(118,758)]), Color(1.0,0.93,0.85,0.07))

static func cup_front(c: CanvasItem) -> void:
	var front_rim := PackedVector2Array()
	for i in 61:
		var u := -1.0 + i / 30.0
		front_rim.append(Vector2(561.0 + 497.0 * u, 201.0 - 40.0 * u * u))
	for i in range(60, -1, -1):
		var u := -1.0 + i / 30.0
		front_rim.append(Vector2(561.0 + 484.0 * u, 274.0 - 64.0 * u * u))
	cup_piece(c, front_rim)
	cup_piece(c, PackedVector2Array([Vector2(77,210),Vector2(105,223),Vector2(253,1125),Vector2(247,1156),Vector2(224,1130),Vector2(216,1078)]))
	cup_piece(c, PackedVector2Array([Vector2(1049,212),Vector2(1025,222),Vector2(878,1128),Vector2(880,1156),Vector2(901,1127),Vector2(908,1070)]))
	var base := PackedVector2Array()
	for i in 41:
		var x := 222.0 + i * 17.0
		var u := (x - 562.0) / 340.0
		base.append(Vector2(x, 1164.0 - 65.0 * u * u))
	base.append_array(PackedVector2Array([Vector2(899,1158),Vector2(885,1210),Vector2(857,1236),Vector2(805,1258),Vector2(721,1278),Vector2(624,1288),Vector2(510,1289),Vector2(391,1275),Vector2(310,1253),Vector2(265,1226),Vector2(240,1193),Vector2(222,1120)]))
	cup_piece(c, base)
