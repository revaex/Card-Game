extends VBoxContainer
## Combat presentation. Session owns energy, effects, turns, and results.

const Style = preload("res://scripts/ui/ui_style.gd")
const Session = preload("res://scripts/combat/combat_session.gd")
const HandCard = preload("res://scripts/ui/hand_card.gd")
const POISON_GREEN = Color("65ef94")
signal combat_finished(summary: Dictionary)
var _result_reported: bool = false
var _feedback_tween: Tween
var rival_timer: Timer
var _last_log_text: String = ""
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
var player_hp: ProgressBar
var enemy_hp: ProgressBar
var combat_log: RichTextLabel
var artifact_label: Label
var intent_label: Label
var player_block: ProgressBar
var enemy_block: ProgressBar
var player_status: Label
var enemy_status: Label
var rewrite_row: HBoxContainer
var intent_scroll: ScrollContainer


func setup(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], use_war_drum: bool = false) -> void:
	add_theme_constant_override("separation", 8)
	session = Session.new(player_cards, enemy_cards, true, use_war_drum)
	player_piles = session.player_piles
	enemy_piles = session.enemy_piles
	var actors := Style.row(self)
	var own_panel := Style.panel(actors)
	var own_heading := Style.row(own_panel)
	status_label = Style.label(own_heading, "", 16, Style.GOLD)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_status = Style.label(own_heading, "", 14, Color("b4d77c"))
	player_hp = make_health_bar(own_panel, Color("65b58b"))
	player_block = player_hp.get_node("Block")
	var enemy_panel := Style.panel(actors)
	var enemy_heading := Style.row(enemy_panel)
	enemy_label = Style.label(enemy_heading, "", 16, Style.GOLD)
	enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_status = Style.label(enemy_heading, "", 14, Color("b4d77c"))
	enemy_hp = make_health_bar(enemy_panel, Color("ce7871"))
	enemy_block = enemy_hp.get_node("Block")
	intent_label = Style.label(self, "", 14, Style.GOLD)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_scroll = ScrollContainer.new()
	intent_scroll.custom_minimum_size.y = 38
	intent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(intent_scroll)
	rewrite_row = Style.row(intent_scroll)
	var middle := Style.row(self)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var field := Style.column(middle, true)
	message = Style.label(field, "Block lasts until your next turn.", 14, Style.MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	artifact_label = Style.label(field, "", 14, Style.GOLD)
	pile_row = Style.row(field)
	var controls := Style.row(field)
	end_button = Style.button(controls, "End turn →", end_turn)
	var tools := CheckButton.new()
	tools.text = "Testing tools"
	controls.add_child(tools)
	tools.toggled.connect(func(enabled: bool): sandbox = enabled; refresh())
	var debug_controls := Style.row(field)
	draw_button = Style.button(debug_controls, "Draw 1", draw_one)
	redraw_button = Style.button(debug_controls, "Redraw up to 5", next_hand)
	var log_panel := Style.panel(middle)
	log_panel.get_parent().custom_minimum_size.x = 340
	Style.label(log_panel, "COMBAT LOG", 14, Style.GOLD)
	combat_log = RichTextLabel.new()
	combat_log.custom_minimum_size = Vector2(290, 100)
	combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log.scroll_following = true
	combat_log.bbcode_enabled = true
	combat_log.add_theme_font_size_override("normal_font_size", 14)
	combat_log.add_theme_color_override("default_color", Style.INK)
	log_panel.add_child(combat_log)
	Style.label(self, "YOUR HAND", 14, Style.GOLD)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 242
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	hand_row = Style.row(scroll)
	rival_timer = Timer.new()
	rival_timer.wait_time = 0.65
	rival_timer.timeout.connect(advance_rival_presentation)
	add_child(rival_timer)
	session.changed.connect(on_session_changed)
	session.card_played.connect(on_card_presented)
	refresh()


func make_health_bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 32
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", Style.box(Color("0b1c20")))
	var fill := Style.box(color, color)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var shield := ProgressBar.new()
	shield.name = "Block"
	shield.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shield.offset_bottom = 8
	shield.show_percentage = false
	shield.mouse_filter = Control.MOUSE_FILTER_PASS
	shield.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color("64bdff")
	shield_fill.set_corner_radius_all(3)
	shield.add_theme_stylebox_override("fill", shield_fill)
	bar.add_child(shield)
	var overlay := HBoxContainer.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 10
	overlay.offset_right = -5
	overlay.offset_top = 8
	overlay.offset_bottom = -3
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(overlay)
	var hp_text := Style.label(overlay, "", 14, Color("f1f6ee"))
	hp_text.add_theme_color_override("font_outline_color", Color("091b20"))
	hp_text.add_theme_constant_override("outline_size", 4)
	hp_text.name = "Health"
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var block_text := Style.label(overlay, "", 14, Color("d4edff"))
	block_text.name = "BlockText"
	block_text.add_theme_color_override("font_outline_color", Color("102c42"))
	block_text.add_theme_constant_override("outline_size", 4)
	block_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return bar


func empty(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func refresh() -> void:
	empty(pile_row)
	empty(hand_row)
	enemy_label.text = "RIVAL"
	status_label.text = "YOU  ·  Energy %d / 3" % session.energy
	player_hp.max_value = session.player.max_health
	player_hp.value = session.player.health
	enemy_hp.max_value = session.enemy.max_health
	enemy_hp.value = session.enemy.health
	player_hp.get_node("Overlay/Health").text = "%d / %d HP" % [session.player.health, session.player.max_health]
	enemy_hp.get_node("Overlay/Health").text = "%d / %d HP" % [session.enemy.health, session.enemy.max_health]
	update_block_bar(player_block, session.player)
	update_block_bar(enemy_block, session.enemy)
	update_status(player_status, session.player)
	update_status(enemy_status, session.enemy)
	refresh_intent()
	artifact_label.text = "Turn %d  ·  CADENCE %d/3  ·  %s" % [session.round_number, session.cadence, "War Drum +%d" % session.war_drum.damage_bonus if session.war_drum != null else "No artifact"]
	artifact_label.tooltip_text = "First card each turn or a change of category earns 1 Cadence (maximum 3). Repeating a category earns none. Cadence carries between turns. Spend 2 once per turn to move a rival card to the back of its prepared hand."
	var log_text := "\n".join(session.history)
	if _last_log_text != log_text:
		_last_log_text = log_text
		var colored: PackedStringArray = []
		for line in session.history:
			var escaped: String = line.replace("[", "[lb]")
			colored.append("[color=#65ef94]%s[/color]" % escaped if line.contains("Poison") else escaped)
		combat_log.text = "\n".join(colored)
	end_button.disabled = not session.player_turn and session.outcome.is_empty()
	end_button.text = "Encounter results" if not session.outcome.is_empty() else ("End turn →" if session.player_turn else "Rival is playing…")
	draw_button.visible = sandbox
	redraw_button.visible = sandbox
	draw_button.get_parent().visible = sandbox
	draw_button.disabled = not session.player_turn or not session.outcome.is_empty()
	redraw_button.disabled = not session.player_turn or not session.outcome.is_empty()
	for entry in [["Draw", player_piles.draw_pile], ["Discard", player_piles.discard_pile], ["Exhaust", player_piles.exhaust_pile]]:
		var pile_button := Style.button(pile_row, "%s · %d\nInspect ↗" % [entry[0], entry[1].size()], inspect_pile.bind(entry[0], entry[1]))
		pile_button.custom_minimum_size = Vector2(100, 48)
		pile_button.add_theme_font_size_override("font_size", 14)
		pile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if player_piles.hand.is_empty():
		var empty_text := "Encounter complete. Review the log or open Encounter results." if not session.outcome.is_empty() else ("Your hand is empty. End turn to draw again." if session.player_turn else "Rival's turn — your next hand follows.")
		var empty_label := Style.label(hand_row, empty_text, 18, Style.MUTED)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size.x = 400
	for card in player_piles.hand:
		var view := HandCard.new()
		hand_row.add_child(view)
		var exhaust := move_card.bind(card, true) if sandbox and session.player_turn and session.outcome.is_empty() else Callable()
		var text: String = session.describe_card(card)
		var details := forecast_text(card)
		view.setup(card, session.can_play(card), play_card.bind(card), exhaust, text, details)
		view.inspected.connect(show_card_forecast.bind(card))
		view.inspection_ended.connect(restore_action_message)


func forecast_text(card: CardInstance) -> String:
	var text: String = session.describe_card(card)
	var forecast: Dictionary = session.preview_attack(card)
	if forecast.damage > 0:
		text += " Rival loses %d HP; %d damage blocked." % [forecast.hp_loss, forecast.blocked]
		if forecast.lethal:
			text += " Lethal."
	if session.war_drum != null and forecast.bonus > 0:
		text += " War Drum bonus: +%d." % forecast.bonus
	if not session.outcome.is_empty():
		text += " Encounter finished."
	elif not session.player_turn:
		text += " Wait for your turn."
	elif card.get_energy_cost() > session.energy:
		text += " Need %d energy; you have %d." % [card.get_energy_cost(), session.energy]
	if session.player_turn and session.outcome.is_empty():
		text += " Cadence +%d." % session.cadence_gain(card)
	return text


func show_card_forecast(card: CardInstance) -> void:
	if session.player_turn and session.outcome.is_empty():
		message.text = forecast_text(card)


func restore_action_message() -> void:
	if not session.outcome.is_empty():
		message.text = session.outcome + " — encounter complete."
	elif not session.last_action.is_empty():
		var action: Dictionary = session.last_action
		message.text = "%sLast: %s played %s. %s" % ["Your turn. " if session.player_turn else "", "You" if action.by_player else "Rival", action.card, action.description]
	else:
		message.text = "Your turn — hover a card to preview its effects."


func update_block_bar(bar: ProgressBar, actor: Combatant) -> void:
	# Same units as the HP bar; excess block remains effective beyond a full bar.
	bar.max_value = actor.max_health
	bar.value = mini(actor.block, actor.max_health)
	bar.visible = actor.block > 0
	bar.tooltip_text = "%d block. Absorbs damage; expires at the owner's next turn. Full width = %d block." % [actor.block, actor.max_health]
	bar.get_parent().tooltip_text = bar.tooltip_text
	bar.get_parent().get_node("Overlay/BlockText").text = "BLOCK %d" % actor.block


func update_status(label: Label, actor: Combatant) -> void:
	label.text = "POISON %d" % actor.poison
	label.visible = actor.poison > 0
	label.add_theme_color_override("font_color", POISON_GREEN)
	label.tooltip_text = "At this side's turn start: lose HP equal to Poison, bypassing block; then remove 1 stack. Reapplying Poison adds stacks."


func refresh_intent() -> void:
	empty(rewrite_row)
	intent_label.visible = true
	intent_scroll.visible = false
	if not session.outcome.is_empty():
		intent_label.text = "Combat finished — " + session.outcome
		return
	if not session.player_turn:
		intent_label.text = "RIVAL TURN  ·  %d energy remaining" % session.enemy_energy
		return
	if session.enemy.poison >= session.enemy.health:
		intent_label.text = "RIVAL NEXT TURN  ·  Lethal Poison — defeated before playing."
		intent_label.tooltip_text = "Poison ticks before cards are played."
		return
	var entries: PackedStringArray = []
	var includes_draw := false
	for card in session.enemy_opening_plan():
		entries.append("%s (%d)" % [card.definition.display_name, card.get_energy_cost()])
		for effect in card.definition.effects:
			if effect is DrawEffect:
				includes_draw = true
	intent_label.text = "RIVAL NEXT TURN  ·  " + ("Pass — no affordable cards" if entries.is_empty() else " → ".join(entries))
	if includes_draw:
		intent_label.text += "  ·  Drawn cards may add follow-up plays."
	intent_label.tooltip_text = "Prepared cards in play order; numbers are energy costs. Block can reduce their damage."
	intent_label.visible = false
	intent_scroll.visible = true
	var opening: Array[CardInstance] = session.enemy_opening_plan()
	var heading := Style.label(rewrite_row, "RIVAL LINE →", 14, Style.GOLD)
	heading.tooltip_text = "Click a card to spend 2 Cadence and move it to the back. Once per turn. Bright cards are currently affordable; dim cards are in reserve."
	if includes_draw:
		heading.tooltip_text += " Draw effects can add follow-up plays from reserve or newly drawn cards."
	for index in range(enemy_piles.hand.size()):
		var card: CardInstance = enemy_piles.hand[index]
		var planned := opening.has(card)
		var button := Style.button(rewrite_row, "%d · %s (%d) ↷" % [index + 1, card.definition.display_name, card.get_energy_cost()], rewrite_card.bind(card))
		button.custom_minimum_size.y = 30
		button.add_theme_font_size_override("font_size", 13)
		var compact := Style.box(Color("203436"))
		compact.content_margin_left = 8
		compact.content_margin_right = 8
		compact.content_margin_top = 5
		compact.content_margin_bottom = 5
		button.add_theme_stylebox_override("normal", compact)
		button.add_theme_color_override("font_disabled_color", Style.GOLD if planned else Style.MUTED)
		button.add_theme_color_override("font_color", Style.GOLD if planned else Style.MUTED)
		button.disabled = not session.can_rewrite(card)
		var reason := "Click to rewrite this card."
		if session.rewrote_this_turn:
			reason = "Already used this turn."
		elif session.cadence < 2:
			reason = "Build more Cadence by changing card categories."
		elif index == enemy_piles.hand.size() - 1:
			reason = "This card is already at the back."
		button.tooltip_text = "%s\n%s\nRewrite: spend 2 Cadence to move this card to the back. %s" % ["Planned" if planned else "Reserve", session.describe_card(card, false), reason]


func rewrite_card(card: CardInstance) -> void:
	session.rewrite_intent(card)


func draw_one() -> void:
	if not sandbox or not session.player_turn or not session.outcome.is_empty():
		return
	var card := player_piles.draw_card()
	message.text = "Drew %s." % card.definition.display_name if card else "No cards to draw. Exhausted cards stay out of the draw cycle."
	refresh()


func next_hand() -> void:
	if not sandbox or not session.player_turn or not session.outcome.is_empty():
		return
	player_piles.discard_hand()
	var drawn := player_piles.draw_cards(5)
	message.text = "Drew %d cards. %d exhausted; %d total across all piles." % [drawn.size(), player_piles.exhaust_pile.size(), player_piles.total_cards()]
	refresh()


func move_card(card: CardInstance, exhaust: bool) -> void:
	if not sandbox or not session.player_turn or not session.outcome.is_empty() or not player_piles.hand.has(card):
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
	if not session.outcome.is_empty():
		combat_finished.emit(session.combat_summary())
		return
	if session.begin_rival_turn() and session.outcome.is_empty():
		rival_timer.start()


func advance_rival_presentation() -> void:
	session.advance_rival_turn()
	if session.player_turn or not session.outcome.is_empty():
		rival_timer.stop()


func on_card_presented(card: CardInstance, by_player: bool) -> void:
	message.text = "%s played %s." % ["You" if by_player else "Rival", card.definition.display_name]
	# Presentation-only pulse; health and block have already resolved in the model.
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	player_hp.modulate = Color.WHITE
	enemy_hp.modulate = Color.WHITE
	var bar := enemy_hp if by_player else player_hp
	bar.modulate = Color("ffe0b6")
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(bar, "modulate", Color.WHITE, 0.3)


func on_session_changed() -> void:
	restore_action_message()
	refresh()
	if not session.outcome.is_empty():
		rival_timer.stop()
		if not _result_reported:
			_result_reported = true
			combat_finished.emit(session.combat_summary())


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
