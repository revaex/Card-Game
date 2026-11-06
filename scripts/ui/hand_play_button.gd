extends "res://scripts/ui/info_button.gd"

var table: Control
var card: CardInstance
var face: Control


func _gui_input(event: InputEvent) -> void:
	if table != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if not event.pressed:
			table.inspect_hand_card(card, self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if table == null or not table.can_drag_card(card):
		return null
	var preview := Control.new()
	var copy: Control = face.make_snapshot()
	preview.add_child(copy)
	copy.scale = Vector2.ONE * 0.87
	copy.position = -copy.size * 0.435
	set_drag_preview(preview)
	table.begin_hand_drag(face, card)
	return {"table": table.get_instance_id(), "card": card}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return table != null and table.is_hand_drag(data) and card != data.card


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	table.reorder_hand(data.card, card)
