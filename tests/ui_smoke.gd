extends SceneTree

const GameUI = preload("res://scenes/ui/game_ui.tscn")
const Bindings = preload("res://scripts/ui/control_bindings.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, text: String) -> void:
	if not condition:
		failed = true
		push_error(text)


func drag_card(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	root.push_input(press, true)
	var lift := InputEventMouseMotion.new()
	lift.button_mask = MOUSE_BUTTON_MASK_LEFT
	lift.relative = Vector2(18, 0)
	lift.position = from + lift.relative
	root.push_input(lift, true)
	var travel := lift.duplicate() as InputEventMouseMotion
	travel.position = to
	travel.relative = to - lift.position
	root.push_input(travel, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = to
	root.push_input(release, true)


func controller_press(button: JoyButton, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func stick_flick(axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var neutral := event.duplicate() as InputEventJoypadMotion
	neutral.axis_value = 0.0
	Input.parse_input_event(neutral)
	Input.flush_buffered_events()


func tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)


func play_puzzle_card(session: RefCounted, id: StringName) -> void:
	for card in session.player_piles.hand:
		if card.definition.id == id:
			check(session.play_card(card), "Puzzle can play %s" % id)
			return
	check(false, "Puzzle hand contains %s" % id)


func run() -> void:
	var ui := GameUI.instantiate()
	ui.journey_checkpoint.path = "res://.godot/ui_smoke-journey-%d.checkpoint" % Time.get_ticks_usec()
	ui.relics.save_path = "res://.godot/ui-relics-%d.cfg" % Time.get_ticks_usec()
	ui.options_path = "res://.godot/ui-test-options-%d.cfg" % Time.get_ticks_usec()
	root.add_child(ui)
	ui.library.save_path = "res://.godot/ui-test-decks.json"
	ui.library.decks.assign([{"name": "Test", "cards": {"strike": 5, "block": 5}}])
	check(ui.screen == "menu", "Main menu opens")
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == ui.main_menu.get_node("%JourneyButton"), "First stick input focuses the primary Play button")
	await process_frame
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == ui.main_menu.find_child("LessonButton"), "Right from Play focuses the tutorial")
	var old_bindings := Bindings.defaults()
	old_bindings.erase(&"combat_inspect")
	old_bindings[&"combat_pile"] = [KEY_I, JOY_BUTTON_RIGHT_STICK]
	var migrated := Bindings.sanitize(old_bindings)
	check(migrated[&"combat_pile"] == [KEY_I, JOY_BUTTON_RIGHT_STICK] and migrated[&"combat_inspect"][0] != KEY_I and migrated[&"combat_inspect"][1] != JOY_BUTTON_RIGHT_STICK, "New actions preserve saved bindings and receive free inputs")
	var legacy_help := Bindings.defaults()
	legacy_help.erase(&"focus_tooltips")
	legacy_help[&"combat_inspect"] = [KEY_U, JOY_BUTTON_RIGHT_STICK]
	var help_migration := Bindings.sanitize(legacy_help)
	check(help_migration[&"combat_inspect"] == [KEY_U, JOY_BUTTON_LEFT_STICK] and help_migration[&"focus_tooltips"][1] == JOY_BUTTON_RIGHT_STICK, "The R3 help migration preserves the custom keyboard Inspect binding")
	controller_press(JOY_BUTTON_START)
	var options := ui.get_node("OptionsMenu")
	check(options.visible, "Options opens from the main menu")
	var tabs: TabContainer = options.get_node("%Tabs")
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	options.push_input(shoulder, true)
	check(tabs.current_tab == 1, "RB switches to the next Options tab")
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	options.push_input(shoulder, true)
	check(tabs.current_tab == 0, "LB switches to the previous Options tab")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 0.85
	options.push_input(trigger, true)
	check(tabs.current_tab == 0, "Triggers leave the Options tab unchanged")
	await process_frame
	var quit_clicked := [false]
	for connection: Dictionary in options.quit_requested.get_connections():
		options.quit_requested.disconnect(connection.callable)
	options.quit_requested.connect(func(): quit_clicked[0] = true)
	var quit_button: Button = options.get_node("%Quit")
	check(quit_button.is_visible_in_tree() and not quit_button.disabled, "Options exposes an enabled Quit game button")
	quit_button.grab_focus()
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	options.push_input(confirm, true)
	var confirm_release := confirm.duplicate() as InputEventJoypadButton
	confirm_release.pressed = false
	options.push_input(confirm_release, true)
	check(quit_clicked[0], "Quit game requests exit from inside Options")
	options.get_node("%Level").value = 65
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.65), "Options volume updates the live audio bus")
	options.get_node("%Effects").value = 40
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Effects")), 0.4), "Effects volume uses its own audio bus")
	options.get_node("%WindowMode").item_selected.emit(0)
	check(ui.window_mode == 0 and not options.get_node("%WindowSize").disabled, "Windowed mode enables the window size selector")
	options.get_node("%WindowSize").item_selected.emit(2)
	options.get_node("%SwapShoulders").button_pressed = true
	ui.master_volume = 100.0
	ui.effects_volume = 100.0
	ui.window_size = 0
	ui.swap_shoulders = false
	ui.load_options()
	check(ui.master_volume == 65.0 and ui.effects_volume == 40.0 and ui.window_size == 2 and ui.swap_shoulders, "Options reload audio, display, and controller preferences")
	options.get_node("%Level").value = 100
	options.get_node("%Effects").value = 100
	await process_frame
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	options.push_input(back, true)
	check(not options.visible, "B closes Options")
	await process_frame
	ui.show_options()
	options = ui.get_node("OptionsMenu")
	tabs = options.get_node("%Tabs")
	tabs.current_tab = 2
	var binding_rows: Control = options.get_node("%Bindings")
	binding_rows.get_child(2).get_node("Keyboard").pressed.emit()
	var rebound_key := InputEventKey.new()
	rebound_key.keycode = KEY_F9
	rebound_key.pressed = true
	options.push_input(rebound_key, true)
	binding_rows.get_child(3).get_node("Gamepad").pressed.emit()
	var rebound_pad := InputEventJoypadButton.new()
	rebound_pad.button_index = JOY_BUTTON_X
	rebound_pad.pressed = true
	options.push_input(rebound_pad, true)
	check(tabs.current_tab == 2, "The capture event does not also navigate")
	check(ui.control_bindings[&"combat_pile"][1] == JOY_BUTTON_LEFT_SHOULDER, "Binding an occupied button swaps its former action")
	options.push_input(rebound_pad, true)
	check(tabs.current_tab == 1 and options.get_node("%PreviousTab").text.contains("X"), "The rebound gamepad input navigates and updates the tab prompt")
	var next_page_key := InputEventKey.new()
	next_page_key.keycode = KEY_PAGEDOWN
	next_page_key.pressed = true
	options.push_input(next_page_key, true)
	check(tabs.current_tab == 2, "The keyboard page shortcut navigates Options")
	options.get_node("%MovementBindings").get_child(3).get_node("Keyboard").pressed.emit()
	var movement_key := InputEventKey.new()
	movement_key.keycode = KEY_L
	movement_key.pressed = true
	options.push_input(movement_key, true)
	var standard_right := movement_key.duplicate() as InputEventKey
	standard_right.keycode = KEY_RIGHT
	check(movement_key.is_action_pressed("ui_right") and standard_right.is_action_pressed("ui_right"), "Alternate movement can be rebound while arrow keys still work")
	options.push_input(rebound_key, true)
	check(not options.visible, "The rebound keyboard shortcut closes Options")
	await process_frame
	ui.load_options()
	root.push_input(rebound_key, true)
	options = ui.get_node("OptionsMenu")
	check(options.visible and ui.control_bindings[&"menu_options"][0] == KEY_F9, "Rebound inputs persist across preference reloads")
	options.get_node("%ResetBindings").pressed.emit()
	check(ui.control_bindings[&"menu_previous"][1] == JOY_BUTTON_LEFT_SHOULDER, "Reset restores the default gamepad button")
	options.push_input(back, true)
	ui.show_library(false)
	ui.show_editor(0, false)
	var editor: Node = ui.body.get_node("DeckEditor")
	var strike_entry := editor.get_node("%Cards/strike")
	var search: LineEdit = editor.find_child("CatalogueSearch", true, false)
	search.text = "inkblot"
	search.text_changed.emit(search.text)
	check(not strike_entry.visible and editor.get_node("%Cards/inkblot").visible, "Catalogue search matches card names")
	search.text = "apply 4 poison"
	search.text_changed.emit(search.text)
	check(not strike_entry.visible and editor.get_node("%Cards/inkblot").visible, "Catalogue search matches effect descriptions")
	var energy_filter: OptionButton = editor.find_child("CatalogueEnergy", true, false)
	energy_filter.select(1)
	energy_filter.item_selected.emit(1)
	check(not editor.get_node("%Cards/inkblot").visible, "Energy filter combines with effect search")
	editor.find_children("*", "Button", true, false).filter(func(button): return button.text == "Clear filters")[0].pressed.emit()
	check(strike_entry.visible and editor.get_node("%Cards/inkblot").visible, "Clear filters restores the full catalogue")
	check(editor.get_node("%DeckProfile").text.contains("1E ×10") and editor.get_node("%DeckProfile").text.contains("Damage cards 5"), "Deck profile counts energy costs and damage copies")
	search.clear()
	search.text_changed.emit("")
	var category_filter: OptionButton = editor.find_child("CatalogueCategory", true, false)
	category_filter.select(2)
	category_filter.item_selected.emit(2)
	check(not strike_entry.visible and editor.get_node("%Cards/block").visible, "Catalogue filters by category")
	category_filter.select(0)
	category_filter.item_selected.emit(0)
	var owned: CheckButton = editor.find_child("CatalogueInDeck", true, false)
	owned.button_pressed = true
	check(strike_entry.visible and not editor.get_node("%Cards/inkblot").visible, "In-deck filter hides unowned copies")
	owned.button_pressed = false
	var inkblot: RichTextLabel = editor.get_node("%Cards/inkblot/Card/Content/Description")
	check(inkblot.text.contains("[color=#155479]Gain 4 block") and inkblot.text.contains("[color=#285524]Apply 4 Poison"), "A single card distinguishes its Block and Poison effects")
	check(inkblot.get_parsed_text() == "Gain 4 block. Apply 4 Poison.", "Color preserves the readable card description")
	await process_frame
	await process_frame
	var strike_face: Button = strike_entry.get_node("Card/HitArea/Play")
	tap(strike_face.get_global_rect().get_center())
	check(editor == ui.body.get_node("DeckEditor") and strike_entry.get_node("Card/Content/Footer").text == "6 IN DECK", "Adding a card updates the visible count without rebuilding the editor")
	strike_face.grab_focus()
	controller_press(JOY_BUTTON_A)
	controller_press(JOY_BUTTON_A, false)
	check(ui.library.total(ui.library.decks[0]) == 12, "Confirm adds exactly one copy on the focused card")
	check(editor.get_node("%Total").text.contains("Attack 7") and editor.get_node("%JourneyStatus").text == "Ready for a Journey.", "Workshop reports category mix and Journey readiness")
	check(editor.get_node("%DeckContents/strike/Caption").text == "Strike ×7" and not editor.get_node("%DeckContents/inkblot").visible, "Deck tray shows only cards with copies and updates with catalogue input")
	var tray: Control = editor.get_node("%DeckTray")
	drag_card(strike_face.get_global_rect().get_center(), tray.get_global_rect().position + Vector2(30, 18))
	check(ui.library.total(ui.library.decks[0]) == 13, "Dragging a catalogue card to the tray adds exactly one copy")
	editor.get_node("%DeckContents/strike/Remove").pressed.emit()
	var catalogue: ScrollContainer = editor.get_node("%CatalogueScroll")
	catalogue.scroll_vertical = int(catalogue.get_v_scroll_bar().max_value)
	await process_frame
	var late_card: Button = editor.get_node("%Cards/revision_note/Card/HitArea/Play")
	check(catalogue.get_global_rect().has_point(late_card.get_global_rect().get_center()), "Scrolling the catalogue exposes later cards alongside the tray")
	drag_card(late_card.get_global_rect().get_center(), tray.get_global_rect().position + Vector2(30, 18))
	check(ui.library.decks[0].cards.get("revision_note", 0) == 1, "A new card below the fold can be dragged into the visible deck tray")
	editor.get_node("%DeckContents/revision_note/Remove").pressed.emit()
	ui.library.load_decks()
	check(ui.library.total(ui.library.decks[0]) == 12, "Deck survives save/reload")
	ui.change_count(0, "strike", -1, false)
	ui.change_count(0, "strike", -1, false)
	ui.show_setup()
	check(ui.valid_selection() and ui.player_index == 0 and ui.enemy_index == 0, "First usable deck is selected for both sides")
	ui.player_index = 0
	ui.enemy_index = 0
	ui.show_table()
	var drag_table: Control = ui.body.get_node("CombatTable")
	await process_frame
	await process_frame
	var drag_row: HBoxContainer = drag_table.hand_row
	var first: Control = drag_row.get_child(0)
	drag_table.pile_row.get_node("DrawPile").grab_focus()
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == drag_table.pile_row.get_node("DiscardPile"), "Right from Draw focuses Discard")
	await process_frame
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == drag_table.pile_row.get_node("ExhaustPile"), "Right from Discard focuses Exhaust")
	await process_frame
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == drag_table.pile_row.get_node("ExhaustPile"), "Right at the pile edge stays in the row")
	drag_table.end_button.grab_focus()
	await process_frame
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	var brace_help: Button = drag_table.get_node("%Brace")
	check(root.gui_get_focus_owner() == brace_help, "Right from End Turn focuses Brace even with no Cadence")
	await process_frame
	var focus_help: Control = ui.get_node("%FocusHelp")
	check(focus_help._text.contains("BRACE") and focus_help._text.contains("0 Cadence"), "Controller focus shows the unavailable Brace tooltip")
	await process_frame
	check(focus_help._tooltip.find_child("DismissHint", true, false).text == "R3 · Hide help", "Controller help keeps its dismiss shortcut visible inside the tooltip")
	check(not focus_help._tooltip.get_global_rect().intersects(focus_help.protected_control.get_global_rect()), "Controller tooltip leaves the toolbar help toggle visible")
	controller_press(JOY_BUTTON_RIGHT_STICK)
	await process_frame
	check(not focus_help.hints_enabled and focus_help._text.is_empty(), "R3 hides controller tooltips")
	controller_press(JOY_BUTTON_RIGHT_STICK)
	await process_frame
	check(focus_help.hints_enabled and focus_help._text.contains("BRACE"), "R3 restores the current tooltip")
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	check(root.gui_get_focus_owner() == drag_table.get_node("%CadenceDraw") and focus_help._text.contains("draw 1 card"), "Right from Brace focuses Cadence Draw and shows its tooltip")
	controller_press(JOY_BUTTON_RIGHT_SHOULDER)
	check(root.gui_get_focus_owner() == first.get_node("%Play"), "Swapped controller shoulders focus the hand")
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	root.push_input(arrow, true)
	var next_card: Control = drag_row.get_child(1)
	check(root.gui_get_focus_owner() == next_card.get_node("%Play"), "Right arrow moves to the next hand card")
	var outline := next_card.get_theme_stylebox("panel") as StyleBoxFlat
	check(outline.border_width_left == 5 and next_card.get_node("%FocusBadge").visible, "The focused card face has a high-contrast frame and marker")
	await process_frame
	check(next_card.position.y < first.position.y, "The focused card lifts out of the hand")
	controller_press(JOY_BUTTON_DPAD_LEFT)
	check(root.gui_get_focus_owner() == first.get_node("%Play"), "D-pad moves focus back to the previous card")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	check(root.gui_get_focus_owner() == next_card.get_node("%Play"), "Left stick moves focus across the hand")
	var neutral := stick.duplicate() as InputEventJoypadMotion
	neutral.axis_value = 0.0
	Input.parse_input_event(neutral)
	Input.flush_buffered_events()
	controller_press(JOY_BUTTON_X)
	var pile := drag_table.get_node("PileBrowser") as Window
	check(pile.visible, "X opens the draw pile")
	pile.push_input(back, true)
	check(not pile.visible and ui.screen == "table", "B closes the pile without leaving combat")
	drag_table.session.cadence = 2
	drag_table.refresh_intent()
	var rival_shortcut := drag_table.get_node_or_null("%RivalShortcut") as Label
	check(rival_shortcut != null and rival_shortcut.is_visible_in_tree() and rival_shortcut.text.ends_with(Bindings.active_label(&"menu_previous", 1)), "Rival line shows its swapped controller binding")
	controller_press(JOY_BUTTON_LEFT_SHOULDER)
	check(root.gui_get_focus_owner() == drag_table.rewrite_row.get_child(0), "Controller shortcut focuses a rewritable rival card")
	check(drag_table.get_node("%ThreatPreview").text.begins_with("REWRITE PREVIEW") and drag_table.session.cadence == 2, "Rival shortcut previews Rewrite without spending Cadence")
	check(drag_table.rewrite_row.get_child(0).get_node("%Index").text.begins_with("▶"), "The focused rival card shows a focus marker")
	drag_table.configure_controller(true, false)
	check(rival_shortcut.text.ends_with(Bindings.active_label(&"menu_next", 1)), "Rival line shows the unswapped controller binding")
	drag_table.configure_controller(false, false)
	check(not rival_shortcut.is_visible_in_tree(), "Disabling combat shortcuts hides the rival binding")
	drag_table.configure_controller(true, true)
	var saved_bindings: Dictionary = ui.control_bindings.duplicate(true)
	var rival_rebind := saved_bindings.duplicate(true)
	rival_rebind[&"menu_previous"] = [KEY_U, JOY_BUTTON_X]
	rival_rebind[&"combat_pile"][1] = JOY_BUTTON_LEFT_SHOULDER
	ui.change_option("bindings", rival_rebind)
	check(rival_shortcut.is_visible_in_tree() and rival_shortcut.text.ends_with("U / X"), "Rival line updates after both inputs are rebound")
	controller_press(JOY_BUTTON_RIGHT_SHOULDER)
	controller_press(JOY_BUTTON_X)
	check(root.gui_get_focus_owner() == drag_table.rewrite_row.get_child(0), "The rebound shortcut still focuses the rewritable rival card")
	ui.change_option("bindings", saved_bindings)
	var intent: Button = drag_table.rewrite_row.get_child(0)
	var inspected_intent: CardInstance = intent.get_meta("card")
	await process_frame
	tap(intent.get_global_rect().get_center())
	var touch_inspection: Window = drag_table.get_node_or_null("IntentInspection")
	check(touch_inspection != null and touch_inspection.visible and drag_table.session.cadence == 2, "An actual tap offers inspection without spending Cadence")
	if touch_inspection != null:
		touch_inspection.push_input(back, true)
		await process_frame
	intent.grab_focus()
	controller_press(JOY_BUTTON_LEFT_STICK)
	var intent_window: Window = drag_table.get_node("IntentInspection")
	check(intent_window.visible and drag_table.session.cadence == 2, "L3 inspects the focused rival card without spending Cadence")
	intent_window.push_input(back, true)
	await process_frame
	controller_press(JOY_BUTTON_A)
	controller_press(JOY_BUTTON_A, false)
	check(not drag_table.has_node("IntentInspection") and drag_table.enemy_piles.hand.back() == inspected_intent and drag_table.session.cadence == 0, "A directly rewrites after both touch and L3 inspection")
	if drag_table.rewrite_fx.is_active():
		await drag_table.rewrite_fx.finished
	drag_table.rewrite_row.get_child(0).grab_focus()
	controller_press(JOY_BUTTON_A)
	controller_press(JOY_BUTTON_A, false)
	check(not drag_table.has_node("IntentInspection"), "Confirm on an unavailable Rewrite does not reopen inspection")
	check(drag_table.message.text.contains("already used"), "Unavailable Rewrite explains why the action failed")
	first = drag_row.get_child(0)
	var second: Control = drag_row.get_child(1)
	var dragged: CardInstance = first.get_meta("card")
	drag_card(first.get_global_rect().get_center(), second.get_global_rect().get_center())
	check(drag_row.get_child(1) == first and drag_table.session.statistics.player.cards == 0, "Dragging within the hand reorders cards without playing them")
	await process_frame
	drag_card(first.get_global_rect().get_center(), drag_table.player_hp.get_global_rect().get_center())
	check(drag_table.session.statistics.player.cards == 0 and first.modulate.a == 1.0, "Dropping outside the table returns the card to hand")
	drag_card(first.get_global_rect().get_center(), drag_table.card_stage.get_global_rect().get_center())
	check(drag_table.session.statistics.player.cards == 1 and drag_table.player_piles.discard_pile.has(dragged), "Dropping a card on the table plays it exactly once")
	check(drag_table.card_stage.get_node("%CardMotion").get_child_count() == 1, "A played card appears on the board")
	await process_frame
	await process_frame
	var touch_card: Control = drag_row.get_child(0)
	var touch_point := touch_card.get_global_rect().get_center()
	tap(touch_point)
	check(drag_table.has_selected_card() and drag_table.session.statistics.player.cards == 1, "First touch selects the card without playing it")
	tap(touch_point)
	check(not drag_table.has_selected_card() and drag_table.session.statistics.player.cards == 1, "Tapping the selected card again cancels it")
	tap(touch_point)
	tap(drag_table.card_stage.get_global_rect().get_center())
	check(not drag_table.has_selected_card() and drag_table.session.statistics.player.cards == 2, "Tapping the table plays the selected card exactly once")
	drag_table.session.energy = 0
	drag_table.refresh()
	drag_table.focus_hand()
	var blocked_card: Control = drag_row.get_child(0)
	check(blocked_card.get_node("%FocusBadge").visible and blocked_card.get_node("%FocusBadge").text.contains("INSPECTING"), "Cards without enough energy still show a focus marker")
	controller_press(JOY_BUTTON_LEFT_STICK)
	var inspection: Window = drag_table.get_node("CardInspection")
	check(inspection.get_node("%CardPreview").visible and inspection.get_node("%Body").get_parsed_text().contains("you have 0"), "Inspect shows the actual card and its current energy restriction")
	inspection.push_input(back, true)
	check(not inspection.visible and root.gui_get_focus_owner() == blocked_card.get_node("%Play"), "Closing inspection restores hand focus")
	await process_frame
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = blocked_card.get_global_rect().get_center()
	right_click.pressed = true
	root.push_input(right_click, true)
	var right_release := right_click.duplicate() as InputEventMouseButton
	right_release.pressed = false
	root.push_input(right_release, true)
	inspection = drag_table.get_node("CardInspection")
	check(inspection.visible, "Right-click opens the focused card inspection")
	inspection.push_input(back, true)
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(drag_table.session.statistics.player.cards == 2, "Confirm cannot play an unaffordable card")
	ui.show_table()
	var table = ui.body.get_node("CombatTable")
	await process_frame
	check(table.player_piles.hand.size() == 5, "Player draws opening hand")
	check(table.enemy_piles.draw_pile.size() == 5 and table.enemy_piles.hand.size() == 5, "Enemy prepares its upcoming hand")
	check(table.player_piles.hand[0] != table.enemy_piles.draw_pile[0], "Same recipe creates independent sides")
	var played_card = table.player_piles.hand[0]
	var play_button: Button = table.hand_row.get_child(0).find_child("Play", true, false)
	var card_view: Control = table.hand_row.get_child(0)
	check(play_button.get_global_rect().size.is_equal_approx(card_view.get_global_rect().size), "Whole card is the play target")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = card_view.get_global_rect().get_center()
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	var tooltip: Control = play_button.call("_make_custom_tooltip", play_button.tooltip_text)
	check(is_equal_approx(tooltip.get_theme_stylebox("panel").bg_color.a, 0.88), "Custom card tooltip background is slightly translucent")
	tooltip.free()
	check(is_equal_approx(ui.theme.get_stylebox("panel", "TooltipPanel").bg_color.a, 0.88), "Fallback tooltip theme matches the translucent custom tooltip")
	check(table.energy_label.tooltip_text.contains("Surge") and table.energy_label.mouse_filter != Control.MOUSE_FILTER_IGNORE, "Energy help is hoverable")
	check(table.relic_label.tooltip_text.contains("WAR DRUM") and table.turn_label.tooltip_text.contains("TURN"), "Artifact and turn information have help")
	check(table.player_hp.get_node("Overlay/BlockText").tooltip_text.contains("Poison"), "Block text explains damage absorption and Poison")
	check(table.pile_row.get_node("DrawPile").tooltip_text.contains("shuffled"), "Draw pile stack explains recycling")
	check(table.session.energy == 2 and table.player_piles.discard_pile.has(played_card), "UI play resolves effect and spends energy")
	check(table.player_hp.value == table.session.player.health and table.enemy_hp.value == table.session.enemy.health, "HP bars match combat state")
	check(table.combat_log.text.contains("played"), "Combat log displays resolved actions")
	check(table.player_block.value == mini(table.session.player.block, table.session.player.max_health), "Player block bar matches combat state")
	check(table.enemy_block.value == mini(table.session.enemy.block, table.session.enemy.max_health), "Rival block bar matches combat state")
	check(table.intent_scroll.is_visible_in_tree() and table.rewrite_row.get_child_count() > 0, "Rival intent appears during player turn")
	table.session.player.gain_block(80)
	table.session.enemy.apply_poison(3)
	table.refresh()
	check(table.player_block.value == 30 and table.session.player.block >= 80, "Full block bar never clamps actual block")
	check(table.player_hp.get_node("Overlay/BlockText").text == "BLOCK %d" % table.session.player.block, "Block text shows the uncapped amount on the HP bar")
	check(table.enemy_status.text == "POISON 3" and table.enemy_status.visible, "Poison status appears on affected side")
	table.session.player.clear_block()
	table.refresh()
	check(not table.player_block.visible, "Zero block hides the blue bar")
	table.session.enemy.apply_poison(100)
	table.refresh()
	check(table.intent_label.text.contains("Lethal Poison"), "Intent explains when Poison will prevent rival actions")
	# Restore a nonlethal fixture before the remaining navigation checks.
	table.session.enemy.poison = 3
	table.refresh()
	table.sandbox = true
	var card = table.player_piles.hand[0]
	table.move_card(card, true)
	check(table.player_piles.exhaust_pile.size() == 1, "Exhaust button moves card")
	table.next_hand()
	check(table.player_piles.hand.size() == 5, "Next hand draws five")
	# Exhaust six of ten, redrawing only the four surviving instances.
	while table.player_piles.exhaust_pile.size() < 6:
		if table.player_piles.hand.is_empty():
			table.draw_one()
		table.move_card(table.player_piles.hand[0], true)
	for cycle in range(3):
		table.next_hand()
		check(table.player_piles.hand.size() == 4, "UI redraw cannot invent a fifth card")
		check(table.player_piles.total_cards() == 10, "UI conserves total card count")
	table.configure_controller(false, false)
	controller_press(JOY_BUTTON_Y)
	check(not table.session.player_turn and table.end_button.disabled, "Y ends the turn even when optional focus shortcuts are disabled")
	ui.body.get_node("TableToolbar").get_node("%Options").pressed.emit()
	var combat_options := ui.get_node("OptionsMenu")
	check(table.rival_timer.is_stopped(), "Opening Options from combat pauses rival playback")
	combat_options.get_node("%Close").pressed.emit()
	check(not table.rival_timer.is_stopped(), "Closing Options resumes rival playback")
	var sample: Array[CardInstance] = [CardInstance.new(StarterDeck.STRIKE), CardInstance.new(StarterDeck.BLOCK), CardInstance.new(StarterDeck.STRIKE)]
	table.inspect_pile("Draw", sample)
	var pile_view: Window = table.get_node("PileBrowser")
	var previews := pile_view.get_node("%Cards")
	check(previews.get_child_count() == 2 and previews.get_child(0).get_node("%Title").text == "Block", "Pile viewer groups copies and sorts independently of draw order")
	check(previews.get_child(1).get_node("%Footer").text == "×2 COPIES" and not previews.get_child(1).get_node("%Play").visible, "Pile card shows the copy count without a play button")
	check(table.rival_timer.is_stopped(), "Pile viewer pauses rival playback")
	pile_view.get_node("%Close").pressed.emit()
	check(not table.rival_timer.is_stopped(), "Closing the pile viewer resumes rival playback")
	while not table.session.player_turn and table.session.outcome.is_empty():
		table.rival_timer.timeout.emit()
	check(table.rival_timer.is_stopped(), "Paced turn stops its timer on completion")
	check(table.combat_log.text.contains("Rival played"), "Combat log includes rival actions after end turn")
	check(table.player_hp.value == table.session.player.health, "HP bar updates after rival damage")
	ui.show_setup()
	ui.confirm_remove(0, true)
	for child in ui.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
	check(ui.library.decks.is_empty(), "Remove deck updates library")
	check(not ui.valid_selection(), "Removal clears selections")
	ui.library.decks.assign([
		{"name": "Empty", "cards": {}},
		{"name": "First usable", "cards": {"block": 5}},
		{"name": "Other", "cards": {"strike": 5}}
	])
	ui.show_setup()
	check(ui.player_index == 1 and ui.enemy_index == 1, "Defaults skip empty decks")
	ui.enemy_index = 2
	ui.show_menu()
	ui.show_setup()
	check(ui.enemy_index == 2, "Chosen deck survives navigation within the session")
	ui.set_fast_turns(true)
	ui.show_table()
	var finale = ui.body.get_node("CombatTable")
	check(is_equal_approx(finale.rival_timer.wait_time, 0.70), "Fast-turn choice applies the slower playback to new encounters")
	finale.session.enemy.take_damage(39)
	finale.session.enemy.apply_poison(3)
	finale.end_turn()
	check(ui.screen == "result" and is_instance_valid(ui.result_overlay), "Poison victory opens the result panel")
	check(finale.rival_timer.is_stopped(), "Lethal turn-start Poison does not start a presentation timer")
	await process_frame
	var result_focus := root.gui_get_focus_owner()
	controller_press(JOY_BUTTON_BACK)
	check(not finale.has_node("PatternGuide") and root.gui_get_focus_owner() == result_focus, "Pattern guide shortcut leaves the victory popup in control")
	var result_review: Button = ui.result_overlay.get_node("%Review")
	stick_flick(JOY_AXIS_LEFT_Y, -1.0)
	check(root.gui_get_focus_owner() == result_review, "Stick up wraps from the primary result action to Review")
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(ui.screen == "table" and not is_instance_valid(ui.result_overlay), "Review closes the panel and preserves the finished table")
	check(finale.session.outcome == "Victory", "Review does not restart combat")
	check(root.gui_get_focus_owner() == finale.end_button, "Review focuses Encounter results on the finished table")
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(ui.screen == "result", "Finished table can reopen its encounter results")
	ui.result_overlay.find_child("Rematch", true, false).pressed.emit()
	var rematch = ui.body.get_node("CombatTable")
	check(rematch.session.outcome.is_empty() and rematch.session.player.health == 30 and rematch.session.enemy.health == 40, "Rematch starts fresh combat with selected decks")
	check(rematch.session.statistics.player.cards == 0 and rematch.session.enemy.poison == 0, "Rematch resets statistics and statuses")
	rematch.session.enemy.apply_poison(99)
	rematch.end_turn()
	ui.result_overlay.find_child("ChooseDecks", true, false).pressed.emit()
	check(ui.screen == "setup" and ui.enemy_index == 2, "Result navigation preserves deck selections")
	ui.show_table()
	var departing = ui.body.get_node("CombatTable")
	departing.end_turn()
	var departing_timer: Timer = departing.rival_timer
	ui.show_setup()
	await process_frame
	check(not is_instance_valid(departing_timer), "Leaving a table frees its pending rival timer")
	ui.library.decks.assign([{"name": "Attack test", "cards": {"strike": 5}}])
	ui.player_index = 0
	ui.enemy_index = 0
	ui.show_table()
	var attacks = ui.body.get_node("CombatTable")
	var first_view = attacks.hand_row.get_child(0)
	check(first_view.find_child("Description", true, false).get_parsed_text() == "Deal 11 damage.", "Hand card displays effective attack including pending artifact trigger")
	first_view.inspected.emit()
	check(attacks.message.text.contains("11 HP") and attacks.session.statistics.player.cards == 0, "Card inspection shows forecast without playing the card")
	var keyboard_play: Button = first_view.find_child("Play", true, false)
	keyboard_play.grab_focus()
	var key_press := InputEventKey.new()
	key_press.keycode = KEY_ENTER
	key_press.pressed = true
	root.push_input(key_press, true)
	var key_release := key_press.duplicate() as InputEventKey
	key_release.pressed = false
	root.push_input(key_release, true)
	check(attacks.session.statistics.player.cards == 1, "Keyboard Enter plays the focused card")
	check(root.gui_get_focus_owner() == attacks.hand_row.get_child(0).get_node("%Play"), "Hand focus follows the next card after playing")
	check(attacks.hand_row.get_child(0).find_child("Description", true, false).get_parsed_text() == "Deal 12 damage.", "Card text refreshes after artifact activation")
	attacks.session.enemy.take_damage(28)
	controller_press(JOY_BUTTON_A)
	var accept_release := InputEventJoypadButton.new()
	accept_release.button_index = JOY_BUTTON_A
	root.push_input(accept_release, true)
	check(ui.screen == "result" and attacks.session.outcome == "Victory", "Lethal player card also opens encounter results")
	controller_press(JOY_BUTTON_B)
	check(ui.screen == "table", "B returns from results to the board")
	controller_press(JOY_BUTTON_B)
	check(ui.screen == "setup", "B on the board follows the Leave table action")
	ui.library.decks.assign([ui.library.counterpoint_recipe()])
	ui.library.save()
	ui.library.load_decks()
	check(ui.library.total(ui.library.decks[0]) == 10 and ui.library.decks[0].cards.crosscut == 2, "Counterpoint deck persists new card IDs")
	ui.show_table()
	var rhythm = ui.body.get_node("CombatTable")
	var opener: CardInstance = rhythm.player_piles.hand[0]
	var followup: CardInstance = null
	for candidate in rhythm.player_piles.hand:
		if candidate.definition.category != opener.definition.category:
			followup = candidate
			break
	rhythm.play_card(opener)
	rhythm.play_card(followup)
	check(rhythm.session.cadence == 2 and rhythm.artifact_label.text.contains("CADENCE 2/3"), "Changing categories updates Cadence in the table")
	await process_frame
	await process_frame
	var rewrite_target: CardInstance = rhythm.enemy_piles.hand[0]
	var rewrite_button: Button = rhythm.rewrite_row.get_child(0)
	check(not rewrite_button.disabled, "Rival-line button unlocks when Cadence is available")
	rhythm._touch_pointer = true
	rewrite_button.pressed.emit()
	check(not rhythm.has_node("IntentInspection") and rhythm.enemy_piles.hand[-1] == rewrite_target and rhythm.session.cadence == 0, "Rival-line Confirm ignores stale touch state")
	check(rhythm.combat_log.text.contains("Rewrite:"), "Rewrite appears in combat log")
	check(rhythm.rewrite_fx.is_active() and rhythm.rewrite_fx.get_child_count() == 5, "Rewrite animates the selected card and the cards it passes")
	check(rhythm.get_node("%RewriteStatus").text.contains("LINE REWRITTEN"), "The line immediately confirms the Cadence spend")
	await rhythm.rewrite_fx.finished
	check(rhythm.rewrite_fx.get_child_count() == 0 and rhythm.rewrite_row.get_child(-1).modulate.a == 1.0, "Rewrite restores the settled line and frees the animated copies")
	ui.show_table()
	var interrupted = ui.body.get_node("CombatTable")
	interrupted.session.cadence = 2
	interrupted.refresh_intent()
	await process_frame
	await process_frame
	interrupted.rewrite_card(interrupted.enemy_piles.hand[0])
	check(interrupted.rewrite_fx.is_active(), "A second duel starts a fresh Rewrite animation")
	var toolbar := ui.body.get_node("TableToolbar") as HBoxContainer
	toolbar.get_node("%Motion").button_pressed = false
	toolbar.get_node("%Sound").button_pressed = false
	check(not interrupted.rewrite_fx.is_active() and interrupted.rewrite_fx.get_child_count() == 0 and interrupted.rewrite_row.get_child(-1).modulate.a == 1.0, "Disabling Motion during Rewrite settles and reveals the line")
	ui.show_table()
	var quiet_table = ui.body.get_node("CombatTable")
	check(not quiet_table.motion_enabled and not quiet_table.combat_audio.enabled, "Motion and sound preferences carry into the next duel")
	quiet_table.session.cadence = 2
	quiet_table.refresh_intent()
	var quiet_target: CardInstance = quiet_table.enemy_piles.hand[0]
	quiet_table.rewrite_card(quiet_target)
	check(quiet_table.enemy_piles.hand[-1] == quiet_target and not quiet_table.rewrite_fx.is_active(), "Rewrite settles immediately with motion disabled")
	ui.library.decks.assign([{"name": "Patterns", "cards": {"strike": 2, "block": 2, "mend": 2}}])
	ui.show_table()
	var patterns = ui.body.get_node("CombatTable")
	for face: Control in patterns.hand_row.get_children():
		check(face.get_node("%PatternBadge").visible, "Each opening card advertises its Pattern")
	for category in [CardDefinition.Category.GUARD, CardDefinition.Category.TACTIC]:
		for candidate in patterns.player_piles.hand:
			if candidate.definition.category == category:
				patterns.play_card(candidate)
				break
		var expected_category := CardDefinition.Category.TACTIC if category == CardDefinition.Category.GUARD else CardDefinition.Category.ATTACK
		for face: Control in patterns.hand_row.get_children():
			var marked_card: CardInstance = face.get_meta("card")
			check(face.get_node("%PatternBadge").visible == (marked_card.get_category() == expected_category), "Only the next category shows the locked Pattern badge")
	var brace: Button = patterns.get_node("%Brace")
	check(not brace.disabled, "The table offers another spend when Cadence is ready")
	brace.pressed.emit()
	check(patterns.session.cadence == 0 and patterns.session.pattern_history.size() == 2, "Brace spends Cadence without consuming a Pattern step")
	check(patterns.pattern_label.text.contains("Riposte"), "Pattern tracker names the available finisher")
	for index in range(patterns.player_piles.hand.size()):
		var finisher: CardInstance = patterns.player_piles.hand[index]
		if finisher.definition.category == CardDefinition.Category.ATTACK:
			var view = patterns.hand_row.get_child(index)
			check(view.find_child("Description", true, false).get_parsed_text() == "Deal 17 damage.", "Pattern-ready card shows its full effective damage")
			view.inspected.emit()
			check(patterns.message.text.contains("Pattern Riposte") and view.tooltip_text.contains("War Drum bonus: +1"), "Forecast distinguishes Pattern and artifact bonuses")
			view.find_child("Play", true, false).pressed.emit()
			break
	check(patterns.pattern_label.text.contains("PATTERN COMPLETE") and patterns.combat_log.text.contains("Pattern Riposte"), "Completed Pattern appears in tracker and log")
	controller_press(JOY_BUTTON_BACK)
	var guide: Window = patterns.get_node("PatternGuide")
	check(guide.pages.size() == 5 and guide.pages[1].title == "Shelter" and guide.pages[3].title == "Surge" and guide.pages[4].title == "How the rival line resolves", "The guide includes all Patterns and the rival line rules")
	var overview: String = guide.get_node("%Body").get_parsed_text()
	check(overview.contains("Shelter") and overview.contains("Riposte") and overview.contains("Surge"), "The first Pattern Guide page lists all three payoffs")
	guide.get_node("%Next").pressed.emit()
	check(guide.get_node("%PatternSeal").visible and guide.get_node("%Route").get_parsed_text().contains("Guard"), "A recipe page shows its badge and ordered route")
	guide.close_requested.emit()
	ui.library.decks.assign([{"name": "Starter", "cards": {"strike": 5, "block": 5}}])
	ui.player_index = 0
	ui.enemy_index = 0
	ui.show_setup()
	check(ui.library.category_counts(ui.library.decks[0]) == [5, 5, 0], "Deck preparation reports category composition")
	ui.use_counterpoint_deck()
	check(ui.library.decks.size() == 2 and ui.player_index == 1 and ui.library.decks[0].cards.strike == 5, "Counterpoint shortcut adds a suitable deck without altering existing decks")
	ui.use_counterpoint_deck()
	check(ui.library.decks.size() == 2, "Counterpoint shortcut reuses an existing suitable deck")
	ui.show_rivals()
	check(ui.screen == "rivals", "Menu opens rival selection")
	ui.select_rival(1)
	check(ui.screen == "setup" and ui.selected_rival.display_name == "The Warden", "Rival selection opens deck preparation")
	ui.enemy_index = -1
	check(ui.valid_selection(), "Named rivals do not require a custom enemy deck selection")
	ui.show_table()
	var named = ui.body.get_node("CombatTable")
	check(named.session.enemy.max_health == 46 and named.enemy_label.text == "THE WARDEN", "Combat shows selected rival identity and health")
	named.session.enemy.apply_poison(99)
	named.end_turn()
	ui.result_overlay.find_child("Rematch", true, false).pressed.emit()
	check(ui.body.get_node("CombatTable").session.enemy.max_health == 46, "Rematch preserves rival identity")
	check(not ui.body.get_node("CombatTable").get_node("%MarginBurn").visible, "Normal duels hide Margin Burn")
	var marks_before_playtest: int = ui.relics.marks
	ui.show_setup()
	var experiment: CheckButton = ui.body.get_node("MarginBurnPlaytest")
	experiment.button_pressed = true
	for rival_index in range(3):
		ui.select_rival(rival_index)
		ui.show_table()
		var trial: Control = ui.body.get_node("CombatTable")
		var burn: Button = trial.get_node("%MarginBurn")
		var sacrificed: CardInstance = trial.player_piles.hand[1]
		var starting_energy: int = trial.session.energy
		var preview: Dictionary = trial.session.preview_margin_burn(sacrificed)
		check(burn.visible and not burn.disabled and preview.cadence == 2 and preview.rewrite_available, "Each rival supports a fresh Margin Burn and previews a legal Rewrite")
		burn.pressed.emit()
		var dialog: ConfirmationDialog = trial.get_node("MarginBurnDialog")
		check(dialog.visible and dialog.gui_get_focus_owner() == dialog.get_cancel_button(), "Margin Burn asks for explicit confirmation with Cancel focused")
		dialog.push_input(back, true)
		await process_frame
		check(not trial.has_node("MarginBurnDialog") and root.gui_get_focus_owner() == burn and trial.player_piles.hand.has(sacrificed) and trial.session.cadence == 0, "Controller Back closes the preview, restores focus, and leaves the card and Cadence alone")
		burn.pressed.emit()
		dialog = trial.get_node("MarginBurnDialog")
		var picker: OptionButton = dialog.find_child("Sacrifice", true, false)
		var vertical := InputEventJoypadButton.new()
		vertical.pressed = true
		vertical.button_index = JOY_BUTTON_DPAD_UP
		dialog.push_input(vertical, true)
		check(dialog.gui_get_focus_owner() == picker, "D-pad Up reaches the Margin Burn card picker from Cancel")
		vertical.button_index = JOY_BUTTON_DPAD_DOWN
		dialog.push_input(vertical, true)
		check(dialog.gui_get_focus_owner() == dialog.get_cancel_button(), "D-pad Down returns to the safe action")
		dialog.get_ok_button().grab_focus()
		vertical.button_index = JOY_BUTTON_DPAD_UP
		dialog.push_input(vertical, true)
		check(dialog.gui_get_focus_owner() == picker, "D-pad Up reaches the card picker from Exhaust card")
		dialog.push_input(confirm, true)
		dialog.push_input(confirm_release, true)
		check(picker.get_popup().visible and not trial.session.margin_burn_used, "Confirm opens the dropdown without exhausting a card")
		picker.get_popup().hide()
		picker.select(1)
		picker.item_selected.emit(1)
		var burn_forecast: RichTextLabel = dialog.find_child("Forecast", true, false)
		check(burn_forecast.text.contains(trial.session.describe_card(sacrificed)) and burn_forecast.text.contains("Rewrite available"), "The dialog previews the selected sacrifice and the available Rewrite")
		dialog.get_ok_button().pressed.emit()
		check(trial.player_piles.exhaust_pile.has(sacrificed) and trial.session.energy == starting_energy and trial.session.cadence == 2 and trial.session.pattern_history.is_empty(), "Confirm exhausts one card and grants Cadence without spending energy or advancing a Pattern")
		check(burn.disabled and not trial.session.margin_burn(trial.player_piles.hand[0]), "Margin Burn cannot be used twice")
		trial.session.enemy.apply_poison(99)
		trial.end_turn()
	check(ui.relics.marks == marks_before_playtest, "Margin Burn playtests grant no progression Marks")
	ui.start_custom_duel()
	check(ui.selected_rival == null and ui.valid_selection(), "Custom duel restores editable deck-versus-deck setup")
	ui.library.decks.append({"name": "Legacy", "cards": {"strike": 7, "block": 5, "inkblot": 3}})
	ui.library.save()
	ui.library.load_decks()
	ui.player_index = 2
	check(ui.valid_selection() and ui.library.total(ui.library.decks[2]) == 15, "Legacy recipe survives reloading and stays usable in custom duels")
	ui.show_journey_setup()
	check(not ui.body.has_node("MarginBurnPlaytest"), "Journey setup keeps Margin Burn outside campaign progression")
	check(not ui.valid_selection() and ui.library.journey_issues(ui.library.decks[2]).size() == 2, "Journey reports both size and copy violations")
	ui.begin_journey()
	check(ui.journey == null, "Invalid legacy recipes cannot start a Journey directly")
	ui.show_editor(2, true)
	editor = ui.body.get_node("DeckEditor")
	editor.get_node("%DeckContents/inkblot/Remove").pressed.emit()
	check(ui.library.total(ui.library.decks[2]) == 14 and ui.library.journey_issues(ui.library.decks[2]).is_empty(), "One removal repairs the legacy recipe without clipping its starter counts")
	ui.player_index = 1
	ui.show_journey_setup()
	ui.begin_journey()
	check(ui.screen == "journey" and ui.journey != null, "Journey preparation opens the route overview")
	var chart: Control = ui.body.get_node("JourneyMap")
	var enter: Button = chart.get_node("%Enter")
	var scout: Button = chart.get_node("%Scout")
	stick_flick(JOY_AXIS_LEFT_X, -1.0)
	check(root.gui_get_focus_owner() == scout, "Left from the duel action focuses Scout")
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == enter and chart.get_node("%Title").text.contains("The Duelist"), "Right from Scout focuses the duel action without changing rivals")
	stick_flick(JOY_AXIS_LEFT_Y, -1.0)
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(chart.get_node("%Title").text.contains("The Warden") and not enter.disabled and enter.text.contains("Duelist"), "Scouting a future rival keeps the active duel available")
	stick_flick(JOY_AXIS_LEFT_Y, 1.0)
	check(root.gui_get_focus_owner() == enter, "Down from a rival moves to the active duel action")
	check(chart.get_node("%Opening").text.contains("Iron Seal"), "Scouted openings use the rival's actual opening cards")
	chart.get_node("%Scout").pressed.emit()
	var dossier: Window = chart.get_node("ScoutDeck")
	check(dossier.visible and dossier.get_node("%Summary").text.contains("10 cards"), "Scouting opens the rival deck browser")
	dossier.push_input(back, true)
	check(not dossier.visible, "Back returns from the scout deck to the map")
	chart.get_node("%Stops/Gate/Inspect").pressed.emit()
	check(not enter.disabled and chart.get_node("%Title").text.contains("The Duelist"), "The active stop permits entering the duel")
	enter.pressed.emit()
	var journey_table = ui.body.get_node("CombatTable")
	check(not journey_table.get_node("%MarginBurn").visible, "A standalone playtest opt-in does not carry into Journey combat")
	var retained: RefCounted = journey_table.session
	retained.player.gain_block(100)
	journey_table.end_turn()
	ui.show_options()
	ui.get_node("OptionsMenu").get_node("%MainMenu").pressed.emit()
	check(ui.screen == "menu" and ui.journey.active_session == retained, "Options returns to the menu and preserves the active Journey duel")
	ui.main_menu.get_node("%JourneyButton").pressed.emit()
	ui.show_journey_encounter()
	journey_table = ui.body.get_node("CombatTable")
	check(journey_table.session == retained and not journey_table.rival_timer.is_stopped(), "Paused rival turn resumes the same encounter and restarts presentation")
	while retained.outcome.is_empty() and not retained.player_turn:
		journey_table.rival_timer.timeout.emit()
	retained.enemy.apply_poison(99)
	journey_table.end_turn()
	check(ui.screen == "result", "Journey duel shows encounter results")
	await process_frame
	var next_step: Button = ui.result_overlay.get_node("%Rematch")
	var end_journey: Button = ui.result_overlay.get_node("%ChooseDecks")
	var review_table: Button = ui.result_overlay.get_node("%Review")
	check(root.gui_get_focus_owner() == next_step and next_step.has_theme_stylebox_override("normal"), "Journey victory focuses the gold Choose reward action")
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	check(root.gui_get_focus_owner() == end_journey, "Stick right focuses End journey")
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	var end_dialog: ConfirmationDialog = ui.get_node("%EndJourneyDialog")
	check(end_dialog.visible and end_dialog.gui_get_focus_owner() == end_dialog.get_cancel_button(), "End Journey opens confirmation with Cancel focused")
	end_dialog.push_input(back, true)
	await process_frame
	check(not end_dialog.visible and ui.journey != null and root.gui_get_focus_owner() == end_journey, "Controller cancel preserves the Journey and restores result focus")
	stick_flick(JOY_AXIS_LEFT_Y, 1.0)
	check(root.gui_get_focus_owner() == review_table, "Stick down focuses Review the table")
	stick_flick(JOY_AXIS_LEFT_Y, 1.0)
	check(root.gui_get_focus_owner() == next_step, "Stick wraps within the result actions instead of entering the board")
	stick_flick(JOY_AXIS_LEFT_X, -1.0)
	check(root.gui_get_focus_owner() == review_table, "Stick left wraps to Review without entering the board")
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(ui.screen == "journey_reward", "Controller confirm opens the Journey reward")
	var reward: Control = ui.body.get_node("JourneyReward")
	var draft: Button = reward.get_node("%Offers/redline").get_node("%Draft")
	check(root.gui_get_focus_owner() == draft, "Reward entry focuses the first draft choice")
	var roster_size: int = ui.journey.roster.size()
	var original_recipe: Dictionary = ui.library.decks[ui.player_index].duplicate(true)
	reward.get_node("%RevisionToggle").button_pressed = true
	check(reward.get_node("%Revisions").visible and not reward.get_node("%Draft").visible, "Revision choices are available alongside the draft")
	reward.get_node("%RevisionToggle").button_pressed = false
	draft.grab_focus()
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(ui.screen == "journey" and ui.journey.stage == 1 and ui.journey.roster.size() == roster_size + 1, "Drafting adds exactly one card and advances the journey")
	check(ui.library.decks[ui.player_index] == original_recipe, "A draft leaves the saved deck unchanged")
	check(not ui.journey.draft_card(preload("res://data/cards/redline.tres")), "The same reward cannot be claimed twice")
	chart = ui.body.get_node("JourneyMap")
	chart.get_node("%Stops/Gate/Inspect").pressed.emit()
	check(chart.get_node("%Advice").text.contains("HP remaining") and chart.get_node("%Enter").text.contains("Warden"), "A cleared stop displays its result while the duel action points at the current rival")
	ui.show_journey_encounter()
	var next_table: Control = ui.body.get_node("CombatTable")
	check(next_table.session.enemy.max_health == 46, "UI advances to Warden after reward")
	check(next_table.player_piles.total_cards() == roster_size + 1, "The next encounter uses the larger deck")
	check((next_table.player_piles.hand + next_table.player_piles.draw_pile).any(func(card): return card.definition.id == &"redline"), "The drafted Redline is available in the next encounter")
	next_table.session.enemy.apply_poison(99)
	next_table.end_turn()
	await process_frame
	stick_flick(JOY_AXIS_LEFT_X, 1.0)
	root.push_input(confirm, true)
	root.push_input(confirm_release, true)
	check(end_dialog.visible, "End Journey requires confirmation before clearing the run")
	var dialog_right := InputEventJoypadButton.new()
	dialog_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dialog_right.pressed = true
	end_dialog.push_input(dialog_right, true)
	check(end_dialog.gui_get_focus_owner() == end_dialog.get_ok_button(), "Controller can move from Cancel to End journey")
	end_dialog.push_input(confirm, true)
	end_dialog.push_input(confirm_release, true)
	check(ui.screen == "menu" and ui.journey == null, "Confirming End Journey clears the run")
	var sustain: Dictionary = ui.library.counterpoint_sustain_recipe()
	check(ui.library.journey_issues(sustain).is_empty() and sustain.cards.mend == 2, "Sustain preset adds healing within Journey rules")
	var marks_before_puzzle: int = ui.relics.marks
	ui.show_rivals()
	ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Scout opening")[2].pressed.emit()
	var opening_scout: Window = ui.get_node("OpeningScout")
	check(opening_scout.pages[0].route.begins_with("Inkblot"), "Scouting reads the rival's prepared opening")
	opening_scout.close_requested.emit()
	await process_frame
	await process_frame
	var practice_buttons: Array = ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Practice fixed-opening puzzle")
	check(practice_buttons.size() == 3, "Each rival has a practice entry")
	for index in [0, 1]:
		practice_buttons[index].pressed.emit()
		var practice: RefCounted = ui.body.get_node("CombatTable").session
		check(practice.rival_definition == ui.Rivals.ALL[index] and practice.player_piles.hand[0].definition.id == &"block", "Rival practice loads the correct fixed encounter")
		ui.show_rivals()
		practice_buttons = ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Practice fixed-opening puzzle")
	practice_buttons[2].pressed.emit()
	var first_puzzle: RefCounted = ui.body.get_node("CombatTable").session
	ui.body.get_node("TableToolbar").find_children("*", "Button", true, false).filter(func(button): return button.text == "Restart puzzle")[0].pressed.emit()
	check(ui.body.get_node("CombatTable").session != first_puzzle, "Restart puzzle creates a fresh attempt from the table")
	for rewrite in [false, true]:
		var puzzle: Control = ui.body.get_node("CombatTable")
		var duel: RefCounted = puzzle.session
		check(duel.player_piles.hand[0].definition.id == &"block" and duel.enemy_opening_plan()[0].definition.id == &"inkblot", "Puzzle and rematch share the fixed opening")
		play_puzzle_card(duel, &"block")
		if rewrite:
			play_puzzle_card(duel, &"strike")
			check(duel.rewrite_intent(duel.enemy_opening_plan()[0]), "Puzzle can Rewrite Inkblot out of the affordable line")
			play_puzzle_card(duel, &"insight")
		else:
			play_puzzle_card(duel, &"insight")
			play_puzzle_card(duel, &"strike")
			check(duel.completed_pattern == "Riposte", "Puzzle supports a Riposte opening")
		duel.end_turn()
		check(duel.enemy.block == (0 if rewrite else 4), "Puzzle routes resolve different amounts of rival Block")
		for attempt in range(3):
			if duel.outcome.is_empty():
				play_puzzle_card(duel, &"strike")
		check(duel.outcome == "Victory" and ui.screen == "result" and ui.relics.marks == marks_before_puzzle, "Either puzzle solution wins without Journey or Marks progression")
		check(ui.result_overlay.get_node("%Spoils").text.begins_with("Practice time · "), "Puzzle results show elapsed practice time")
		check(ui.result_overlay.get_node("%Spoils").text.contains("Session best"), "Puzzle victory records a session best")
		check(ui.result_overlay.get_node("%Spoils").text.contains("Fewest turns · 2") and ui.result_overlay.get_node("%Spoils").text.contains("Wins · %d" % (2 if rewrite else 1)), "Practice records best turns and win count per rival")
		check(ui.result_overlay.get_node("%Spoils").text.contains("Attempt %d" % (3 if rewrite else 2)), "Puzzle attempts count restarts and rematches for this rival")
		if not rewrite:
			ui.result_overlay.get_node("%Rematch").pressed.emit()
		else:
			ui.result_overlay.get_node("%ChooseDecks").pressed.emit()
			check(ui.screen == "rivals", "Puzzle results return to rival selection")
	ui.body.find_child("StrictPracticeQueue", true, false).button_pressed = true
	ui.body.find_child("CarryPracticeReserves", true, false).button_pressed = true
	ui.body.find_child("PracticeCadenceEnergy", true, false).button_pressed = true
	ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Scout opening")[1].pressed.emit()
	opening_scout = ui.get_node("OpeningScout")
	check(opening_scout.pages.size() == 2 and opening_scout.pages[1].body.contains("Strict queue stops at Strike"), "Scouting separates standard advice from the selected practice forecast")
	opening_scout.close_requested.emit()
	await process_frame
	var experimental_buttons: Array = ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Practice fixed-opening puzzle")
	experimental_buttons[1].pressed.emit()
	var experimental_table: Control = ui.body.get_node("CombatTable")
	var experimental_duel: RefCounted = experimental_table.session
	check(experimental_duel.strict_rival_queue and experimental_duel.carry_rival_reserves, "Rival selection enables both practice variants")
	check(not experimental_table.get_node("Middle/Field/Actions/LabToggle").visible, "Scored practice hides the sandbox pile tools")
	var energy_trade_button: Button = experimental_table.get_node("%CadenceEnergy")
	check(energy_trade_button.visible and energy_trade_button.disabled, "Experimental energy button shows its Cadence requirement")
	experimental_duel.cadence = 3
	experimental_table.refresh()
	energy_trade_button.pressed.emit()
	check(experimental_duel.energy == 4 and energy_trade_button.disabled, "Practice energy purchase uses the once-per-turn combat rule")
	check(experimental_table.get_node("%IntentExperiment").text.contains("stops at Strike") and experimental_table.get_node("%IntentExperiment").text.contains("Next front"), "Board explains the visible blocker and carried prefix")
	experimental_duel.enemy.apply_poison(99)
	experimental_table.end_turn()
	check(ui.result_overlay.get_node("%Spoils").text.contains("Attempt 1"), "Alternate rules start a separate practice record")
	ui.result_overlay.get_node("%Rematch").pressed.emit()
	experimental_duel = ui.body.get_node("CombatTable").session
	check(experimental_duel.strict_rival_queue and experimental_duel.carry_rival_reserves and experimental_duel.cadence_energy_enabled, "Rematch preserves the selected rules")
	ui.show_library(false)
	for recipe in ui.library.style_recipes():
		check(ui.library.journey_issues(recipe).is_empty() and not ui.library.category_counts(recipe).has(0), "New style preset is Journey legal and supports Patterns")
		check(ui.library.instantiate_deck(recipe).size() == ui.library.total(recipe), "Each preset builds all of its catalogued cards")
	check(ui.library.profile_text(ui.library.counterpoint_sustain_recipe()).contains("Healing cards 2"), "Deck profile counts healing copies")
	var deck_search: LineEdit = ui.body.find_child("DeckSearch", true, false)
	deck_search.text = "no-deck-with-this-name"
	deck_search.text_changed.emit(deck_search.text)
	var deck_rows: Array = ui.body.find_children("*", "PanelContainer", true, false).filter(func(panel): return panel.has_meta("recipe"))
	check(not deck_rows.is_empty() and deck_rows.all(func(panel): return not panel.visible), "Deck library search hides unmatched recipes")
	deck_search.clear()
	deck_search.text_changed.emit("")
	var ready_filter: CheckButton = ui.body.find_child("JourneyReadyFilter", true, false)
	ready_filter.button_pressed = true
	check(deck_rows.all(func(panel): return panel.visible == ui.library.journey_issues(panel.get_meta("recipe")).is_empty()), "Journey filter uses the shared validation")
	var alphabetical: CheckButton = ui.body.find_child("AlphabeticalDecks", true, false)
	alphabetical.button_pressed = true
	var sorted: Array = deck_rows[0].get_parent().get_children().filter(func(panel): return panel.has_meta("recipe"))
	for index in range(1, sorted.size()):
		check(String(sorted[index - 1].get_meta("recipe").name).naturalnocasecmp_to(sorted[index].get_meta("recipe").name) <= 0, "Deck library sorts names without changing recipes")
	var original: Dictionary = ui.library.decks[0].duplicate(true)
	ui.duplicate_deck(0, false)
	var copy_index: int = ui.library.decks.size() - 1
	var copy_editor: Control = ui.body.get_node("DeckEditor")
	var rename: LineEdit = copy_editor.find_child("DeckName", true, false)
	rename.text_submitted.emit("Practice copy")
	ui.change_count(copy_index, "strike", 1, false)
	ui.library.load_decks()
	check(ui.library.decks[0] == original and ui.library.decks[copy_index].name == "Practice copy", "Duplicate and rename save independently of the original recipe")
	ui.start_custom_duel()
	ui.player_index = 0
	ui.enemy_index = 1
	ui.show_setup()
	ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Swap decks")[0].pressed.emit()
	check(ui.player_index == 1 and ui.enemy_index == 0, "Custom duel swaps the selected recipes")
	ui.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Edit this deck")[0].pressed.emit()
	check(ui.screen == "editor", "Deck setup opens the selected recipe directly")
	ui.body.get_node("DeckEditor").get_node("%Done").pressed.emit()
	check(ui.screen == "setup", "Done returns to the duel setup")
	ui.show_menu()
	ui.queue_free()
	await process_frame
	print("UI flow checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
