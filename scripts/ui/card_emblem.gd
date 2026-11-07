@tool
extends Control
@export var kind: String = "ATTACK"
@export var accent: Color = Color("d88b78")

func _draw() -> void:
	# Keep the complete ornament inside both full and compact card art frames.
	var center := Vector2.ZERO
	var frame := get_parent() as Control
	var factor := minf(1.0, frame.size.y / 64.0) if frame != null else 1.0
	draw_set_transform(size / 2, 0, Vector2.ONE * factor)
	draw_circle(center, 26, Color(accent, 0.12))
	draw_arc(center, 26, 0, TAU, 48, Color(accent, 0.4), 1.0, true)
	draw_arc(center, 29, 0, TAU, 48, Color(accent, 0.22), 1.0, true)
	for direction in [-1, 1]:
		var tip := center + Vector2(40 * direction, 0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 0), tip + Vector2(0, -3), tip + Vector2(4, 0), tip + Vector2(0, 3)]), Color(accent, 0.8))
		draw_line(tip + Vector2(7 * direction, 0), tip + Vector2(21 * direction, 0), Color(accent, 0.32), 1.0, true)
	match kind:
		"ATTACK":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-11, 14), center + Vector2(-5, 16), center + Vector2(18, -18), center + Vector2(9, -14)]), accent)
			draw_line(center + Vector2(-15, 5), center + Vector2(1, 17), accent, 4, true)
			draw_line(center + Vector2(-7, 12), center + Vector2(-16, 24), accent, 5, true)
		"GUARD":
			var points := PackedVector2Array([center + Vector2(-17, -17), center + Vector2(17, -17), center + Vector2(13, 9), center + Vector2(0, 22), center + Vector2(-13, 9), center + Vector2(-17, -17)])
			draw_polyline(points, accent, 3, true)
			draw_line(center + Vector2(0, -13), center + Vector2(0, 15), accent, 2, true)
		"POISON":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -24), center + Vector2(16, 0), center + Vector2(12, 17), center + Vector2(-12, 17), center + Vector2(-16, 0)]), accent)
			draw_circle(center + Vector2(-4, 3), 3, Color("122e25"))
			draw_circle(center + Vector2(5, 10), 2, Color("122e25"))
		"RESTORE":
			draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), accent, 10, true)
			draw_line(center + Vector2(0, -18), center + Vector2(0, 18), accent, 10, true)
		_:
			for index in range(3):
				var offset := Vector2(index * 8 - 18, index * -5 - 10)
				draw_rect(Rect2(center + offset, Vector2(22, 30)), accent, false, 2)
