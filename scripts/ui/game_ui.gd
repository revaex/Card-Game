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
var _table_is_puzzle: bool = false
var _puzzle_started_at := 0
var _puzzle_elapsed := -1
var _puzzle_bests := {}
var _puzzle_attempts := {}
var _puzzle_wins := {}
var _puzzle_best_rounds := {}
var _practice_strict := false
var _practice_carry := false
var _practice_energy := false
var _practice_record_key := ""
var margin_burn_playtest: bool = false
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
	var rules := Style.row(body)
	Style.label(rules, "Practice rules", 15, Style.GOLD)
	var strict := CheckButton.new()
	strict.name = "StrictPracticeQueue"
	strict.text = "Strict queue"
	strict.tooltip_text = "Stop at the first unaffordable card. Cards behind it wait, including free cards."
	strict.set_pressed_no_signal(_practice_strict)
	strict.toggled.connect(func(enabled: bool): _practice_strict = enabled)
	rules.add_child(strict)
	var carry := CheckButton.new()
	carry.name = "CarryPracticeReserves"
	carry.text = "Carry reserves"
	carry.tooltip_text = "Keep unplayed cards at the front of the next hand. Doctrine orders only the new draws."
	carry.set_pressed_no_signal(_practice_carry)
	carry.toggled.connect(func(enabled: bool): _practice_carry = enabled)
	rules.add_child(carry)
	var energy_trade := CheckButton.new()
	energy_trade.name = "PracticeCadenceEnergy"
	energy_trade.text = "Cadence for energy"
	energy_trade.tooltip_text = "Spend 3 Cadence for 1 energy once per player turn."
	energy_trade.set_pressed_no_signal(_practice_energy)
	energy_trade.toggled.connect(func(enabled: bool): _practice_energy = enabled)
	rules.add_child(energy_trade)
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
		Style.button(panel, "Practice fixed-opening puzzle", func(): show_rival_puzzle(index, _practice_strict, _practice_carry, _practice_energy))
		Style.button(panel, "Scout opening", scout_rival_opening.bind(rival))
	Style.button(body, "← Main menu", show_menu)
	_back_action = show_menu


