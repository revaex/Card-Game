extends Control
## Mirrors a focused control's hover tooltip when using a gamepad.

signal toggle_requested

const Tooltip = preload("res://scripts/ui/board_tooltip.gd")
var hints_enabled := true
var _gamepad_active := false
var _tooltip: Control
var _text := ""


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
	if text != _text:
		_text = text
		if is_instance_valid(_tooltip):
			_tooltip.hide()
			_tooltip.queue_free()
		_tooltip = Tooltip.create(text)
		if _tooltip != null:
			add_child(_tooltip)
	if not is_instance_valid(_tooltip) or not is_instance_valid(focus):
		return
	var bounds := get_viewport_rect().grow(-10)
	var target := focus.get_global_rect()
	var point := Vector2(target.position.x, target.end.y + 8)
	if point.y + _tooltip.size.y > bounds.end.y:
		point.y = target.position.y - _tooltip.size.y - 8
	_tooltip.global_position = point.clamp(bounds.position, (bounds.end - _tooltip.size).max(bounds.position))
