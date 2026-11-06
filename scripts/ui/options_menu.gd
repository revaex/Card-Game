extends Window

signal preference_changed(key: String, value: Variant)

var _parent_window: Window
var _trigger_held := [false, false]
var _section_fade: Tween


func open(settings: Dictionary, desktop_display: bool = true) -> void:
	%Sound.set_pressed_no_signal(settings.sound)
	%Motion.set_pressed_no_signal(settings.motion)
	%Speed.set_pressed_no_signal(settings.fast_turns)
	%Level.set_value_no_signal(settings.volume)
	%Effects.set_value_no_signal(settings.effects_volume)
	%Volume.text = "Master volume %d%%" % settings.volume
	%EffectsVolume.text = "Effects volume %d%%" % settings.effects_volume
	%WindowMode.select(settings.window_mode)
	%WindowSize.select(settings.window_size)
	%WindowMode.disabled = not desktop_display
	%WindowSize.disabled = not desktop_display or settings.window_mode != 0
	%VSync.disabled = not desktop_display
	if not desktop_display:
		%DisplayDetail.text = "Window size, fullscreen, and refresh settings are managed by your device or browser."
	%VSync.set_pressed_no_signal(settings.vsync)
	%Controller.set_pressed_no_signal(settings.controller)
	%SwapShoulders.set_pressed_no_signal(settings.swap_shoulders)
	%EndShortcut.set_pressed_no_signal(settings.end_shortcut)
	update_mapping()
	for entry in [[%Sound, "sound"], [%Motion, "motion"], [%Speed, "fast_turns"], [%VSync, "vsync"],
			[%Controller, "controller"], [%SwapShoulders, "swap_shoulders"], [%EndShortcut, "end_shortcut"]]:
		entry[0].toggled.connect(_on_toggle.bind(entry[1]))
	_parent_window = get_parent().get_window()
	_parent_window.size_changed.connect(fit_to_parent)
	popup_centered(_parent_window.size)
	fit_to_parent()
	if desktop_display:
		%WindowMode.grab_focus()
	else:
		%Tabs.current_tab = 1
		%Level.grab_focus()
	_tab_changed(%Tabs.current_tab)


func fit_to_parent() -> void:
	size = _parent_window.size
	position = _parent_window.position if not is_embedded() else Vector2i.ZERO
	%WindowReadout.text = "Current window area: %d × %d" % [size.x, size.y]


func update_mapping() -> void:
	var active: bool = %Controller.button_pressed
	%SwapShoulders.disabled = not active
	%EndShortcut.disabled = not active
	if not active:
		%Mapping.text = "Combat shortcuts off. Standard navigation and Start: Options still work."
		return
	var shoulders := "LB: rival line   /   RB: hand" if %SwapShoulders.button_pressed else "LB: hand   /   RB: rival line"
	%Mapping.text = shoulders + ("   /   Y: end turn" if %EndShortcut.button_pressed else "") + "   /   Start: Options"


func _on_window_mode(index: int) -> void:
	%WindowSize.disabled = index != 0
	preference_changed.emit("window_mode", index)


func _on_window_size(index: int) -> void:
	preference_changed.emit("window_size", index)


func _on_level_changed(value: float) -> void:
	%Volume.text = "Master volume %d%%" % value
	preference_changed.emit("volume", value)


func _on_effects_changed(value: float) -> void:
	%EffectsVolume.text = "Effects volume %d%%" % value
	preference_changed.emit("effects_volume", value)


func _on_toggle(value: bool, key: String) -> void:
	update_mapping()
	preference_changed.emit(key, value)


func _on_close_pressed() -> void:
	close_requested.emit()


func _previous_tab() -> void:
	turn_tab(-1)


func _next_tab() -> void:
	turn_tab(1)


func turn_tab(direction: int) -> void:
	var tabs: TabContainer = %Tabs
	tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
	var first_controls: Array[Control] = [%WindowMode, %Level, %Controller, %Motion]
	var focus := first_controls[tabs.current_tab]
	if focus is BaseButton and focus.disabled:
		focus = %Close
	focus.grab_focus()


func _tab_changed(index: int) -> void:
	if not is_node_ready() or index < 0:
		return
	var tabs: TabContainer = %Tabs
	%SectionIndex.text = "%02d / %02d   ·   %s" % [index + 1, tabs.get_tab_count(), tabs.get_tab_title(index).to_upper()]
	if _section_fade != null:
		_section_fade.kill()
	for tab in range(tabs.get_tab_count()):
		tabs.get_tab_control(tab).modulate.a = 1.0
	if %Motion.button_pressed:
		var page := tabs.get_tab_control(index)
		page.modulate.a = 0.72
		_section_fade = create_tween()
		_section_fade.tween_property(page, "modulate:a", 1.0, 0.17)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_requested.emit()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			set_input_as_handled()
			close_requested.emit()
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			set_input_as_handled()
			turn_tab(1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1)
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		set_input_as_handled()
		var side := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		if event.axis_value < 0.35:
			_trigger_held[side] = false
		elif event.axis_value > 0.55 and not _trigger_held[side]:
			_trigger_held[side] = true
			turn_tab(-1 if side == 0 else 1)
