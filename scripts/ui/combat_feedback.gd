extends Control
## Short-lived visual feedback. Reads completed changes; never schedules game actions.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30


func present(changes: Array[Dictionary], motion: bool = true) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for index in range(mini(3, changes.size())):
		var change: Dictionary = changes[index]
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("101c22")
		panel.border_color = change.color
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(4)
		panel.content_margin_left = 9
		panel.content_margin_right = 9
		panel.content_margin_top = 3
		panel.content_margin_bottom = 3
		badge.add_theme_stylebox_override("panel", panel)
		var label := Label.new()
		label.text = change.text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", change.color)
		label.add_theme_font_size_override("font_size", 15)
		badge.add_child(label)
		add_child(badge)
		badge.size = badge.get_combined_minimum_size()
		badge.position = Vector2((size.x - badge.size.x) / 2, -index * 24)
		var tween := badge.create_tween()
		tween.set_parallel(true)
		if motion:
			tween.tween_property(badge, "position:y", badge.position.y - 22, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(badge, "modulate:a", 0.0, 0.35).set_delay(0.55)
		tween.chain().tween_callback(badge.queue_free)
