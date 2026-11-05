extends Window

signal preference_changed(key: String, value: Variant)


func open(sound: bool, motion: bool, speed: bool, volume: float) -> void:
	%Sound.set_pressed_no_signal(sound)
	%Motion.set_pressed_no_signal(motion)
	%Speed.set_pressed_no_signal(speed)
	%Level.set_value_no_signal(volume)
	%Volume.text = "Volume %d%%" % volume
	popup_centered(Vector2i(470, 315))
	%Close.grab_focus()


func _on_level_changed(value: float) -> void:
	%Volume.text = "Volume %d%%" % value
	preference_changed.emit("volume", value)


func _on_sound_toggled(value: bool) -> void:
	preference_changed.emit("sound", value)


func _on_motion_toggled(value: bool) -> void:
	preference_changed.emit("motion", value)


func _on_speed_toggled(value: bool) -> void:
	preference_changed.emit("fast_turns", value)


func _on_close_pressed() -> void:
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_requested.emit()
