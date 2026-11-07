extends Control
## Navigation and deck editing. Combat rules do not belong in this controller.

const Style = preload("res://scripts/ui/ui_style.gd")
const Library = preload("res://scripts/content/deck_library.gd")
const RelicCollection = preload("res://scripts/content/relic_collection.gd")
const RelicPage = preload("res://scenes/ui/relic_collection.tscn")
const RelicTile = preload("res://scenes/ui/relic_tile.tscn")
const PageHeading = preload("res://scenes/ui/page_heading.tscn")
const RELIC_EMBLEMS = preload("res://data/ui/relic_emblems.svg")
const Table = preload("res://scenes/ui/combat_table.tscn")
const TableToolbar = preload("res://scenes/ui/table_toolbar.tscn")
const OptionsMenu = preload("res://scenes/ui/options_menu.tscn")
const Bindings = preload("res://scripts/ui/control_bindings.gd")
const WINDOW_MODES = [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN]
const WINDOW_SIZES = [Vector2i(1100, 700), Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080)]
const CombatResult = preload("res://scenes/ui/combat_result.tscn")
const DeckEditor = preload("res://scenes/ui/deck_editor.tscn")
const DeckCard = preload("res://scenes/ui/deck_card.tscn")
const CardBrowser = preload("res://scenes/ui/card_browser.tscn")
const Rivals = preload("res://scripts/content/rival_catalog.gd")
const DuelArt = preload("res://scripts/ui/duel_art.gd")
const Journey = preload("res://scripts/combat/journey_state.gd")
const JourneyCheckpoint = preload("res://scripts/content/journey_checkpoint.gd")
const JourneyReward = preload("res://scenes/ui/journey_reward.tscn")
const JourneyMap = preload("res://scenes/ui/journey_map.tscn")
const DraftCard = preload("res://scenes/ui/draft_card.tscn")
const CombatSession = preload("res://scripts/combat/combat_session.gd")
const INSIGHT = preload("res://data/cards/insight.tres")
var journey: RefCounted
var journey_checkpoint := JourneyCheckpoint.new()
var preparing_journey: bool = false
var journey_deck_name: String = ""
var _table_is_journey: bool = false
var selected_rival: Resource
var library = Library.new()
@onready var body: VBoxContainer = %Body
@onready var main_menu: VBoxContainer = %MainMenu
@onready var page_scroll: ScrollContainer = %PageScroll
var player_index: int = -1
var enemy_index: int = -1
var editing: int = -1
var screen: String = ""
var relics := RelicCollection.new()
var _paid_session: RefCounted
var _spoils_text := ""
var fast_rival_turns: bool = false
var combat_sound: bool = true
var combat_motion: bool = true
var master_volume: float = 100.0
var effects_volume: float = 100.0
var window_mode: int = 1
var window_size: int = 0
var vsync: bool = true
var controller_shortcuts: bool = true
var swap_shoulders: bool = false
var end_shortcut: bool = false
var options_path: String = "user://options.cfg"
var result_overlay: Control
var _back_action: Callable
var control_bindings := Bindings.defaults()


func _ready() -> void:
	load_options()
	%FocusHelp.toggle_requested.connect(func(): change_option("focus_tooltips", not %FocusHelp.hints_enabled))
	relics.load_profile()
	var restored := journey_checkpoint.load_run()
	if not restored.is_empty():
		journey = restored.journey
		journey_deck_name = restored.deck
		collect_journey_marks()
	if OS.has_feature("web"):
		main_menu.find_child("QuitButton", true, false).hide()
	main_menu.journey_requested.connect(_on_menu_journey)
	main_menu.lesson_requested.connect(show_lesson)
	main_menu.relics_requested.connect(show_relics)
	main_menu.single_duel_requested.connect(show_rivals)
	main_menu.custom_duel_requested.connect(start_custom_duel)
	main_menu.decks_requested.connect(func(): show_library(false))
	main_menu.options_requested.connect(show_options)
	main_menu.quit_requested.connect(func(): get_tree().quit())
	%EndJourneyDialog.confirmed.connect(end_journey)
	library.load_decks()
	show_menu()


func _on_menu_journey() -> void:
	if journey != null:
		show_journey_overview()
	else:
		show_journey_setup()


