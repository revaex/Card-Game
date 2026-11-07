extends Control
## Mirrors a focused control's hover tooltip when using a gamepad.

signal toggle_requested

const Tooltip = preload("res://scripts/ui/board_tooltip.gd")
const Bindings = preload("res://scripts/ui/control_bindings.gd")
var hints_enabled := true
var protected_control: Control
var _gamepad_active := false
var _tooltip: Control
var _text := ""
var _dismiss_hint := ""


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("focus_tooltips"):
		_gamepad_active = true
		get_viewport().set_input_as_handled()
		toggle_requested.emit()
	elif event is InputEventJoypadButton and event.pressed:
		_gamepad_active = true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) >= 0.5:
		_gamepad_active = true
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and not event.relative.is_zero_approx()) or (event is InputEventKey and event.pressed):
		_gamepad_active = false


func _process(_delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var text := ""
	if hints_enabled and _gamepad_active and is_instance_valid(focus) and focus.is_visible_in_tree():
		text = focus.get_tooltip(focus.size * 0.5)
	var binding := Bindings.active_label(&"focus_tooltips", 1)
	var dismiss_hint := "%s · Hide help" % ("R3" if binding == "Right stick click" else binding)
	if text != _text or dismiss_hint != _dismiss_hint:
		_text = text
		_dismiss_hint = dismiss_hint
		if is_instance_valid(_tooltip):
			_tooltip.hide()
			_tooltip.queue_free()
		_tooltip = Tooltip.create(text, dismiss_hint)
		if _tooltip != null:
			add_child(_tooltip)
	if not is_instance_valid(_tooltip) or not is_instance_valid(focus):
		return
	var bounds := get_viewport_rect().grow(-10)
	var target := focus.get_global_rect()
	var protected := protected_control.get_global_rect().grow(6) if is_instance_valid(protected_control) and protected_control.is_visible_in_tree() else Rect2()
	_tooltip.global_position = place_tooltip(target, _tooltip.size, bounds, protected)


func place_tooltip(target: Rect2, tooltip_size: Vector2, bounds: Rect2, protected: Rect2) -> Vector2:
	# Prefer below, then above, then beside. Clamp every candidate before measuring
	# overlap so a screen-edge correction cannot silently cover the help toggle.
	var candidates: Array[Vector2] = [
		Vector2(target.position.x, target.end.y + 8),
		Vector2(target.position.x, target.position.y - tooltip_size.y - 8),
		Vector2(target.end.x + 8, target.position.y),
		Vector2(target.position.x - tooltip_size.x - 8, target.position.y),
		Vector2(bounds.position.x, bounds.end.y - tooltip_size.y),
		bounds.end - tooltip_size,
	]
	var best := bounds.position
	var best_score := INF
	for candidate in candidates:
		var point := candidate.clamp(bounds.position, (bounds.end - tooltip_size).max(bounds.position))
		var rect := Rect2(point, tooltip_size)
		var score := rect.intersection(target.grow(4)).get_area()
		if protected.has_area() and rect.intersects(protected):
			score += bounds.get_area() + rect.intersection(protected).get_area()
		if score < best_score:
			best = point
			best_score = score
		if is_zero_approx(score):
			break
	return best
