extends VBoxContainer
## Combat presentation. Session owns energy, effects, turns, and results.

const Style = preload("res://scripts/ui/ui_style.gd")
const Session = preload("res://scripts/combat/combat_session.gd")
var session: RefCounted
var sandbox: bool = false
var status_label: Label
var end_button: Button
var draw_button: Button
var redraw_button: Button
var player_piles: CardPiles
var enemy_piles: CardPiles
var hand_row: HBoxContainer
var pile_row: HBoxContainer
var enemy_label: Label
var message: Label


func setup(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance]) -> void:
	add_theme_constant_override("separation", 8)
	session = Session.new(player_cards, enemy_cards)
	player_piles = session.player_piles
	enemy_piles = session.enemy_piles
	var enemy_panel := Style.panel(self)
	enemy_label = Style.label(enemy_panel, "", 20, Style.GOLD)
	var field := Style.column(self)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label = Style.label(field, "", 18, Style.GOLD)
	message = Style.label(field, "Play cards against the rival. Block protects you during its next turn.", 16, Style.MUTED)
	pile_row = Style.row(field)
	var controls := Style.row(field)
	end_button = Style.button(controls, "End turn →", end_turn)
	var tools := CheckButton.new()
	tools.text = "Pile testing tools"
	controls.add_child(tools)
	tools.toggled.connect(func(enabled: bool): sandbox = enabled; refresh())
	draw_button = Style.button(controls, "Draw 1", draw_one)
	redraw_button = Style.button(controls, "Redraw up to 5", next_hand)
	Style.label(self, "YOUR HAND", 16, Style.GOLD)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	hand_row = Style.row(scroll)
	session.changed.connect(on_session_changed)
	refresh()


func empty(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func refresh() -> void:
	empty(pile_row)
	empty(hand_row)
	enemy_label.text = "RIVAL   /   HP %d / %d   ·   Block %d   ·   Deck %d" % [session.enemy.health, session.enemy.max_health, session.enemy.block, enemy_piles.total_cards()]
	status_label.text = "YOU   /   HP %d / %d   ·   Block %d   ·   Energy %d / 3   ·   Turn %d   ·   Cards %d" % [session.player.health, session.player.max_health, session.player.block, session.energy, session.round_number, player_piles.total_cards()]
	end_button.disabled = not session.outcome.is_empty()
	draw_button.visible = sandbox
	redraw_button.visible = sandbox
	draw_button.disabled = not session.outcome.is_empty()
	redraw_button.disabled = not session.outcome.is_empty()
	for entry in [["Draw", player_piles.draw_pile], ["Discard", player_piles.discard_pile], ["Exhaust", player_piles.exhaust_pile]]:
		var pile_button := Style.button(pile_row, "%s pile\n%d cards\nInspect ↗" % [entry[0], entry[1].size()], inspect_pile.bind(entry[0], entry[1]))
		pile_button.custom_minimum_size = Vector2(180, 100)
		pile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if player_piles.hand.is_empty():
		Style.label(hand_row, "Your hand is empty. End turn to draw again.", 20, Style.MUTED)
	for card in player_piles.hand:
		var panel := Style.panel(hand_row)
		panel.custom_minimum_size.x = 185
		Style.label(panel, "%d  /  ENERGY" % card.get_energy_cost(), 14, Style.GOLD)
		Style.label(panel, card.definition.display_name, 24)
		Style.label(panel, card.definition.description, 16, Style.MUTED)
		var actions := Style.row(panel)
		var entries: Array = [["Play", play_card.bind(card)]]
		if sandbox:
			entries.append(["Exhaust", move_card.bind(card, true)])
		for entry in entries:
			var action := Style.button(actions, entry[0], entry[1])
			action.disabled = not session.can_play(card) if entry[0] == "Play" else not session.outcome.is_empty()
			action.add_theme_font_size_override("font_size", 14)
			var compact := Style.box(Color("203436"))
			compact.content_margin_left = 10
			compact.content_margin_right = 10
			action.add_theme_stylebox_override("normal", compact)


func draw_one() -> void:
	if not sandbox or not session.outcome.is_empty():
		return
	var card := player_piles.draw_card()
	message.text = "Drew %s." % card.definition.display_name if card else "No cards to draw. Exhausted cards stay out of the draw cycle."
	refresh()


func next_hand() -> void:
	if not sandbox or not session.outcome.is_empty():
		return
	player_piles.discard_hand()
	var drawn := player_piles.draw_cards(5)
	message.text = "Drew %d cards. %d exhausted; %d total across all piles." % [drawn.size(), player_piles.exhaust_pile.size(), player_piles.total_cards()]
	refresh()


func move_card(card: CardInstance, exhaust: bool) -> void:
	if not sandbox or not session.outcome.is_empty() or not player_piles.hand.has(card):
		return
	if exhaust:
		player_piles.exhaust_card(card)
	else:
		player_piles.discard_card(card)
	message.text = "%s %s." % [card.definition.display_name, "exhausted" if exhaust else "discarded"]
	refresh()


func play_card(card: CardInstance) -> void:
	session.play_card(card)


func end_turn() -> void:
	session.end_turn()


func on_session_changed() -> void:
	var start := maxi(0, session.history.size() - 3)
	message.text = "  ·  ".join(session.history.slice(start))
	if not session.outcome.is_empty():
		message.text = session.outcome + "! Leave the table to choose another encounter."
	refresh()


func inspect_pile(title: String, cards: Array[CardInstance]) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title + " pile"
	var counts: Dictionary = {}
	for card in cards:
		var name: String = card.definition.display_name
		counts[name] = int(counts.get(name, 0)) + 1
	var lines: PackedStringArray = []
	for name in counts:
		lines.append("%s × %d" % [name, counts[name]])
	dialog.dialog_text = "Empty" if lines.is_empty() else "\n".join(lines)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(360, 200))
