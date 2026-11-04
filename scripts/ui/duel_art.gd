extends Control
## Code-drawn card folio and duelist seals, independent of gameplay.

var motif: String = "folio"
var accent: Color = Color("cfaa66")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size / 2
	if motif == "folio":
		for index in range(3):
			draw_set_transform(center + Vector2((index - 1) * 73, abs(index - 1) * 18), (index - 1) * 0.18)
			var card := Rect2(Vector2(-74, -113), Vector2(148, 226))
			draw_rect(Rect2(card.position + Vector2(8, 8), card.size), Color(0, 0, 0, 0.25))
			draw_rect(card, Color("d8c8a6"))
			draw_rect(card.grow(-7), Color("263638"))
			draw_rect(card.grow(-11), accent, false, 1)
			draw_arc(Vector2.ZERO, 37, 0, TAU, 64, accent, 1.5, true)
			var glyph: String = ["A", "G", "T"][index]
			draw_string(ThemeDB.fallback_font, Vector2(-12, 10), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, accent)
			for line in range(3):
				draw_line(Vector2(-39, 65 + line * 9), Vector2(39 - line * 9, 65 + line * 9), Color("71817a"), 1)
		draw_set_transform(Vector2.ZERO)
		return
	var radius := minf(size.x * 0.33, size.y * 0.43)
	draw_circle(center, radius, Color(accent, 0.08))
	draw_arc(center, radius, 0, TAU, 64, Color(accent, 0.5), 1, true)
	draw_arc(center, radius - 7, 0.1, PI * 1.7, 48, Color(accent, 0.2), 1, true)
	var head := center + Vector2(0, -radius * 0.25)
	draw_circle(head, radius * 0.19, accent)
	var cloak := PackedVector2Array([head + Vector2(-radius * 0.16, radius * 0.18), center + Vector2(-radius * 0.47, radius * 0.57), center + Vector2(radius * 0.47, radius * 0.57), head + Vector2(radius * 0.16, radius * 0.18)])
	draw_colored_polygon(cloak, Color(accent, 0.65))
	if motif == "The Duelist":
		draw_line(center + Vector2(-radius * 0.5, radius * 0.4), center + Vector2(radius * 0.5, -radius * 0.65), accent, 4, true)
	elif motif == "The Warden":
		var shield := PackedVector2Array([center + Vector2(-radius * 0.37, 0), center + Vector2(radius * 0.37, 0), center + Vector2(radius * 0.3, radius * 0.48), center + Vector2(0, radius * 0.75), center + Vector2(-radius * 0.3, radius * 0.48), center + Vector2(-radius * 0.37, 0)])
		draw_polyline(shield, accent, 3, true)
	else:
		draw_line(center + Vector2(radius * 0.1, radius * 0.5), center + Vector2(radius * 0.48, -radius * 0.45), accent, 3, true)
		draw_circle(center + Vector2(radius * 0.42, -radius * 0.32), radius * 0.1, accent)
