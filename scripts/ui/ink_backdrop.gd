extends Control
## Deterministic drawing; never consumes the combat random stream.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b20"))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.35), size.x * 0.36, Color("122328"))
	for y in range(0, int(size.y), 5):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.8, 0.7, 0.5, 0.018), 1)
	var border := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(border, Color(0.82, 0.67, 0.4, 0.22), false, 1)
	for corner in [Vector2(16, 16), Vector2(size.x - 16, 16), Vector2(16, size.y - 16), size - Vector2(16, 16)]:
		draw_circle(corner, 2, Color("cfaa66"))
