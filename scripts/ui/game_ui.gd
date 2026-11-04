extends Control
## Navigation and deck editing. Combat rules do not belong in this controller.

const Style = preload("res://scripts/ui/ui_style.gd")
const Library = preload("res://scripts/content/deck_library.gd")
const Table = preload("res://scripts/ui/table_screen.gd")
const CombatResult = preload("res://scripts/ui/combat_result.gd")
var library = Library.new()
var body: VBoxContainer
var player_index: int = -1
var enemy_index: int = -1
var editing: int = -1
var screen: String = ""
var use_war_drum: bool = true
var fast_rival_turns: bool = false
var result_overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme()
	var background := ColorRect.new()
	background.color = Color("0b1c20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page_scroll := ScrollContainer.new()
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(page_scroll)
	body = Style.column(page_scroll, true)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	library.load_decks()
	show_menu()


func clear(title: String, subtitle: String) -> void:
	close_result()
	# Each screen starts at the top, even after scrolling the deck editor.
	body.get_parent().set_deferred("scroll_vertical", 0)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	Style.label(body, "THE CARD TABLE", 14, Style.GOLD)
	Style.label(body, title, 28)
	Style.label(body, subtitle, 16, Style.MUTED)
	if not library.error_message.is_empty():
		Style.label(body, library.error_message, 16, Color("eea89b"))


func show_menu() -> void:
	screen = "menu"
	clear("Every run begins with a deck.", "Build your collection. Choose a rival. Take a seat.")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var menu := Style.panel(center)
	menu.custom_minimum_size.x = 440
	Style.label(menu, "CARD / ROGUELIKE", 32, Style.GOLD)
	Style.label(menu, "Change your rhythm. Rewrite their next move.", 16, Style.MUTED)
	Style.button(menu, "Start game  →", show_setup)
	Style.button(menu, "Manage decks", func(): show_library(false))
	Style.button(menu, "Quit", func(): get_tree().quit())
	Style.label(body, "LOCAL DECKS  •  Saved on this device", 14, Style.MUTED)


func show_library(selecting: bool) -> void:
	screen = "library"
	clear("Your decks", "Create a recipe, then add cards. Changes are saved automatically.")
	var toolbar := Style.row(body)
	var name_input := LineEdit.new()
	name_input.placeholder_text = "New deck name"
	name_input.max_length = 32
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(name_input)
	Style.button(toolbar, "Create deck", func():
		var deck_name := name_input.text.strip_edges()
		if deck_name.is_empty():
			name_input.grab_focus()
			return
		library.decks.append({"name": deck_name, "cards": {"strike": 0, "block": 0}})
		library.save()
		show_editor(library.decks.size() - 1, selecting))
	Style.button(toolbar, "Add Counterpoint", func():
		library.decks.append(library.counterpoint_recipe())
		library.save()
		show_editor(library.decks.size() - 1, selecting))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := Style.column(scroll, true)
	if library.decks.is_empty():
		Style.label(list, "No decks yet. Create your first deck above.", 20, Style.MUTED)
	for index in range(library.decks.size()):
		var recipe: Dictionary = library.decks[index]
		var item := Style.panel(list)
		var line := Style.row(item)
		var name_label := Style.label(line, "%s   /   %d cards" % [recipe.name, library.total(recipe)], 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.button(line, "Edit cards", show_editor.bind(index, selecting))
		Style.button(line, "Remove", confirm_remove.bind(index, selecting))
	Style.button(body, "← Back", show_setup if selecting else show_menu)


func confirm_remove(index: int, selecting: bool) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Remove deck '%s'?" % library.decks[index].name
	dialog.title = "Remove deck"
	add_child(dialog)
	dialog.confirmed.connect(func():
		library.decks.remove_at(index)
		player_index = -1
		enemy_index = -1
		library.save()
		show_library(selecting)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func show_editor(index: int, selecting: bool) -> void:
	screen = "editor"
	editing = index
	var recipe: Dictionary = library.decks[index]
	clear(recipe.name, "%d cards  /  Add at least one card to use this deck. Maximum 50 copies per card." % library.total(recipe))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	for definition in Library.CARDS:
		var panel := Style.panel(cards)
		panel.get_parent().custom_minimum_size.x = 300
		Style.label(panel, definition.display_name, 24, Style.GOLD)
		Style.label(panel, "%d energy" % definition.energy_cost, 16, Style.MUTED)
		var description := Style.label(panel, definition.description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var id := String(definition.id)
		var count := int(recipe.cards.get(id, 0))
		Style.label(panel, "Copies in deck: %d" % count, 22)
		var controls := Style.row(panel)
		Style.button(controls, "− Remove", change_count.bind(index, id, -1, selecting)).disabled = count == 0
		Style.button(controls, "+ Add", change_count.bind(index, id, 1, selecting)).disabled = count >= 50
	Style.label(body, "Change between Attack, Guard, and Tactic to build Cadence. Spend 2 to rewrite rival intent.", 14, Style.MUTED)
	Style.button(body, "Done  →", show_library.bind(selecting))


func change_count(index: int, id: String, amount: int, selecting: bool) -> void:
	library.decks[index].cards[id] = clampi(int(library.decks[index].cards.get(id, 0)) + amount, 0, 50)
	library.save()
	show_editor(index, selecting)


func show_setup() -> void:
	ensure_deck_selections()
	screen = "setup"
	clear("Choose both sides", "Select your deck and an enemy deck. Both may use the same recipe.")
	var sides := Style.row(body)
	for side in ["player", "enemy"]:
		var panel := Style.panel(sides)
		Style.label(panel, "YOUR DECK" if side == "player" else "ENEMY DECK", 20, Style.GOLD)
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(340, 48)
		picker.add_item("Select a deck…", -1)
		for index in range(library.decks.size()):
			var recipe: Dictionary = library.decks[index]
			picker.add_item("%s (%d cards)" % [recipe.name, library.total(recipe)], index)
			picker.set_item_disabled(index + 1, library.total(recipe) == 0)
		var selected := player_index if side == "player" else enemy_index
		picker.select(selected + 1)
		panel.add_child(picker)
		picker.item_selected.connect(func(item: int):
			if side == "player":
				player_index = item - 1
			else:
				enemy_index = item - 1
			show_setup())
		if selected >= 0 and selected < library.decks.size():
			for definition in Library.CARDS:
				var count := int(library.decks[selected].cards.get(String(definition.id), 0))
				if count > 0:
					Style.label(panel, "%s × %d" % [definition.display_name, count])
	var artifact := CheckButton.new()
	artifact.text = "War Drum: each Strike adds +1 attack damage for this encounter (before damage)."
	artifact.button_pressed = use_war_drum
	artifact.toggled.connect(func(enabled: bool): use_war_drum = enabled)
	body.add_child(artifact)
	Style.button(body, "Create / edit decks", show_library.bind(true))
	var confirm := Style.button(body, "Confirm  /  Take a seat  →", show_table)
	confirm.disabled = not valid_selection()
	Style.button(body, "← Main menu", show_menu)


func valid_selection() -> bool:
	return player_index >= 0 and enemy_index >= 0 and player_index < library.decks.size() and enemy_index < library.decks.size() and library.total(library.decks[player_index]) > 0 and library.total(library.decks[enemy_index]) > 0


func ensure_deck_selections() -> void:
	var first := -1
	for index in range(library.decks.size()):
		if library.total(library.decks[index]) > 0:
			first = index
			break
	if player_index < 0 or player_index >= library.decks.size() or library.total(library.decks[player_index]) == 0:
		player_index = first
	if enemy_index < 0 or enemy_index >= library.decks.size() or library.total(library.decks[enemy_index]) == 0:
		enemy_index = first


func show_table() -> void:
	if not valid_selection():
		return
	screen = "table"
	clear("The table", "%s  vs  %s" % [library.decks[player_index].name, library.decks[enemy_index].name])
	for index in range(3):
		body.get_child(index).hide()
	var toolbar := Style.row(body)
	var title := Style.label(toolbar, "THE CARD TABLE  ·  %s vs %s" % [library.decks[player_index].name, library.decks[enemy_index].name], 14, Style.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var speed := CheckButton.new()
	speed.text = "Fast turns"
	speed.button_pressed = fast_rival_turns
	speed.tooltip_text = "Rival card interval: 0.2 seconds when enabled, 0.65 seconds otherwise."
	toolbar.add_child(speed)
	speed.toggled.connect(set_fast_turns)
	Style.button(toolbar, "← Leave table", show_setup)
	var table := Table.new()
	table.name = "CombatTable"
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(table)
	table.setup(library.instantiate_deck(library.decks[player_index]), library.instantiate_deck(library.decks[enemy_index]), use_war_drum)
	table.rival_timer.wait_time = 0.2 if fast_rival_turns else 0.65
	table.combat_finished.connect(show_result)


func set_fast_turns(enabled: bool) -> void:
	fast_rival_turns = enabled
	var table := body.get_node_or_null("CombatTable")
	if table != null:
		table.rival_timer.wait_time = 0.2 if enabled else 0.65
		if not table.rival_timer.is_stopped():
			table.rival_timer.start()


func close_result() -> void:
	if is_instance_valid(result_overlay):
		remove_child(result_overlay)
		result_overlay.queue_free()
		result_overlay = null


func review_result() -> void:
	close_result()
	screen = "table"


func show_result(summary: Dictionary) -> void:
	close_result()
	screen = "result"
	result_overlay = CombatResult.new()
	result_overlay.name = "CombatResult"
	add_child(result_overlay)
	result_overlay.setup(summary, show_table, show_setup, review_result)
