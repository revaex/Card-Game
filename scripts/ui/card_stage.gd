extends Panel
## Drop target and presentation of the latest play. The session still resolves the action.

const CARD = preload("res://scenes/ui/card.tscn")
const CARD_SCALE: float = 0.58

var table: Control
var _flight: Tween
var _card: Control
var _hot: bool = false
var _seal: float = 1.0
var _confirm_pressed: bool = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return table != null and table.is_hand_drag(data) and table.can_play_card(data.card)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	table.play_card(data.card)


func _gui_input(event: InputEvent) -> void:
	if table == null or not table.has_selected_card() or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		_confirm_pressed = true
		return
	var confirmed := _confirm_pressed and Rect2(Vector2.ZERO, size).has_point(event.position)
	_confirm_pressed = false
	if confirmed:
		table.confirm_selected_card()


func show_selection(card_name: String) -> void:
	_confirm_pressed = false
	show_drag(not card_name.is_empty(), not card_name.is_empty())
	if not card_name.is_empty():
		%Prompt.text = "Tap here to play\n" + card_name


func show_drag(playable: bool, dragging: bool) -> void:
	_hot = playable and dragging
	%Prompt.visible = dragging or _card == null
	%Prompt.text = ("◇\nRelease here to play" if playable else "◇\nCard unavailable") if dragging else "◇\nDrag a card here"
	if is_instance_valid(_card):
		_card.visible = not dragging
	queue_redraw()


func _draw() -> void:
	if _hot:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("e8ba6666"), false, 2)
	if _seal < 1.0:
		var center := Vector2(size.x * 0.5, size.y - 21)
		for index in range(8):
			var angle := TAU * index / 8.0
			var spread := Vector2.from_angle(angle) * Vector2(25 + 38 * _seal, 6 + 13 * _seal)
			draw_circle(center + spread, 2.0 - _seal, Color(0.95, 0.76, 0.44, 1.0 - _seal))


func present(card: CardInstance, by_player: bool, from_canvas: Vector2, animate: bool, description: String) -> void:
	if _flight != null:
		_flight.kill()
	_set_seal(1.0)
	if is_instance_valid(_card):
		_card.hide()
		_card.queue_free()
	var face := CARD.instantiate()
	%CardMotion.add_child(face)
	face.setup(card, false, Callable(), Callable(), description, "", "", "You played" if by_player else "Rival played")
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in face.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = face.get_combined_minimum_size()
	_card = face
	%Title.text = "YOUR PLAY" if by_player else "RIVAL PLAY"
	show_drag(false, false)
	var target := Vector2((size.x - face.size.x * CARD_SCALE) * 0.5, 24.0)
	face.scale = Vector2.ONE * CARD_SCALE
	face.position = target
	if not animate:
		return
	face.position = %CardMotion.get_global_transform_with_canvas().affine_inverse() * from_canvas - face.size * 0.35
	face.scale = Vector2.ONE * 0.70
	face.rotation = -0.09 if by_player else 0.09
	_flight = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flight.tween_property(face, "position", target, 0.34)
	_flight.tween_property(face, "scale", Vector2.ONE * CARD_SCALE, 0.34)
	_flight.tween_property(face, "rotation", 0.0, 0.30)
	_flight.chain().tween_method(_set_seal, 0.0, 1.0, 0.24)


func settle() -> void:
	if _flight != null and _flight.is_valid():
		_flight.custom_step(1.0)


func _set_seal(progress: float) -> void:
	_seal = progress
	queue_redraw()
