extends Window

signal preference_changed(key: String, value: Variant)
signal quit_requested

const Bindings = preload("res://scripts/ui/control_bindings.gd")
const BindingRow = preload("res://scenes/ui/control_binding_row.tscn")
const SAVED_NOTE := "Changes are saved on this device."

var _parent_window: Window
var _section_fade: Tween
var _bindings: Dictionary
var _binding_rows := {}
var _capture_action: StringName = &""
var _capture_column := 0


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
	%Quit.visible = not OS.has_feature("web")
	if not desktop_display:
		%DisplayDetail.text = "Window size, fullscreen, and refresh settings are managed by your device or browser."
	%VSync.set_pressed_no_signal(settings.vsync)
	%Controller.set_pressed_no_signal(settings.controller)
	%SwapShoulders.set_pressed_no_signal(settings.swap_shoulders)
	%EndShortcut.set_pressed_no_signal(settings.end_shortcut)
	_bindings = settings.bindings.duplicate(true)
	for action: StringName in Bindings.ACTIONS:
		var row := BindingRow.instantiate()
		var fixed_pad: bool = Bindings.FIXED_NAVIGATION.has(action)
		var section: Control = %MovementBindings if fixed_pad else %Bindings
		section.add_child(row)
		_binding_rows[action] = row
		row.get_node("Keyboard").pressed.connect(begin_capture.bind(action, 0))
		if fixed_pad:
			row.get_node("Gamepad").disabled = true
		else:
			row.get_node("Gamepad").pressed.connect(begin_capture.bind(action, 1))
	%ResetBindings.pressed.connect(reset_bindings)
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
	var swapped: bool = %SwapShoulders.button_pressed
	for action: StringName in _binding_rows:
		var row: Control = _binding_rows[action]
		var title: String = Bindings.ACTIONS[action][0]
		if action == &"menu_previous" and active:
			title += " / " + ("rival line" if swapped else "hand")
		if action == &"menu_next" and active:
			title += " / " + ("hand" if swapped else "rival line")
		row.get_node("Action").text = title
		row.get_node("Keyboard").text = Bindings.label(_bindings[action][0], 0)
		row.get_node("Gamepad").text = Bindings.label(_bindings[action][1], 1)
	%PreviousTab.text = "‹  " + Bindings.label(_bindings[&"menu_previous"][1], 1)
	%NextTab.text = Bindings.label(_bindings[&"menu_next"][1], 1) + "  ›"


func begin_capture(action: StringName, column: int) -> void:
	_capture_action = action
	_capture_column = column
	update_mapping()
	_binding_rows[action].get_node("Keyboard" if column == 0 else "Gamepad").text = "Press key…" if column == 0 else "Press button…"
	%Note.text = "Press a key · Esc cancels" if column == 0 else "Press a gamepad button · D-pad ← or Esc cancels"


func finish_capture(note: String) -> void:
	_capture_action = &""
	update_mapping()
	%Note.text = note


func reset_bindings() -> void:
	_bindings = Bindings.defaults()
	finish_capture("Default bindings restored.")
	preference_changed.emit("bindings", _bindings)


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not visible:
		return
	if event is InputEventJoypadMotion:
		set_input_as_handled()
		return
	if not event is InputEventKey and not event is InputEventJoypadButton:
		return
	set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if (event is InputEventKey and event.keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_LEFT):
		finish_capture(SAVED_NOTE)
		return
	if (event is InputEventKey) != (_capture_column == 0):
		return
	var code: int = event.keycode if event is InputEventKey else event.button_index
	if not Bindings.accepts(code, _capture_column) or (event is InputEventKey and (event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed)):
		%Note.text = "That input is reserved. Try another, or cancel with Esc or D-pad ←."
		return
	var previous: int = _bindings[_capture_action][_capture_column]
	var note := "Binding saved."
	for action: StringName in _bindings:
		if action != _capture_action and _bindings[action][_capture_column] == code:
			if not Bindings.accepts(previous, _capture_column):
				%Note.text = "That input is already assigned. Choose an unused input or change the other binding first."
				return
			_bindings[action][_capture_column] = previous
			note = "Swapped with %s." % Bindings.ACTIONS[action][0]
			break
	_bindings[_capture_action][_capture_column] = code
	finish_capture(note)
	preference_changed.emit("bindings", _bindings)


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


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _previous_tab() -> void:
	turn_tab(-1)


func _next_tab() -> void:
	turn_tab(1)


func turn_tab(direction: int) -> void:
	var tabs: TabContainer = %Tabs
	tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
	var first_controls: Array[Control] = [%WindowMode, %Level, _binding_rows[&"ui_accept"].get_node("Keyboard"), %Motion]
	var focus := first_controls[tabs.current_tab]
	if focus is BaseButton and focus.disabled:
		focus = %Close
	focus.grab_focus()


func _tab_changed(index: int) -> void:
	if not is_node_ready() or index < 0:
		return
	var tabs: TabContainer = %Tabs
	if index != 2 and not _capture_action.is_empty():
		finish_capture(SAVED_NOTE)
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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_options"):
		set_input_as_handled()
		close_requested.emit()
	elif event.is_action_pressed("menu_previous") or event.is_action_pressed("menu_next"):
		set_input_as_handled()
		turn_tab(1 if event.is_action_pressed("menu_next") else -1)
