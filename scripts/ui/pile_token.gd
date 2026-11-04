extends Button
## A physical card stack with standard button keyboard/activation behavior.

const Tooltip = preload("res://scripts/ui/board_tooltip.gd")
var pile_name: String
var count: int
var accent: Color


func setup(title: String, amount: int, color: Color, action: Callable) -> void:
	pile_name = title
	count = amount
	accent = color
	custom_minimum_size = Vector2(108, 64)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	pressed.connect(action)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var x := size.x / 2 - 26
	var ink := Color("eddfc3") if is_hovered() or has_focus() else accent
	for index in range(2, -1, -1):
		var rect := Rect2(Vector2(x + index * 3, 2 + index * 2), Vector2(48, 35))
		draw_rect(rect, Color("17292e"))
		draw_rect(rect, ink, false, 1)
	draw_string(font, Vector2(x, 28), str(count), HORIZONTAL_ALIGNMENT_CENTER, 48, 22, Color("eee2c9"))
	draw_string(font, Vector2(0, 59), pile_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, ink)


func _make_custom_tooltip(text: String) -> Object:
	return Tooltip.new(text)
