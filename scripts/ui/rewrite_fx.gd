extends Control
## Animates a snapshot of the old line. It never changes the combat session.

signal landed
signal finished

const INK = Color("dc956d")
const GOLD = Color("f3cf85")
const FLIGHT_TIME: float = 0.55

var _tween: Tween
var _hidden_tiles: Array[Control] = []
var _moved: Button
var _from: Vector2
var _to: Vector2
var _tile_size: Vector2
var _progress: float = 0.0
var _seal: float = 0.0
var _sealing: bool = false


func capture(row: HBoxContainer) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for tile: Control in row.get_children():
		snapshot.append({"tile": tile, "position": to_local * tile.get_global_transform_with_canvas().origin, "size": tile.size})
	return snapshot


func play(old_line: Array[Dictionary], row: HBoxContainer, moved_index: int) -> bool:
	if moved_index < 0 or moved_index >= old_line.size() - 1 or row.get_child_count() != old_line.size():
		return false
	_from = old_line[moved_index].position
	_to = old_line.back().position
	_tile_size = old_line[moved_index].size
	if _to.x <= _from.x or _tile_size.x <= 0:
		return false
	_progress = 0.0
	_seal = 0.0
	_sealing = false
	_tween = create_tween().set_parallel(true)
	for index in range(moved_index, old_line.size()):
		var frame: Dictionary = old_line[index]
		var new_index := old_line.size() - 1 if index == moved_index else index - 1
		var tile: Control = row.get_child(new_index)
		tile.modulate.a = 0.0
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hidden_tiles.append(tile)
		var ghost: Button = frame.tile.duplicate(0)
		add_child(ghost)
		ghost.focus_mode = Control.FOCUS_NONE
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ghost.position = frame.position
		ghost.size = frame.size
		if index == moved_index:
			_moved = ghost
			ghost.z_index = 1
			ghost.pivot_offset = ghost.size / 2
			var paper := ghost.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			paper.bg_color = Color("ffe8b9")
			paper.border_color = GOLD
			paper.set_border_width_all(2)
			paper.shadow_color = Color("e6a95e92")
			paper.shadow_size = 5
			ghost.add_theme_stylebox_override("normal", paper)
			ghost.disabled = false
		else:
			_tween.tween_property(ghost, "position", old_line[new_index].position, 0.30).set_delay(0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_flight, 0.0, 1.0, FLIGHT_TIME)
	_tween.chain().tween_callback(_land)
	_tween.chain().tween_method(_burst, 0.0, 1.0, 0.33)
	_tween.chain().tween_callback(_finish)
	return true


func cancel() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_restore_tiles()
	_sealing = false
	queue_redraw()


func is_active() -> bool:
	return _tween != null


func _restore_tiles() -> void:
	for tile in _hidden_tiles:
		if is_instance_valid(tile):
			tile.modulate = Color.WHITE
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
	_hidden_tiles.clear()
	for ghost in get_children():
		remove_child(ghost)
		ghost.queue_free()
	_moved = null


func _flight(progress: float) -> void:
	_progress = progress
	_moved.position = _arc(progress)
	_moved.rotation = -0.085 * sin(progress * TAU)
	_moved.scale = Vector2.ONE * (1.0 + 0.07 * sin(progress * PI))
	queue_redraw()


func _arc(progress: float) -> Vector2:
	var eased := smoothstep(0.0, 1.0, progress)
	return _from.lerp(_to, eased) - Vector2(0, 12.0 * sin(progress * PI))


func _land() -> void:
	_restore_tiles()
	_sealing = true
	landed.emit()


func _burst(progress: float) -> void:
	_seal = progress
	queue_redraw()


func _finish() -> void:
	_tween = null
	_sealing = false
	queue_redraw()
	finished.emit()


func _draw() -> void:
	if _moved != null:
		var trail := PackedVector2Array()
		for index in range(19):
			var time := maxf(_progress - (18 - index) * 0.027, 0.0)
			trail.append(_arc(time) + Vector2(_tile_size.x * 0.27, _tile_size.y * 0.84))
		draw_polyline(trail, Color(INK, 0.55), 9.0, true)
		draw_polyline(trail, Color(GOLD, 0.94), 2.0, true)
		for index in range(3, trail.size(), 4):
			draw_circle(trail[index] + Vector2(-5, float(index % 3) * 4), 2.2, GOLD)
	elif _sealing:
		var fade := 1.0 - _seal
		var radius := 8.0 + 22.0 * _seal
		var rect := Rect2(_to, _tile_size).grow(radius * 0.3)
		draw_rect(rect, Color(GOLD, fade * 0.76), false, 2)
		for index in range(8):
			var angle := TAU * index / 8.0
			var spark := _to + _tile_size / 2 + Vector2.from_angle(angle) * Vector2(_tile_size.x * 0.42 + radius, _tile_size.y * 0.37 + radius)
			draw_circle(spark, 1.0 + fade * 2.0, Color(GOLD, fade))
