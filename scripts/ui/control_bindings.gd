extends RefCounted
## Action bindings shared by menus, folios, and combat presentation.

const ACTIONS := {
	&"ui_accept": ["Confirm / play card", KEY_ENTER, JOY_BUTTON_A],
	&"ui_cancel": ["Back / cancel", KEY_ESCAPE, JOY_BUTTON_B],
	&"menu_options": ["Open or close Options", KEY_F10, JOY_BUTTON_START],
	&"menu_previous": ["Previous tab / page", KEY_PAGEUP, JOY_BUTTON_LEFT_SHOULDER],
	&"menu_next": ["Next tab / page", KEY_PAGEDOWN, JOY_BUTTON_RIGHT_SHOULDER],
	&"combat_pile": ["Inspect draw pile", KEY_P, JOY_BUTTON_X],
	&"combat_guide": ["Open Pattern guide", KEY_G, JOY_BUTTON_BACK],
	&"combat_end": ["End turn", KEY_F, JOY_BUTTON_Y],
	&"combat_inspect": ["Inspect focused card", KEY_I, JOY_BUTTON_LEFT_STICK],
	&"focus_tooltips": ["Toggle controller tooltips", KEY_F1, JOY_BUTTON_RIGHT_STICK],
	&"ui_up": ["Move focus up", KEY_W, -1],
	&"ui_left": ["Move focus left", KEY_A, -1],
	&"ui_down": ["Move focus down", KEY_S, -1],
	&"ui_right": ["Move focus right", KEY_D, -1],
}
const FIXED_NAVIGATION := {
	&"ui_up": [KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
	&"ui_left": [KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
	&"ui_down": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	&"ui_right": [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
}
const GAMEPAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View / Select", JOY_BUTTON_START: "Menu / Start",
	JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
const FIXED_KEYS := [KEY_ESCAPE, KEY_SPACE, KEY_KP_ENTER, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const SPARE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_F6, KEY_F7, KEY_F8]


static func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = [ACTIONS[action][1], ACTIONS[action][2]]
	return result


static func accepts(code: int, column: int) -> bool:
	if column == 1:
		return GAMEPAD_NAMES.has(code)
	return code > 0 and not FIXED_KEYS.has(code) and not OS.get_keycode_string(code).is_empty()


static func sanitize(saved: Variant) -> Dictionary:
	var result := defaults()
	if not saved is Dictionary:
		return result
	# Move the old default Inspect binding so R3 can toggle help. Keep custom assignments.
	var old_inspect: Variant = saved.get(&"combat_inspect")
	if not saved.has(&"focus_tooltips") and old_inspect is Array and old_inspect.size() == 2 and old_inspect[1] == JOY_BUTTON_RIGHT_STICK:
		saved = saved.duplicate(true)
		saved[&"combat_inspect"][1] = JOY_BUTTON_LEFT_STICK
		saved[&"focus_tooltips"] = [KEY_F1, JOY_BUTTON_RIGHT_STICK]
	for column in range(2):
		var replacements := {}
		var used := []
		for action in ACTIONS:
			var pair: Variant = saved.get(action)
			var default_code: int = result[action][column]
			if default_code == -1:
				replacements[action] = default_code
				continue
			if not pair is Array or pair.size() != 2:
				continue
			var code: Variant = pair[column]
			if not code is int or (code != default_code and not accepts(code, column)) or used.has(code):
				continue
			replacements[action] = code
			used.append(code)
		for action in ACTIONS:
			if not replacements.has(action):
				var candidates := [result[action][column]]
				candidates.append_array(GAMEPAD_NAMES.keys() if column == 1 else SPARE_KEYS)
				for code in candidates:
					if not used.has(code):
						replacements[action] = code
						used.append(code)
						break
			result[action][column] = replacements[action]
	return result


static func apply(bindings: Dictionary) -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.keycode = bindings[action][0]
		InputMap.action_add_event(action, key)
		var pad := InputEventJoypadButton.new()
		pad.device = -1
		if FIXED_NAVIGATION.has(action):
			var movement: Array = FIXED_NAVIGATION[action]
			var arrow := InputEventKey.new()
			arrow.keycode = movement[0]
			InputMap.action_add_event(action, arrow)
			var stick := InputEventJoypadMotion.new()
			stick.device = -1
			stick.axis = movement[2]
			stick.axis_value = movement[3]
			InputMap.action_add_event(action, stick)
			pad.button_index = movement[1]
		else:
			pad.button_index = bindings[action][1]
		InputMap.action_add_event(action, pad)
	# Keep an escape route through menus even after an accidental remap.
	for fallback in [[&"ui_cancel", KEY_ESCAPE], [&"ui_accept", KEY_SPACE], [&"ui_accept", KEY_KP_ENTER]]:
		var key := InputEventKey.new()
		key.keycode = fallback[1]
		if not InputMap.action_has_event(fallback[0], key):
			InputMap.action_add_event(fallback[0], key)


static func label(code: int, column: int) -> String:
	if column == 1 and code == -1:
		return "D-pad / stick"
	return GAMEPAD_NAMES.get(code, "?") if column == 1 else OS.get_keycode_string(code)


static func active_label(action: StringName, column: int) -> String:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if column == 0 and event is InputEventKey:
				return label(event.keycode, 0)
			if column == 1 and event is InputEventJoypadButton:
				return label(event.button_index, 1)
	return label(ACTIONS[action][column + 1], column)