func clear(title: String, subtitle: String) -> void:
	close_result()
	_back_action = Callable()
	var edge := 12 if screen == "table" else 24
	$ScreenMargin.add_theme_constant_override("margin_top", edge)
	$ScreenMargin.add_theme_constant_override("margin_bottom", edge)
	# Each screen starts at the top, even after scrolling the deck editor.
	page_scroll.set_deferred("scroll_vertical", 0)
	main_menu.hide()
	body.show()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var heading := PageHeading.instantiate()
	body.add_child(heading)
	heading.get_node("%Title").text = title
	heading.get_node("%Subtitle").text = subtitle
	if not library.error_message.is_empty():
		Style.label(body, library.error_message, 16, Color("eea89b"))
	if screen.begins_with("journey"):
		var notice := journey_save_notice()
		if not notice.is_empty():
			Style.label(body, notice, 15, Color("eea89b")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func show_menu() -> void:
	screen = "menu"
	clear("", "")
	body.hide()
	main_menu.set_has_journey(journey != null)
	main_menu.set_relic_marks(relics.marks)
	main_menu.set_save_notice(journey_save_notice())
	main_menu.show()


func start_custom_duel() -> void:
	preparing_journey = false
	selected_rival = null
	show_setup()


func show_rivals() -> void:
	preparing_journey = false
	screen = "rivals"
	clear("Every rival writes differently.", "Choose a doctrine to challenge. Their prepared line is yours to reshape.")
	var choices := Style.row(body)
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index in range(Rivals.ALL.size()):
		var rival: Resource = Rivals.ALL[index]
		var panel := Style.panel(choices)
		panel.get_parent().custom_minimum_size.x = 300
		Style.label(panel, "0%d  /  %s" % [index + 1, ["PRESSURE", "BASTION", "INTRIGUE"][index]], 12, rival.accent)
		var art := DuelArt.new()
		art.motif = rival.display_name
		art.accent = rival.accent
		art.custom_minimum_size.y = 112
		panel.add_child(art)
		Style.heading(panel, rival.display_name, 28)
		var epithet := Style.label(panel, rival.epithet, 13, rival.accent)
		epithet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := Style.label(panel, rival.description, 14, Style.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		Style.label(panel, "%d HP  ·  %d cards" % [rival.health, rival.cards.size()], 14, Style.GOLD)
		Style.label(panel, rival.doctrine_text(), 13, rival.accent)
		Style.primary(Style.button(panel, "Challenge  →", select_rival.bind(index)))
	Style.button(body, "← Main menu", show_menu)
	_back_action = show_menu


func select_rival(index: int) -> void:
	if index < 0 or index >= Rivals.ALL.size():
		return
	selected_rival = Rivals.ALL[index]
	preparing_journey = false
	show_setup()


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
	var presets := OptionButton.new()
	presets.add_item("Add a preset…")
	presets.set_item_disabled(0, true)
	presets.add_item("Counterpoint")
	presets.add_item("Palimpsest")
	presets.add_item("Counterwritten")
	presets.item_selected.connect(func(item: int):
		library.decks.append([library.counterpoint_recipe(), library.palimpsest_recipe(), library.counterwritten_recipe()][item - 1])
		library.save()
		show_editor(library.decks.size() - 1, selecting))
	toolbar.add_child(presets)
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
		Style.button(line, "View cards", show_deck_cards.bind(index))
		Style.button(line, "Edit cards", show_editor.bind(index, selecting))
		Style.button(line, "Remove", confirm_remove.bind(index, selecting))
	_back_action = show_setup if selecting else show_menu
	Style.button(body, "← Back", _back_action)


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
	clear(recipe.name, "Build your deck from the almanac. Mix Attack, Guard, and Tactic to unlock Patterns.")
	var editor := DeckEditor.instantiate()
	body.add_child(editor)
	_back_action = show_library.bind(selecting)
	editor.get_node("%Done").pressed.connect(_back_action)
	var cards := editor.get_node("%Cards")
	for definition in Library.CARDS:
		var id := String(definition.id)
		var entry := DeckCard.instantiate()
		entry.name = id
		cards.add_child(entry)
		entry.get_node("%Card").setup_preview(CardInstance.new(definition))
		var remove: Button = entry.get_node("%Remove")
		var add: Button = entry.get_node("%Add")
		remove.tooltip_text = "Remove one copy of %s" % definition.display_name
		add.tooltip_text = "Add one copy of %s (maximum 50)" % definition.display_name
		remove.pressed.connect(change_count.bind(index, id, -1, selecting))
		add.pressed.connect(change_count.bind(index, id, 1, selecting))
		update_deck_card(entry, int(recipe.cards.get(id, 0)))
	editor.get_node("%Total").text = "%d cards in deck" % library.total(recipe)


func update_deck_card(entry: Node, count: int) -> void:
	entry.get_node("%Card").set_caption("%d in deck" % count)
	entry.get_node("%Remove").disabled = count == 0
	entry.get_node("%Add").disabled = count >= 50


func change_count(index: int, id: String, amount: int, selecting: bool) -> void:
	var recipe: Dictionary = library.decks[index]
	var count := clampi(int(recipe.cards.get(id, 0)) + amount, 0, 50)
	recipe.cards[id] = count
	var saved: bool = library.save()
	var editor := body.get_node_or_null("DeckEditor")
	if screen != "editor" or editing != index or editor == null:
		show_editor(index, selecting)
		return
	var entry := editor.get_node("%Cards").get_node_or_null(id)
	if entry != null:
		update_deck_card(entry, count)
	editor.get_node("%Total").text = "%d cards in deck" % library.total(recipe) if saved else library.error_message


func show_setup() -> void:
	ensure_deck_selections()
	screen = "setup"
	clear("Choose your approach." if selected_rival != null else "Choose both sides", "Your deck is your argument. The rival's doctrine is a promise." if selected_rival != null else "Choose both decks for a custom duel.")
	if preparing_journey:
		Style.label(body, "THREE DUELS  ·  HP carries forward  ·  Recover, draft, or revise between wins", 13, Style.GOLD)
	var sides := Style.row(body)
	for side in ["player", "enemy"]:
		var panel := Style.panel(sides)
		Style.label(panel, "YOUR DECK" if side == "player" else ("YOUR RIVAL" if selected_rival != null else "ENEMY DECK"), 20, Style.GOLD)
		if side == "enemy" and selected_rival != null:
			Style.heading(panel, selected_rival.display_name, 28)
			var description := Style.label(panel, selected_rival.description, 16, Style.MUTED)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			Style.label(panel, "%d HP  ·  %s" % [selected_rival.health, selected_rival.doctrine_text()], 14, selected_rival.accent)
			if not selected_rival.opening_advice.is_empty():
				Style.label(panel, selected_rival.opening_advice, 14, Style.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			Style.button(panel, "Choose a different rival", show_rivals)
			continue
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
			Style.button(panel, "View deck cards", show_deck_cards.bind(selected))
			var counts: Array[int] = library.category_counts(library.decks[selected])
			Style.label(panel, "Attack %d  ·  Guard %d  ·  Tactic %d" % counts, 13, Style.MUTED)
			if side == "player" and counts.has(0):
				Style.label(panel, "Patterns use all three categories.", 13, Style.GOLD)
				Style.button(panel, "Try the Counterpoint deck", use_counterpoint_deck)
	var equipment := Style.row(body)
	var equipped := relics.equipped()
	Style.label(equipment, "RELIC   /   " + (equipped.title if equipped != null else "None"), 15, Style.GOLD)
	Style.button(equipment, "Change relic", show_relics.bind(true))
	var actions := HFlowContainer.new()
	body.add_child(actions)
	var confirm := Style.button(actions, "Begin the journey  →" if preparing_journey else "Begin the duel  →", begin_journey if preparing_journey else show_table)
	Style.primary(confirm)
	confirm.disabled = not valid_selection()
	Style.button(actions, "Create / edit decks", show_library.bind(true))
	Style.button(actions, "← Main menu", show_menu)
	_back_action = show_menu


func show_relics(from_setup: bool = false) -> void:
	screen = "relics"
	clear("Relic collection", "Equip one relic for your next duel or journey.")
	var page := RelicPage.instantiate()
	body.add_child(page)
	page.get_node("%Balance").text = "%d MARKS" % relics.marks
	page.get_node("%Collected").text = "%d / %d collected" % [relics.owned.size(), RelicCollection.CATALOG.size()]
	page.get_node("%Earnings").text = "Named rival victories earn %d Marks. Completing a Journey earns %d more." % [RelicCollection.DUEL_MARKS, RelicCollection.JOURNEY_BONUS]
	_back_action = show_setup if from_setup else show_menu
	page.get_node("%Back").pressed.connect(_back_action)
	for relic in RelicCollection.CATALOG:
		var tile := RelicTile.instantiate()
		tile.name = relic.id
		page.get_node("%Relics").add_child(tile)
		var emblem := AtlasTexture.new()
		emblem.atlas = RELIC_EMBLEMS
		emblem.region = Rect2(relic.perk * 64, 0, 64, 64)
		tile.get_node("%Emblem").texture = emblem
		tile.get_node("%Title").text = relic.title
		tile.get_node("%Description").text = relic.description
		var tier := "STARTER" if relic.price == 0 else ("JOURNEY RELIC" if relic.requires_journey else ("RIVAL RELIC" if not relic.required_rival.is_empty() else "COLLECTION RELIC"))
		tile.get_node("%Tier").text = tier
		var action: Button = tile.get_node("%Action")
		if relics.owned.has(relic.id):
			var equipped: bool = relics.equipped_id == relic.id
			tile.get_node("%Status").text = "EQUIPPED" if equipped else "OWNED"
			if equipped:
				var frame := tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
				frame.border_color = Style.GOLD
				tile.add_theme_stylebox_override("panel", frame)
				tile.get_node("%Status").add_theme_color_override("font_color", Style.GOLD)
			action.text = "Unequip" if equipped else "Equip"
			action.pressed.connect(change_equipped_relic.bind("" if equipped else relic.id, from_setup))
		else:
			var requirement := relic_requirement(relic)
			tile.get_node("%Status").text = requirement if not relics.meets_milestone(relic) else ("Ready to unlock" if relics.marks >= relic.price else "%d more Marks needed" % (relic.price - relics.marks))
			action.text = "Unlock · %d Marks" % relic.price
			action.disabled = not relics.meets_milestone(relic) or relics.marks < relic.price
			action.pressed.connect(unlock_relic.bind(relic, from_setup))
	if not relics.error_message.is_empty():
		Style.label(body, relics.error_message, 15, Color("eea89b"))


func relic_requirement(relic: Resource) -> String:
	if relic.requires_journey:
		return "Complete a Journey"
	for rival in Rivals.ALL:
		if rival.id == relic.required_rival:
			var title: String = rival.display_name
			return "Defeat " + ("the " + title.trim_prefix("The ") if title.begins_with("The ") else title)
	return ""


func change_equipped_relic(id: String, from_setup: bool) -> void:
	relics.equip(id)
	show_relics(from_setup)


func unlock_relic(relic: Resource, from_setup: bool) -> void:
	relics.buy(relic)
	show_relics(from_setup)


func show_deck_cards(index: int) -> void:
	var recipe: Dictionary = library.decks[index]
	var dialog := CardBrowser.instantiate()
	add_child(dialog)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.show_cards(recipe.name, library.instantiate_deck(recipe), "Saved deck")


func use_counterpoint_deck() -> void:
	for index in range(library.decks.size()):
		if library.decks[index].name == "Counterpoint" and not library.category_counts(library.decks[index]).has(0):
			player_index = index
			show_setup()
			return
	library.decks.append(library.counterpoint_recipe())
	player_index = library.decks.size() - 1
	library.save()
	show_setup()


func valid_selection() -> bool:
	var player_valid: bool = player_index >= 0 and player_index < library.decks.size() and library.total(library.decks[player_index]) > 0
	var enemy_valid: bool = selected_rival != null or (enemy_index >= 0 and enemy_index < library.decks.size() and library.total(library.decks[enemy_index]) > 0)
	return player_valid and enemy_valid


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
	var enemy_name: String = selected_rival.display_name if selected_rival != null else library.decks[enemy_index].name
	var enemy_cards: Array[CardInstance] = selected_rival.create_deck() if selected_rival != null else library.instantiate_deck(library.decks[enemy_index])
	var player_cards: Array[CardInstance] = library.instantiate_deck(library.decks[player_index])
	var duel := CombatSession.new(player_cards, enemy_cards, true, false, selected_rival, 30, relics.equipped())
	mount_table(player_cards, enemy_cards, library.decks[player_index].name, enemy_name, selected_rival, duel)


func show_lesson() -> void:
	var player_cards: Array[CardInstance] = [CardInstance.new(INSIGHT), CardInstance.new(StarterDeck.BLOCK), CardInstance.new(StarterDeck.STRIKE)]
	var rival_cards: Array[CardInstance] = []
	for index in range(4):
		rival_cards.append(CardInstance.new(StarterDeck.BLOCK))
	rival_cards.append(CardInstance.new(StarterDeck.STRIKE))
	var practice := CombatSession.new(player_cards, rival_cards, false)
	mount_table(player_cards, rival_cards, "First lesson", "Practice rival", null, practice, false, true)


func mount_table(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], player_name: String, enemy_name: String, rival: Resource, existing: RefCounted = null, in_journey: bool = false, guided: bool = false) -> void:
	screen = "table"
	_table_is_journey = in_journey
	clear("The table", "%s vs %s" % [player_name, enemy_name])
	body.get_node("PageHeading").hide()
	var toolbar := TableToolbar.instantiate()
	body.add_child(toolbar)
	toolbar.get_node("%Title").text = ("CHAPTER %d/3  ·  " % (journey.stage + 1) if in_journey else "") + "%s / %s" % [player_name.to_upper(), enemy_name.to_upper()]
	var speed: CheckButton = toolbar.get_node("%FastTurns")
	var sound: CheckButton = toolbar.get_node("%Sound")
	var motion: CheckButton = toolbar.get_node("%Motion")
	speed.set_pressed_no_signal(fast_rival_turns)
	sound.set_pressed_no_signal(combat_sound)
	motion.set_pressed_no_signal(combat_motion)
	for toggle in [speed, sound, motion]:
		Style.quiet(toggle)
	var help: CheckButton = toolbar.get_node("%FocusTooltips")
	Style.quiet(help)
	update_tooltip_toggle(toolbar)
	help.toggled.connect(func(enabled: bool): change_option("focus_tooltips", enabled))
	var leave: Button = toolbar.get_node("%Leave")
	Style.quiet(toolbar.get_node("%Options"))
	leave.text = "Journey" if in_journey else ("← Main menu" if guided else "← Leave table")
	_back_action = show_journey_overview if in_journey else (show_menu if guided else show_setup)
	leave.pressed.connect(_back_action)
	Style.quiet(leave)
	leave.tooltip_text = "JOURNEY\nPause this duel and view your route. Returning here resumes the fight. Closing the game restarts this chapter." if in_journey else "LEAVE TABLE\nReturn to deck preparation. This single duel is discarded; saved decks are unchanged."
	var table := Table.instantiate()
	table.name = "CombatTable"
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(table)
	table.motion_enabled = combat_motion
	table.guided = guided
	table.configure_controller(controller_shortcuts, swap_shoulders, end_shortcut)
	table.combat_audio.set_enabled(combat_sound)
	table.setup(player_cards, enemy_cards, false, rival, existing)
	if guided:
		table.lesson.completed.connect(show_journey_setup)
		table.lesson.get_node("%Continue").grab_focus()
	table.rival_timer.wait_time = 0.70 if fast_rival_turns else 1.15
	table.combat_finished.connect(show_result)
	speed.toggled.connect(func(enabled: bool): change_option("fast_turns", enabled))
	sound.toggled.connect(func(enabled: bool): change_option("sound", enabled))
	motion.toggled.connect(func(enabled: bool): change_option("motion", enabled))
	toolbar.get_node("%Options").pressed.connect(show_options)
	if existing != null and not existing.player_turn and existing.outcome.is_empty():
		table.rival_timer.start()


func set_fast_turns(enabled: bool) -> void:
	fast_rival_turns = enabled
	var table := body.get_node_or_null("CombatTable")
	if table != null:
		table.rival_timer.wait_time = 0.70 if enabled else 1.15
		if not table.rival_timer.is_stopped():
			table.rival_timer.start()


func load_options() -> void:
	var config := ConfigFile.new()
	if config.load(options_path) == OK:
		control_bindings = Bindings.sanitize(config.get_value("table", "bindings", {}))
		combat_sound = bool(config.get_value("table", "sound", true))
		combat_motion = bool(config.get_value("table", "motion", true))
		fast_rival_turns = bool(config.get_value("table", "fast_turns", false))
		master_volume = clampf(float(config.get_value("table", "volume", 100.0)), 0.0, 100.0)
		effects_volume = clampf(float(config.get_value("table", "effects_volume", 100.0)), 0.0, 100.0)
		window_mode = clampi(int(config.get_value("table", "window_mode", 1)), 0, WINDOW_MODES.size() - 1)
		window_size = clampi(int(config.get_value("table", "window_size", 0)), 0, WINDOW_SIZES.size() - 1)
		vsync = bool(config.get_value("table", "vsync", true))
		controller_shortcuts = bool(config.get_value("table", "controller", true))
		swap_shoulders = bool(config.get_value("table", "swap_shoulders", false))
		end_shortcut = bool(config.get_value("table", "end_shortcut", false))
		%FocusHelp.hints_enabled = bool(config.get_value("table", "focus_tooltips", true))
		if config.has_section_key("table", "window_mode"):
			apply_window.call_deferred()
		if config.has_section_key("table", "vsync"):
			apply_vsync()
	Bindings.apply(control_bindings)
	apply_volume()


func apply_volume() -> void:
	AudioServer.set_bus_volume_linear(0, master_volume / 100.0)
	var bus := AudioServer.get_bus_index("Effects")
	if bus >= 0:
		AudioServer.set_bus_volume_linear(bus, effects_volume / 100.0)


func apply_window() -> void:
	if not supports_desktop_display() or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	window.mode = WINDOW_MODES[window_mode]
	if window.mode == Window.MODE_WINDOWED:
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.size = WINDOW_SIZES[window_size].min(usable.size - Vector2i(32, 64))
		window.position = usable.position + (usable.size - window.size) / 2


func apply_vsync() -> void:
	if supports_desktop_display() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, get_window().get_window_id())


func supports_desktop_display() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func option_values() -> Dictionary:
	return {
		"sound": combat_sound, "motion": combat_motion, "fast_turns": fast_rival_turns,
		"volume": master_volume, "effects_volume": effects_volume,
		"window_mode": window_mode, "window_size": window_size, "vsync": vsync,
		"controller": controller_shortcuts, "swap_shoulders": swap_shoulders, "end_shortcut": end_shortcut,
		"bindings": control_bindings,
		"focus_tooltips": %FocusHelp.hints_enabled,
	}


func update_tooltip_toggle(toolbar: Control) -> void:
	%FocusHelp.protected_control = toolbar.get_node("%FocusTooltips")
	var toggle: CheckButton = toolbar.get_node("%FocusTooltips")
	var pad := Bindings.active_label(&"focus_tooltips", 1)
	toggle.text = ("R3" if pad == "Right stick click" else pad) + " Help"
	toggle.tooltip_text = "CONTROLLER HELP\nShow help for the focused control. Toggle with %s or %s." % [
		pad, Bindings.active_label(&"focus_tooltips", 0),
	]
	toggle.set_pressed_no_signal(%FocusHelp.hints_enabled)


func change_option(key: String, value: Variant) -> void:
	var table := body.get_node_or_null("CombatTable")
	var toolbar := body.get_node_or_null("TableToolbar")
	match key:
		"sound":
			combat_sound = value
			if table != null:
				table.combat_audio.set_enabled(combat_sound)
				toolbar.get_node("%Sound").set_pressed_no_signal(combat_sound)
		"motion":
			combat_motion = value
			if table != null:
				table.set_motion_enabled(combat_motion)
				toolbar.get_node("%Motion").set_pressed_no_signal(combat_motion)
		"fast_turns":
			set_fast_turns(value)
			if toolbar != null:
				toolbar.get_node("%FastTurns").set_pressed_no_signal(fast_rival_turns)
		"volume":
			master_volume = value
			apply_volume()
		"effects_volume":
			effects_volume = value
			apply_volume()
		"window_mode":
			window_mode = value
			apply_window()
		"window_size":
			window_size = value
			apply_window()
		"vsync":
			vsync = value
			apply_vsync()
		"bindings":
			control_bindings = Bindings.sanitize(value)
			Bindings.apply(control_bindings)
			if table != null:
				table.update_hand_shortcut()
			if toolbar != null:
				update_tooltip_toggle(toolbar)
		"focus_tooltips":
			%FocusHelp.hints_enabled = value
			if toolbar != null:
				update_tooltip_toggle(toolbar)
		"controller", "swap_shoulders", "end_shortcut":
			match key:
				"controller": controller_shortcuts = value
				"swap_shoulders": swap_shoulders = value
				"end_shortcut": end_shortcut = value
			if table != null:
				table.configure_controller(controller_shortcuts, swap_shoulders, end_shortcut)
	var config := ConfigFile.new()
	var values := option_values()
	for option in values:
		config.set_value("table", option, values[option])
	var error := config.save(options_path)
	if error != OK:
		push_warning("Could not save options: " + error_string(error))


func show_options() -> void:
	if has_node("OptionsMenu"):
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	var table := body.get_node_or_null("CombatTable")
	var resume: bool = table != null and not table.rival_timer.is_stopped()
	if resume:
		table.rival_timer.stop()
	if table != null:
		table.pause_lesson_delay(true)
	var menu := OptionsMenu.instantiate()
	add_child(menu)
	menu.preference_changed.connect(change_option)
	menu.quit_requested.connect(func(): get_tree().quit())
	menu.close_requested.connect(func():
		menu.hide()
		menu.queue_free()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
		if is_instance_valid(table):
			table.pause_lesson_delay(false)
		if resume and is_instance_valid(table) and not table.session.player_turn and table.session.outcome.is_empty():
			table.rival_timer.start())
	menu.open(option_values(), supports_desktop_display())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if screen == "result":
			get_viewport().set_input_as_handled()
			review_result()
		elif _back_action.is_valid():
			get_viewport().set_input_as_handled()
			_back_action.call()
		return
	if event.is_action_pressed("menu_options"):
		get_viewport().set_input_as_handled()
		show_options()
	elif get_viewport().gui_get_focus_owner() == null:
		for direction in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(direction):
				var page: Control = main_menu if screen == "menu" else body
				var first := main_menu.get_node("%JourneyButton") as Control if screen == "menu" else page.find_next_valid_focus()
				if first != null and page.is_ancestor_of(first):
					first.grab_focus()
					get_viewport().set_input_as_handled()
				return


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
	result_overlay = CombatResult.instantiate()
	add_child(result_overlay)
	var table := body.get_node("CombatTable")
	if table.guided:
		result_overlay.setup(summary, show_lesson, show_menu, review_result, "Retry lesson", "Main menu")
	elif _table_is_journey and journey != null:
		if journey.phase == Journey.Phase.DUEL:
			journey.finish_encounter(body.get_node("CombatTable").session)
			journey_checkpoint.save_run(journey, journey_deck_name)
		var next := show_journey_reward if journey.phase == Journey.Phase.REWARD else show_journey_summary
		result_overlay.setup(summary, next, end_journey, review_result, "Choose your next step" if journey.phase == Journey.Phase.REWARD else "Journey summary", "End journey")
	else:
		result_overlay.setup(summary, show_table, show_setup, review_result)
	show_victory_spoils(table.session, summary)
	if _table_is_journey and not journey_checkpoint.error_message.is_empty():
		result_overlay.set_spoils(journey_checkpoint.error_message)


func show_victory_spoils(session: RefCounted, summary: Dictionary) -> void:
	if summary.outcome != "Victory" or session.rival_definition == null:
		return
	if _paid_session != session:
		var rival_id: String = session.rival_definition.id
		var locked := RelicCollection.CATALOG.filter(func(relic): return not relics.meets_milestone(relic))
		var amount := 0
		if not _table_is_journey:
			amount = relics.record_victory(rival_id, false)
		elif journey_checkpoint.error_message.is_empty():
			amount = collect_journey_marks()
		if amount == 0:
			result_overlay.set_spoils(relics.error_message)
			return
		_paid_session = session
		_spoils_text = "+%d MARKS" % amount
		var unlocked := locked.filter(func(relic): return relics.meets_milestone(relic))
		if unlocked.size() == 1:
			_spoils_text += "   ·   %s milestone reached" % unlocked[0].title
		elif unlocked.size() > 1:
			_spoils_text += "   ·   %d relic milestones reached" % unlocked.size()
	result_overlay.set_spoils(_spoils_text)


func collect_journey_marks() -> int:
	var paid := 0
	for index in unpaid_journey_victories():
		var amount := relics.record_victory(Rivals.ALL[index].id, index == Rivals.ALL.size() - 1, journey.checkpoint_id, index)
		if amount == 0:
			break
		paid += amount
	return paid


func unpaid_journey_victories() -> Array[int]:
	var stages: Array[int] = []
	for index in range(journey.summaries.size()):
		if journey.summaries[index].outcome == "Victory" and not relics.has_journey_receipt(journey.checkpoint_id, index):
			stages.append(index)
	return stages


func save_journey_boundary() -> void:
	if journey_checkpoint.save_run(journey, journey_deck_name):
		collect_journey_marks()


func journey_save_notice() -> String:
	return journey_checkpoint.error_message if not journey_checkpoint.error_message.is_empty() else relics.error_message


func show_journey_setup() -> void:
	if journey != null:
		show_journey_overview()
		return
	preparing_journey = true
	selected_rival = Rivals.ALL[0]
	show_setup()


func begin_journey() -> void:
	if not preparing_journey or not valid_selection() or journey != null:
		return
	journey_deck_name = library.decks[player_index].name
	journey = Journey.new(library.instantiate_deck(library.decks[player_index]), false, relics.equipped())
	journey.checkpoint_id = Crypto.new().generate_random_bytes(16).hex_encode()
	preparing_journey = false
	save_journey_boundary()
	show_journey_overview()


func show_journey_overview() -> void:
	if journey == null:
		show_menu()
		return
	if journey.phase == Journey.Phase.REWARD:
		show_journey_reward()
		return
	if journey.phase == Journey.Phase.COMPLETE or journey.phase == Journey.Phase.DEFEAT:
		show_journey_summary()
		return
	screen = "journey"
	clear("The road between duels", "Scout each rival along the route. Your deck and health carry from one chapter to the next.")
	var hp: int = journey.active_session.player.health if journey.active_session != null else journey.health
	Style.label(body, "%s  ·  HP %d / %d  ·  %d cards" % [journey_deck_name, hp, journey.max_health, journey.roster.size()], 17, Style.GOLD)
	Style.label(body, "Journey saves between fights. If you quit mid-duel, the chapter restarts.", 13, Style.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chart := JourneyMap.instantiate()
	body.add_child(chart)
	chart.setup(journey, show_journey_encounter, combat_motion)
	if not journey.edits.is_empty():
		Style.label(body, "JOURNEY DECK CHANGES", 13, Style.GOLD)
		for edit in journey.edits:
			Style.label(body, edit, 15)
	var footer := Style.row(body)
	var leave := Style.button(footer, "Main menu — keep this journey", show_menu)
	_back_action = show_menu
	var end := Style.button(footer, "End this journey", confirm_end_journey)
	chart.connect_footer(leave, end)


func confirm_end_journey() -> void:
	%EndJourneyDialog.popup_centered()
	%EndJourneyDialog.get_cancel_button().grab_focus()


func show_journey_encounter() -> void:
	if journey == null:
		return
	if journey.phase == Journey.Phase.READY and not journey_checkpoint.error_message.is_empty():
		save_journey_boundary()
	var session: RefCounted = journey.start_encounter() if journey.phase == Journey.Phase.READY else journey.active_session
	if session == null:
		return
	var rival: Resource = journey.current_rival()
	mount_table([], [], journey_deck_name, rival.display_name, rival, session, true)


func show_journey_reward() -> void:
	if journey == null or journey.phase != Journey.Phase.REWARD:
		return
	screen = "journey_reward"
	clear("A pause between the lines.", "Choose one reward for this journey. Your saved deck stays as it was.")
	var next_rival: Resource = Rivals.ALL[journey.stage + 1]
	var reward := JourneyReward.instantiate()
	body.add_child(reward)
	reward.get_node("%Context").text = "HP %d / %d   ·   NEXT: %s   ·   %s" % [journey.health, journey.max_health, next_rival.display_name, next_rival.doctrine_text()]
	reward.get_node("%Briefing").text = next_rival.opening_advice
	reward.get_node("%Briefing").visible = not next_rival.opening_advice.is_empty()
	var profile: Label = reward.get_node("%DeckProfile")
	profile.text = journey_deck_profile()
	var recover: Button = reward.get_node("%Recover")
	var missing: int = journey.max_health - journey.health
	recover.text = "Recover %d HP" % mini(missing, journey.RECOVERY) if missing > 0 else "Already at full HP"
	recover.disabled = missing == 0
	recover.pressed.connect(take_journey_recovery)
	reward.get_node("%Skip").pressed.connect(skip_journey_reward)
	for definition in journey.draft_offers():
		var entry := DraftCard.instantiate()
		entry.name = String(definition.id)
		reward.get_node("%Offers").add_child(entry)
		entry.get_node("%Card").setup_preview(CardInstance.new(definition))
		var button: Button = entry.get_node("%Draft")
		button.text = "Draft " + definition.display_name
		button.pressed.connect(take_journey_draft.bind(definition))
		preview_reward_profile(button, profile, definition.category)
	var revision: Button = reward.get_node("%RevisionToggle")
	var removal: Button = reward.get_node("%RemovalToggle")
	removal.disabled = journey.roster.size() <= 1
	revision.toggled.connect(func(enabled: bool): show_reward_panel(reward, "Revisions" if enabled else "Draft"))
	removal.toggled.connect(func(enabled: bool): show_reward_panel(reward, "Removal" if enabled else "Draft"))
	_back_action = func():
		if revision.button_pressed:
			revision.button_pressed = false
			revision.grab_focus()
		elif removal.button_pressed:
			removal.button_pressed = false
			removal.grab_focus()
		else:
			show_menu()


func show_reward_panel(reward: Control, panel: String) -> void:
	var revision: Button = reward.get_node("%RevisionToggle")
	var removal: Button = reward.get_node("%RemovalToggle")
	revision.set_pressed_no_signal(panel == "Revisions")
	removal.set_pressed_no_signal(panel == "Removal")
	revision.text = "Back to draft" if panel == "Revisions" else "Revise a card"
	removal.text = "Back to draft" if panel == "Removal" else "Remove a card"
	reward.get_node("%Draft").visible = panel == "Draft"
	var revisions: VBoxContainer = reward.get_node("%Revisions")
	revisions.visible = panel == "Revisions"
	if revisions.visible and revisions.get_child_count() == 0:
		build_journey_revisions(revisions, reward.get_node("%DeckProfile"))
	reward.get_node("%Removal").visible = panel == "Removal"
	var cuts: Control = reward.get_node("%Cuts")
	if panel == "Removal" and cuts.get_child_count() == 0:
		build_journey_cuts(cuts, reward.get_node("%DeckProfile"))


func journey_deck_profile(added: int = -1, removed: int = -1) -> String:
	var counts := [0, 0, 0]
	for card: CardInstance in journey.roster:
		counts[card.get_category()] += 1
	if added >= 0:
		counts[added] += 1
	if removed >= 0:
		counts[removed] -= 1
	var heading := "AFTER THIS CHOICE" if added >= 0 or removed >= 0 else "JOURNEY DECK"
	return "%s  ·  %d cards  ·  %d Attack / %d Guard / %d Tactic" % [
		heading, journey.roster.size() + int(added >= 0) - int(removed >= 0), counts[0], counts[1], counts[2],
	]


func preview_reward_profile(button: Button, profile: Label, added: int = -1, removed: int = -1) -> void:
	var preview := journey_deck_profile(added, removed)
	var current := journey_deck_profile()
	button.tooltip_text = preview
	button.focus_entered.connect(func(): profile.text = preview)
	button.focus_exited.connect(func(): profile.text = current)


func build_journey_cuts(list: Control, profile: Label) -> void:
	var groups := {}
	for index in range(journey.roster.size()):
		var card: CardInstance = journey.roster[index]
		var key := "%s/%d/%d" % [card.definition.id, card.get_category(), card.cost_modifier]
		if groups.has(key):
			groups[key].count += 1
		else:
			groups[key] = {"index": index, "count": 1}
	for group: Dictionary in groups.values():
		var card: CardInstance = journey.roster[group.index]
		var entry := DraftCard.instantiate()
		list.add_child(entry)
		entry.get_node("%Card").setup_preview(card, "%d in Journey deck" % group.count)
		var cut: Button = entry.get_node("%Draft")
		cut.text = "Cut " + card.definition.display_name
		cut.pressed.connect(take_journey_cut.bind(group.index))
		preview_reward_profile(cut, profile, -1, card.get_category())


func build_journey_revisions(list: VBoxContainer, profile: Label) -> void:
	Style.heading(list, "Revise a card", 23)
	Style.label(list, "Change one card’s category for Cadence and Patterns. Its effects stay the same.", 15, Style.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var names := CardDefinition.Category.keys()
	for index in range(journey.roster.size()):
		var card: CardInstance = journey.roster[index]
		var panel := Style.panel(list)
		var row := Style.row(panel)
		var label := Style.label(row, "%02d  %s · %s" % [index + 1, card.definition.display_name, names[card.get_category()].capitalize()], 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for category in range(3):
			var button := Style.button(row, names[category].capitalize(), take_journey_edit.bind(index, category))
			button.disabled = category == card.get_category()
			if not button.disabled:
				preview_reward_profile(button, profile, category, card.get_category())


func take_journey_draft(definition: CardDefinition) -> void:
	if journey != null and journey.draft_card(definition):
		save_journey_boundary()
		show_journey_overview()


func take_journey_recovery() -> void:
	if journey != null and journey.take_recovery():
		save_journey_boundary()
		show_journey_overview()


func take_journey_edit(index: int, category: int) -> void:
	if journey != null and journey.reclassify(index, category):
		save_journey_boundary()
		show_journey_overview()


func take_journey_cut(index: int) -> void:
	if journey != null and journey.remove_card(index):
		save_journey_boundary()
		show_journey_overview()


func skip_journey_reward() -> void:
	if journey != null and journey.skip_reward():
		save_journey_boundary()
		show_journey_overview()


func show_journey_summary() -> void:
	if journey == null:
		return
	screen = "journey_summary"
	clear("The last line is yours." if journey.phase == Journey.Phase.COMPLETE else "This ending can be rewritten.", "Journey complete" if journey.phase == Journey.Phase.COMPLETE else "Your journey ended in defeat")
	var totals: Dictionary = journey.totals()
	var panel := Style.panel(body)
	Style.heading(panel, "%d / 3 duels won" % totals.wins, 34)
	Style.label(panel, "%d cards played  ·  %d HP damage  ·  %d rewrites  ·  %d Patterns" % [totals.cards, totals.damage, totals.rewrites, totals.patterns], 16)
	for edit in journey.edits:
		Style.label(panel, edit, 15, Style.MUTED)
	Style.primary(Style.button(body, "Return to main menu", end_journey))
	_back_action = end_journey


func end_journey() -> void:
	if journey_checkpoint.has_run:
		if journey != null and not unpaid_journey_victories().is_empty():
			if journey.phase != Journey.Phase.DUEL:
				save_journey_boundary()
			elif journey_checkpoint.error_message.is_empty():
				collect_journey_marks()
			if not unpaid_journey_victories().is_empty():
				show_menu()
				return
		if not journey_checkpoint.write({}):
			show_menu()
			return
	journey = null
	preparing_journey = false
	_table_is_journey = false
	show_menu()