func scout_rival_opening(rival: Resource) -> void:
	var cards: Array[CardInstance] = rival.create_deck()
	var player_cards: Array[CardInstance] = [CardInstance.new(StarterDeck.BLOCK)]
	var preview := CombatSession.new(player_cards, cards, false, false, rival)
	var names := PackedStringArray()
	var affordable := PackedStringArray()
	var plan: Array[CardInstance] = preview.enemy_opening_plan()
	for card in preview.enemy_piles.hand:
		names.append(card.definition.display_name)
		if plan.has(card):
			affordable.append(card.definition.display_name)
	var previous := get_viewport().gui_get_focus_owner()
	var dialog := preload("res://scenes/ui/folio_reader.tscn").instantiate()
	dialog.name = "OpeningScout"
	add_child(dialog)
	dialog.close_requested.connect(func():
		dialog.hide()
		dialog.queue_free()
		if is_instance_valid(previous):
			previous.grab_focus())
	var opening_notes := "Affordable opening: %s\nDoctrine for new hands: %s\n\n%s" % [" → ".join(affordable), rival.doctrine_text(), rival.opening_advice]
	var pages: Array[Dictionary] = [{"section": "SCOUT OPENING", "title": rival.display_name, "route": " → ".join(names), "body": opening_notes}]
	if _practice_strict or _practice_carry or _practice_energy:
		preview.strict_rival_queue = _practice_strict
		preview.carry_rival_reserves = _practice_carry
		preview.cadence_energy_enabled = _practice_energy
		plan = preview.enemy_opening_plan()
		var planned := PackedStringArray()
		for card in plan:
			planned.append(card.definition.display_name)
		var threat := preview.line_threat(plan)
		var blocker := preview.rival_queue_blocker(preview.enemy_piles.hand, plan)
		var reserves := PackedStringArray()
		for card in preview.rival_carryover(preview.enemy_piles.hand, plan):
			reserves.append(card.definition.display_name)
		var details := "Visible energy spent %d · unused %d." % [threat.spent, threat.unused]
		if blocker != null:
			details += "\nStrict queue stops at %s." % blocker.definition.display_name
		if _practice_carry:
			details += "\nNext front: %s." % (", ".join(reserves) if not reserves.is_empty() else "none visible")
		if threat.draws:
			details += "\nDraw effects may change the remaining line."
		pages.append({"section": "PRACTICE SCOUT", "title": practice_rules_text(preview), "route": " → ".join(planned), "body": details})
	dialog.open(pages, "Return to rivals", combat_motion)


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
	var recipes: Array[Dictionary] = [library.counterpoint_recipe(), library.palimpsest_recipe(), library.counterwritten_recipe(), library.counterpoint_sustain_recipe()]
	recipes.append_array(library.style_recipes())
	for recipe in recipes:
		presets.add_item(recipe.name)
	presets.item_selected.connect(func(item: int):
		library.decks.append(recipes[item - 1].duplicate(true))
		library.save()
		show_editor(library.decks.size() - 1, selecting))
	toolbar.add_child(presets)
	var filters := Style.row(body)
	var search := LineEdit.new()
	search.name = "DeckSearch"
	search.placeholder_text = "Search deck names"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	var ready := CheckButton.new()
	ready.name = "JourneyReadyFilter"
	ready.text = "Journey ready only"
	filters.add_child(ready)
	var alphabetical := CheckButton.new()
	alphabetical.name = "AlphabeticalDecks"
	alphabetical.text = "A–Z"
	filters.add_child(alphabetical)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := Style.column(scroll, true)
	if library.decks.is_empty():
		Style.label(list, "No decks yet. Create your first deck above.", 20, Style.MUTED)
	for index in range(library.decks.size()):
		var recipe: Dictionary = library.decks[index]
		var item := Style.panel(list)
		item.get_parent().set_meta("recipe", recipe)
		var line := Style.row(item)
		var name_label := Style.label(line, "%s   /   %d cards" % [recipe.name, library.total(recipe)], 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.button(line, "View cards", show_deck_cards.bind(index))
		Style.button(line, "Edit cards", show_editor.bind(index, selecting))
		Style.button(line, "Duplicate", duplicate_deck.bind(index, selecting))
		Style.button(line, "Remove", confirm_remove.bind(index, selecting))
	var no_matches := Style.label(list, "No decks match these filters.", 16, Style.MUTED)
	no_matches.hide()
	var deck_rows: Array[Node] = list.get_children().filter(func(row): return row.has_meta("recipe"))
	alphabetical.toggled.connect(func(enabled: bool):
		var order := deck_rows.duplicate()
		if enabled:
			order.sort_custom(func(a: Node, b: Node): return String(a.get_meta("recipe").name).naturalnocasecmp_to(String(b.get_meta("recipe").name)) < 0)
		for index in range(order.size()):
			list.move_child(order[index], index))
	var apply_filter := func():
		var matches := 0
		for row in list.get_children():
			if not row.has_meta("recipe"):
				continue
			var recipe: Dictionary = row.get_meta("recipe")
			var query := search.text.strip_edges()
			row.visible = (query.is_empty() or String(recipe.name).containsn(query)) and (not ready.button_pressed or library.journey_issues(recipe).is_empty())
			matches += int(row.visible)
		no_matches.visible = matches == 0 and not library.decks.is_empty()
	search.text_changed.connect(func(_value: String): apply_filter.call())
	ready.toggled.connect(func(_value: bool): apply_filter.call())
	_back_action = show_setup if selecting else show_menu
	Style.button(body, "← Back", _back_action)


func duplicate_deck(index: int, selecting: bool) -> void:
	var copy: Dictionary = library.decks[index].duplicate(true)
	copy.name = String(copy.name).left(27) + " copy"
	library.decks.append(copy)
	if library.save():
		show_editor(library.decks.size() - 1, selecting)
	else:
		library.decks.pop_back()
		show_library(selecting)


func rename_deck(index: int, value: String, status: Label) -> void:
	var name_text := value.strip_edges()
	if name_text.is_empty():
		status.text = "Enter a deck name."
		return
	var recipe: Dictionary = library.decks[index]
	var previous: String = recipe.name
	recipe.name = name_text
	if library.save():
		body.get_node("PageHeading").get_node("%Title").text = name_text
		status.text = "Name saved."
	else:
		recipe.name = previous
		status.text = library.error_message


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


func show_editor(index: int, selecting: bool, from_setup: bool = false) -> void:
	screen = "editor"
	editing = index
	var recipe: Dictionary = library.decks[index]
	clear(recipe.name, "Click, press Confirm, or drag a card to the deck tray to add it. Use − to remove a copy.")
	var editor := DeckEditor.instantiate()
	body.add_child(editor)
	_back_action = show_setup if from_setup else show_library.bind(selecting)
	editor.get_node("%Done").pressed.connect(_back_action)
	var tray: PanelContainer = editor.get_node("%DeckTray")
	tray.add_theme_stylebox_override("panel", Style.box(Color("142a2c")))
	tray.set_drag_forwarding(Callable(), can_drop_deck_card.bind(editor, recipe), drop_deck_card.bind(index, selecting))
	var foley := AudioStreamPlayer.new()
	foley.name = "DeckAddSound"
	foley.stream = preload("res://data/audio/deal.wav")
	foley.bus = &"Effects"
	foley.volume_db = -6.0
	editor.add_child(foley)
	var equipped := relics.equipped()
	editor.get_node("%EquippedRelic").text = "Profile relic · " + (equipped.title if equipped != null else "None")
	var cards := editor.get_node("%Cards")
	var contents := editor.get_node("%DeckContents")
	var controls := Style.row(editor)
	editor.move_child(controls, editor.get_node("Workshop").get_index())
	var query := LineEdit.new()
	query.name = "CatalogueSearch"
	query.placeholder_text = "Search card names or effects"
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(query)
	var category := OptionButton.new()
	category.name = "CatalogueCategory"
	category.add_item("All categories")
	for title in CardDefinition.Category.keys():
		category.add_item(title.capitalize())
	controls.add_child(category)
	var energy_filter := OptionButton.new()
	energy_filter.name = "CatalogueEnergy"
	energy_filter.add_item("Any energy")
	var costs: Array[int] = []
	for definition in Library.CARDS:
		if definition.energy_cost not in costs:
			costs.append(definition.energy_cost)
	costs.sort()
	for cost in costs:
		energy_filter.add_item("%d energy" % cost, cost)
	controls.add_child(energy_filter)
	var in_deck := CheckButton.new()
	in_deck.name = "CatalogueInDeck"
	in_deck.text = "In deck"
	controls.add_child(in_deck)
	var no_matches := Style.label(cards, "No matching cards.", 16, Style.MUTED)
	no_matches.hide()
	var apply_filter := func():
		var matches := 0
		var search_text := query.text.strip_edges()
		var energy := energy_filter.get_selected_id()
		for definition in Library.CARDS:
			var id := String(definition.id)
			var visible_card: bool = (category.selected == 0 or definition.category == category.selected - 1) and (not in_deck.button_pressed or int(recipe.cards.get(id, 0)) > 0)
			visible_card = visible_card and (energy_filter.selected == 0 or definition.energy_cost == energy)
			visible_card = visible_card and (search_text.is_empty() or String(definition.display_name).containsn(search_text) or String(definition.description).containsn(search_text))
			cards.get_node(id).visible = visible_card
			matches += int(visible_card)
		no_matches.visible = matches == 0
	editor.set_meta("apply_filter", apply_filter)
	query.text_changed.connect(func(_value: String): apply_filter.call())
	category.item_selected.connect(func(_value: int): apply_filter.call())
	energy_filter.item_selected.connect(func(_value: int): apply_filter.call())
	in_deck.toggled.connect(func(_value: bool): apply_filter.call())
	Style.button(controls, "Clear filters", func():
		query.clear()
		category.select(0)
		energy_filter.select(0)
		in_deck.set_pressed_no_signal(false)
		apply_filter.call())
	var naming := Style.row(editor)
	editor.move_child(naming, controls.get_index())
	var name_input := LineEdit.new()
	name_input.name = "DeckName"
	name_input.text = recipe.name
	name_input.max_length = 32
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming.add_child(name_input)
	var name_status := Style.label(naming, "", 14, Style.MUTED)
	Style.button(naming, "Rename deck", func(): rename_deck(index, name_input.text, name_status))
	name_input.text_submitted.connect(func(value: String): rename_deck(index, value, name_status))
	for definition in Library.CARDS:
		var id := String(definition.id)
		var entry := DeckCard.instantiate()
		entry.name = id
		cards.add_child(entry)
		var add_copy := change_count.bind(index, id, 1, selecting)
		var card: Control = entry.get_node("%Card")
		card.setup_deck_add(CardInstance.new(definition), add_copy)
		card.get_node("%Play").set_drag_forwarding(drag_deck_card.bind(card, editor, id), Callable(), Callable())
		var remove: Button = entry.get_node("%Remove")
		var add: Button = entry.get_node("%Add")
		remove.tooltip_text = "Remove one copy of %s" % definition.display_name
		add.tooltip_text = "Add one copy of %s" % definition.display_name
		var remove_copy := change_count.bind(index, id, -1, selecting)
		remove.pressed.connect(remove_copy)
		add.pressed.connect(add_copy)
		var row := Style.row(contents)
		row.name = id
		var caption := Style.label(row, definition.display_name, 14)
		caption.name = "Caption"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tray_remove := Style.button(row, "−", remove_copy)
		tray_remove.name = "Remove"
		tray_remove.accessibility_name = remove.tooltip_text
		tray_remove.tooltip_text = remove.tooltip_text
		Style.quiet(tray_remove)
		update_deck_card(entry, row, int(recipe.cards.get(id, 0)))
	update_deck_summary(editor, recipe)


func drag_deck_card(_position: Vector2, card: Control, editor: Node, id: String) -> Variant:
	if card.get_node("%Play").disabled:
		return null
	var preview := Control.new()
	var snapshot: Control = card.make_snapshot()
	preview.add_child(snapshot)
	snapshot.scale = Vector2.ONE * 0.75
	snapshot.position = -snapshot.size * 0.375
	card.set_drag_preview(preview)
	return {"deck_editor": editor.get_instance_id(), "card_id": id}


func can_drop_deck_card(_position: Vector2, data: Variant, editor: Node, recipe: Dictionary) -> bool:
	if not data is Dictionary or data.get("deck_editor") != editor.get_instance_id():
		return false
	var id: String = data.get("card_id", "")
	return not id.is_empty() and editor.get_node("%Cards").has_node(id) and int(recipe.cards.get(id, 0)) < Library.RECIPE_COPY_LIMIT


func drop_deck_card(_position: Vector2, data: Dictionary, index: int, selecting: bool) -> void:
	change_count(index, data.card_id, 1, selecting)


func play_deck_add_feedback(editor: Control, card: Control) -> void:
	if combat_sound:
		editor.get_node("DeckAddSound").play()
	if not combat_motion or not card.is_visible_in_tree():
		return
	var snapshot: Control = card.make_snapshot()
	add_child(snapshot)
	editor.tree_exiting.connect(snapshot.queue_free, CONNECT_ONE_SHOT)
	snapshot.global_position = card.global_position
	snapshot.z_index = 20
	var tray: Control = editor.get_node("%DeckTray")
	var destination := tray.global_position + tray.size * Vector2(0.5, 0.2) - snapshot.size * 0.17
	var flight := snapshot.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flight.tween_property(snapshot, "global_position", destination, 0.26)
	flight.tween_property(snapshot, "scale", Vector2.ONE * 0.34, 0.26)
	flight.tween_property(snapshot, "modulate:a", 0.0, 0.16).set_delay(0.10)
	flight.chain().tween_callback(snapshot.queue_free)


func update_deck_card(entry: Node, tray_row: HBoxContainer, count: int) -> void:
	var card := entry.get_node("%Card")
	card.set_caption("%d in deck" % count)
	card.set_deck_add_enabled(count < Library.RECIPE_COPY_LIMIT)
	entry.get_node("%Remove").disabled = count == 0
	entry.get_node("%Add").disabled = count >= Library.RECIPE_COPY_LIMIT
	if count == 0 and tray_row.get_node("Remove").has_focus():
		card.get_node("%Play").grab_focus()
	tray_row.visible = count > 0
	tray_row.get_node("Caption").text = "%s ×%d" % [card.get_node("%Title").text, count]


func update_deck_summary(editor: Node, recipe: Dictionary) -> void:
	var counts: Array[int] = library.category_counts(recipe)
	var size: int = library.total(recipe)
	editor.get_node("%Total").text = "%d cards  ·  Attack %d  ·  Guard %d  ·  Tactic %d" % [size, counts[0], counts[1], counts[2]]
	editor.get_node("%EmptyDeck").visible = size == 0
	editor.get_node("%DeckProfile").text = library.profile_text(recipe)
	var issues: PackedStringArray = library.journey_issues(recipe)
	var status: Label = editor.get_node("%JourneyStatus")
	status.text = "Ready for a Journey." if issues.is_empty() else "Journey requirements\n" + "\n".join(issues)
	status.tooltip_text = "Journeys start with %d–%d cards and up to %d copies of each card. Strike and Block are exempt from the copy limit." % [Library.JOURNEY_MIN_CARDS, Library.JOURNEY_MAX_CARDS, Library.JOURNEY_COPY_LIMIT]
	if not library.error_message.is_empty():
		status.text += "\n" + library.error_message


func change_count(index: int, id: String, amount: int, selecting: bool) -> void:
	var recipe: Dictionary = library.decks[index]
	var previous := int(recipe.cards.get(id, 0))
	var count := clampi(previous + amount, 0, Library.RECIPE_COPY_LIMIT)
	if count == previous:
		return
	recipe.cards[id] = count
	var saved: bool = library.save()
	if not saved:
		recipe.cards[id] = previous
		count = previous
	var editor := body.get_node_or_null("DeckEditor")
	if screen != "editor" or editing != index or editor == null:
		show_editor(index, selecting)
		return
	var entry := editor.get_node("%Cards").get_node_or_null(id)
	if entry != null:
		update_deck_card(entry, editor.get_node("%DeckContents").get_node(id), count)
		if saved and amount > 0:
			play_deck_add_feedback(editor, entry.get_node("%Card"))
	update_deck_summary(editor, recipe)
	var apply_filter: Callable = editor.get_meta("apply_filter")
	apply_filter.call()


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
			Style.button(panel, "Edit this deck", show_editor.bind(selected, true, true))
			var counts: Array[int] = library.category_counts(library.decks[selected])
			Style.label(panel, "Attack %d  ·  Guard %d  ·  Tactic %d" % counts, 13, Style.MUTED)
			if side == "player" and preparing_journey:
				for issue in library.journey_issues(library.decks[selected]):
					Style.label(panel, issue, 16, Color("ffa293")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if side == "player" and counts.has(0):
				Style.label(panel, "Patterns use all three categories.", 13, Style.GOLD)
				Style.button(panel, "Try the Counterpoint deck", use_counterpoint_deck)
	var equipment := Style.row(body)
	var equipped := relics.equipped()
	Style.label(equipment, "RELIC   /   " + (equipped.title if equipped != null else "None"), 15, Style.GOLD)
	Style.button(equipment, "Change relic", show_relics.bind(true))
	if not preparing_journey:
		var experiment := CheckButton.new()
		experiment.name = "MarginBurnPlaytest"
		experiment.text = "Playtest Margin Burn (no progression rewards)"
		experiment.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		experiment.tooltip_text = "Once per duel, exhaust a card in hand for up to 2 Cadence. Playtest victories award no Marks or milestones."
		experiment.set_pressed_no_signal(margin_burn_playtest)
		experiment.toggled.connect(func(enabled: bool): margin_burn_playtest = enabled)
		body.add_child(experiment)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	var confirm := Style.button(actions, "Begin the journey  →" if preparing_journey else "Begin the duel  →", begin_journey if preparing_journey else show_table)
	Style.primary(confirm)
	confirm.disabled = not valid_selection()
	Style.button(actions, "Create / edit decks", show_library.bind(true))
	if selected_rival == null and valid_selection() and player_index != enemy_index:
		Style.button(actions, "Swap decks", func():
			var previous := player_index
			player_index = enemy_index
			enemy_index = previous
			show_setup())
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
	var counts: Array[int] = library.category_counts(recipe)
	dialog.show_cards(recipe.name, library.instantiate_deck(recipe), "Attack %d  ·  Guard %d  ·  Tactic %d" % counts)


func use_counterpoint_deck() -> void:
	for index in range(library.decks.size()):
		var recipe: Dictionary = library.decks[index]
		if recipe.name == "Counterpoint" and not library.category_counts(recipe).has(0) and (not preparing_journey or library.journey_issues(recipe).is_empty()):
			player_index = index
			show_setup()
			return
	library.decks.append(library.counterpoint_recipe())
	player_index = library.decks.size() - 1
	library.save()
	show_setup()


func valid_selection() -> bool:
	var player_valid: bool = player_index >= 0 and player_index < library.decks.size() and library.total(library.decks[player_index]) > 0
	if player_valid and preparing_journey:
		player_valid = library.journey_issues(library.decks[player_index]).is_empty()
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
	duel.margin_burn_enabled = not preparing_journey and margin_burn_playtest
	mount_table(player_cards, enemy_cards, library.decks[player_index].name, enemy_name, selected_rival, duel)


func show_rival_puzzle(index: int, strict: bool = false, carry: bool = false, energy_trade: bool = false) -> void:
	var rival: Resource = Rivals.ALL[index]
	var mend := preload("res://data/cards/mend.tres")
	var strike := StarterDeck.STRIKE
	var block := StarterDeck.BLOCK
	# CardPiles draws from the end. Keep both opening solutions reproducible.
	var cards: Array[CardInstance] = []
	for definition in [strike, strike, strike, mend, INSIGHT, mend, block, strike, INSIGHT, block]:
		cards.append(CardInstance.new(definition))
	var enemy_cards: Array[CardInstance] = rival.create_deck()
	var duel := CombatSession.new(cards, enemy_cards, false, false, rival)
	duel.strict_rival_queue = strict
	duel.carry_rival_reserves = carry
	duel.cadence_energy_enabled = energy_trade
	mount_table(cards, enemy_cards, "%s puzzle" % rival.display_name.trim_prefix("The "), rival.display_name, rival, duel, false, false, true)
	var table := body.get_node("CombatTable")
	table.message.text = ["Use Rewrite to break up the attack sequence.", "Find a way through the Warden’s opening guard.", "Find a damage window: Rewrite Inkblot or finish Riposte."][index]


func show_lesson() -> void:
	var player_cards: Array[CardInstance] = [CardInstance.new(INSIGHT), CardInstance.new(StarterDeck.BLOCK), CardInstance.new(StarterDeck.STRIKE)]
	for index in range(3):
		player_cards.push_front(CardInstance.new(StarterDeck.BLOCK))
		player_cards.push_front(CardInstance.new(StarterDeck.STRIKE))
	player_cards.push_front(CardInstance.new(INSIGHT))
	var rival_cards: Array[CardInstance] = []
	for index in range(3):
		rival_cards.append(CardInstance.new(StarterDeck.BLOCK))
	rival_cards.append(CardInstance.new(StarterDeck.STRIKE))
	rival_cards.append(CardInstance.new(StarterDeck.STRIKE))
	var practice := CombatSession.new(player_cards, rival_cards, false)
	mount_table(player_cards, rival_cards, "First lesson", "Practice rival", null, practice, false, true)


func mount_table(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], player_name: String, enemy_name: String, rival: Resource, existing: RefCounted = null, in_journey: bool = false, guided: bool = false, puzzle: bool = false) -> void:
	screen = "table"
	_table_is_journey = in_journey
	_table_is_puzzle = puzzle
	if puzzle:
		_puzzle_started_at = Time.get_ticks_msec()
		_puzzle_elapsed = -1
		_practice_record_key = "%s/%d/%d/%d" % [rival.id, int(existing.strict_rival_queue), int(existing.carry_rival_reserves), int(existing.cadence_energy_enabled)]
		_puzzle_attempts[_practice_record_key] = _puzzle_attempts.get(_practice_record_key, 0) + 1
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
	if puzzle:
		leave.text = "← Rivals"
		_back_action = show_rivals
	leave.pressed.connect(_back_action)
	Style.quiet(leave)
	leave.tooltip_text = "JOURNEY\nPause this duel and view your route. Returning here resumes the fight. Closing the game restarts this chapter." if in_journey else "LEAVE TABLE\nReturn to deck preparation. This single duel is discarded; saved decks are unchanged."
	if puzzle:
		leave.tooltip_text = "Return to rival selection. Reopening the puzzle starts a fresh attempt."
		Style.button(toolbar, "Restart puzzle", puzzle_restart(existing))
	var table := Table.instantiate()
	table.name = "CombatTable"
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(table)
	table.motion_enabled = combat_motion
	table.guided = guided
	table.allow_lab = not puzzle
	table.configure_controller(controller_shortcuts, swap_shoulders)
	table.combat_audio.set_enabled(combat_sound)
	table.setup(player_cards, enemy_cards, false, rival, existing)
	if guided:
		table.lesson.completed.connect(show_journey_setup)
		table.lesson.exit_requested.connect(show_menu)
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
		"controller": controller_shortcuts, "swap_shoulders": swap_shoulders,
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
				table.update_combat_shortcuts()
			if toolbar != null:
				update_tooltip_toggle(toolbar)
		"focus_tooltips":
			%FocusHelp.hints_enabled = value
			if toolbar != null:
				update_tooltip_toggle(toolbar)
		"controller", "swap_shoulders":
			match key:
				"controller": controller_shortcuts = value
				"swap_shoulders": swap_shoulders = value
			if table != null:
				table.configure_controller(controller_shortcuts, swap_shoulders)
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
	menu.main_menu_requested.connect(func():
		menu.hide()
		menu.queue_free()
		show_menu())
	menu.close_requested.connect(func():
		menu.hide()
		menu.queue_free()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
		if is_instance_valid(table):
			table.pause_lesson_delay(false)
		if resume and is_instance_valid(table) and not table.session.player_turn and table.session.outcome.is_empty():
			table.rival_timer.start())
	menu.open(option_values(), supports_desktop_display(), screen != "menu")


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
		body.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		var table := body.get_node_or_null("CombatTable")
		if table != null:
			table.set_process_unhandled_input(true)


func review_result() -> void:
	close_result()
	screen = "table"
	var table := body.get_node_or_null("CombatTable")
	if table != null:
		table.end_button.grab_focus()


func show_result(summary: Dictionary) -> void:
	close_result()
	screen = "result"
	body.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	result_overlay = CombatResult.instantiate()
	add_child(result_overlay)
	var table := body.get_node("CombatTable")
	table.set_process_unhandled_input(false)
	if table.guided:
		result_overlay.setup(summary, show_lesson, show_menu, review_result, "Retry lesson", "Main menu")
	elif _table_is_puzzle:
		result_overlay.setup(summary, puzzle_restart(table.session), show_rivals, review_result, "Rematch puzzle", "Rivals")
		Style.primary(result_overlay.get_node("%Rematch"))
		var key := _practice_record_key
		var best: int = _puzzle_bests.get(key, -1)
		if _puzzle_elapsed < 0:
			_puzzle_elapsed = floori((Time.get_ticks_msec() - _puzzle_started_at) / 1000.0)
			if summary.outcome == "Victory":
				_puzzle_wins[key] = _puzzle_wins.get(key, 0) + 1
				_puzzle_best_rounds[key] = mini(int(summary.rounds), _puzzle_best_rounds.get(key, int(summary.rounds)))
				if best < 0 or _puzzle_elapsed < best:
					best = _puzzle_elapsed
					_puzzle_bests[key] = best
		var timing := "Practice time · %s  /  Attempt %d" % [format_puzzle_time(_puzzle_elapsed), _puzzle_attempts[key]]
		if best >= 0:
			timing += "\nSession best · " + format_puzzle_time(best)
			timing += "  /  Fewest turns · %d  /  Wins · %d" % [_puzzle_best_rounds[key], _puzzle_wins[key]]
		timing += "\nRival unused energy %d · Queue stops %d · Cards carried %d" % [table.session.rival_unused_energy, table.session.rival_queue_stops, table.session.reserves_carried_total]
		timing += "\n" + practice_rules_text(table.session)
		result_overlay.set_spoils(timing)
	elif _table_is_journey and journey != null:
		if journey.phase == Journey.Phase.DUEL:
			journey.finish_encounter(body.get_node("CombatTable").session)
			journey_checkpoint.save_run(journey, journey_deck_name)
		var next := show_journey_reward if journey.phase == Journey.Phase.REWARD else show_journey_summary
		result_overlay.setup(summary, next, confirm_end_journey, review_result, "Choose reward  →" if journey.phase == Journey.Phase.REWARD else "Journey summary", "End journey")
		if journey.phase == Journey.Phase.REWARD:
			Style.primary(result_overlay.get_node("%Rematch"))
	else:
		result_overlay.setup(summary, show_table, show_setup, review_result)
	if not _table_is_puzzle:
		show_victory_spoils(table.session, summary)
	if _table_is_journey and not journey_checkpoint.error_message.is_empty():
		result_overlay.set_spoils(journey_checkpoint.error_message)


func practice_rules_text(duel: RefCounted) -> String:
	var names := PackedStringArray()
	if duel.strict_rival_queue:
		names.append("Strict queue")
	if duel.carry_rival_reserves:
		names.append("Carry reserves")
	if duel.cadence_energy_enabled:
		names.append("Cadence for energy")
	return " · ".join(names) if not names.is_empty() else "Standard rules"


func puzzle_restart(duel: RefCounted) -> Callable:
	return show_rival_puzzle.bind(Rivals.ALL.find(duel.rival_definition), duel.strict_rival_queue, duel.carry_rival_reserves, duel.cadence_energy_enabled)


func format_puzzle_time(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


func show_victory_spoils(session: RefCounted, summary: Dictionary) -> void:
	if summary.outcome != "Victory" or session.rival_definition == null:
		return
	if session.margin_burn_enabled:
		result_overlay.set_spoils("Margin Burn playtest · no progression rewards")
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
	var dialog: ConfirmationDialog = %EndJourneyDialog
	var previous := get_viewport().gui_get_focus_owner()
	dialog.popup_centered()
	var cancel := dialog.get_cancel_button()
	var accept := dialog.get_ok_button()
	cancel.focus_neighbor_left = cancel.get_path_to(accept)
	cancel.focus_neighbor_right = cancel.focus_neighbor_left
	accept.focus_neighbor_left = accept.get_path_to(cancel)
	accept.focus_neighbor_right = accept.focus_neighbor_left
	cancel.grab_focus()
	dialog.visibility_changed.connect(func():
		if is_instance_valid(previous) and previous.is_visible_in_tree():
			previous.grab_focus(), CONNECT_ONE_SHOT)


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
	var first_offer := reward.get_node("%Offers").get_child(0)
	if first_offer != null:
		first_offer.get_node("%Draft").grab_focus()
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
