extends VBoxContainer
## Combat presentation. Session owns energy, effects, turns, and results.

const Style = preload("res://scripts/ui/ui_style.gd")
const Session = preload("res://scripts/combat/combat_session.gd")
const HandCard = preload("res://scripts/ui/hand_card.gd")
const POISON_GREEN = Color("65ef94")
const InfoProgress = preload("res://scripts/ui/info_progress.gd")
const PileToken = preload("res://scripts/ui/pile_token.gd")
const Feedback = preload("res://scripts/ui/combat_feedback.gd")
var player_feedback: Control
var enemy_feedback: Control
var _display_state: Dictionary = {}
var _last_presented_card: CardInstance
var _last_presented_by_player: bool = true
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
var pattern_label: Label
var hand_title: Label
var energy_label: Label
var enemy_energy_label: Label
var turn_label: Label
var relic_label: Label


func setup(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], use_war_drum: bool = false, rival: Resource = null, existing_session: RefCounted = null) -> void:
	add_theme_constant_override("separation", 8)
	session = existing_session if existing_session != null else Session.new(player_cards, enemy_cards, true, use_war_drum, rival)
	player_piles = session.player_piles
	enemy_piles = session.enemy_piles
	var actors := Style.row(self)
	var own_panel := Style.panel(actors)
	var own_heading := Style.row(own_panel)
	status_label = Style.label(own_heading, "", 16, Style.GOLD)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_label = Style.label(own_heading, "", 13, Style.GOLD)
	player_status = Style.label(own_heading, "", 14, Color("b4d77c"))
	player_hp = make_health_bar(own_panel, Color("65b58b"))
	player_block = player_hp.get_node("Block")
	player_feedback = make_feedback_layer(player_hp)
	var enemy_panel := Style.panel(actors)
	var enemy_heading := Style.row(enemy_panel)
	enemy_label = Style.label(enemy_heading, "", 16, Style.GOLD)
	enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_energy_label = Style.label(enemy_heading, "", 13, Style.GOLD)
	enemy_energy_label.tooltip_text = "RIVAL ENERGY\nThe rival has 3 energy each turn. It resolves affordable cards in the revealed order. Draw effects can add follow-up plays."
	enemy_status = Style.label(enemy_heading, "", 14, Color("b4d77c"))
	enemy_hp = make_health_bar(enemy_panel, Color("ce7871"))
	enemy_block = enemy_hp.get_node("Block")
	enemy_feedback = make_feedback_layer(enemy_hp)
	intent_label = Style.label(self, "", 14, Style.GOLD)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_scroll = ScrollContainer.new()
	intent_scroll.custom_minimum_size.y = 46
	intent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(intent_scroll)
	rewrite_row = Style.row(intent_scroll)
	var middle := Style.row(self)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var field := Style.column(middle, true)
	message = Style.label(field, "Block lasts until your next turn.", 14, Style.MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var resources := Style.row(field)
	turn_label = Style.label(resources, "", 13, Style.MUTED)
	artifact_label = Style.label(resources, "", 14, Style.GOLD)
	relic_label = Style.label(resources, "", 13, Style.GOLD)
	pile_row = Style.row(field)
	var controls := Style.row(field)
	end_button = Style.button(controls, "End turn →", end_turn)
	Style.primary(end_button)
	var tools := CheckButton.new()
	tools.text = "Lab"
	tools.custom_minimum_size.x = 90
	tools.tooltip_text = "PILE LAB\nOptional testing controls for free drawing, redrawing, and exhausting. These are outside the normal combat rules."
	Style.quiet(tools)
	controls.add_child(tools)
	tools.toggled.connect(func(enabled: bool): sandbox = enabled; refresh())
	var debug_controls := Style.row(field)
	draw_button = Style.button(debug_controls, "Draw 1", draw_one)
	redraw_button = Style.button(debug_controls, "Redraw up to 5", next_hand)
	draw_button.tooltip_text = "LAB DRAW\nDraw one available card without spending energy. Discard reshuffles when the draw pile is empty. Exhausted cards stay out."
	redraw_button.tooltip_text = "LAB REDRAW\nDiscard your current hand and draw up to five available cards without advancing the turn."
	var log_panel := Style.panel(middle)
	log_panel.get_parent().custom_minimum_size.x = 340
	Style.label(log_panel, "ENCOUNTER RECORD", 13, Style.GOLD).tooltip_text = "ENCOUNTER RECORD\nResolved plays and actual HP, block, draw, Poison, Cadence, and Pattern changes. Scroll upward to review earlier actions."
	combat_log = RichTextLabel.new()
	combat_log.custom_minimum_size = Vector2(290, 100)
	combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log.scroll_following = true
	combat_log.tooltip_text = "ENCOUNTER RECORD\nScroll to review earlier actions. Numbers report actual changes after block, healing limits, and available draws."
	combat_log.bbcode_enabled = true
	combat_log.add_theme_font_size_override("normal_font_size", 14)
	combat_log.add_theme_color_override("default_color", Style.INK)
	log_panel.add_child(combat_log)
	var hand_heading := Style.row(self)
	hand_title = Style.label(hand_heading, "YOUR HAND", 13, Style.GOLD)
	pattern_label = Style.label(hand_heading, "", 13, Style.GOLD)
	pattern_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var guide := Style.button(hand_heading, "Patterns ?", show_pattern_guide)
	guide.name = "PatternGuideButton"
	guide.add_theme_font_size_override("font_size", 12)
	guide.custom_minimum_size.y = 22
	Style.quiet(guide)
	guide.tooltip_text = "PATTERNS\nOpen all three sequence recipes. Complete one Pattern per turn; Rewrite does not interrupt the sequence. Rival playback pauses while the guide is open."
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 226
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
	if existing_session != null and not session.player_turn and not session.last_action.is_empty() and not session.last_action.by_player and not enemy_piles.discard_pile.is_empty():
		var last: CardInstance = enemy_piles.discard_pile.back()
		if last.definition.display_name == session.last_action.card:
			_last_presented_card = last
			_last_presented_by_player = false
	refresh()
	restore_action_message()


func make_feedback_layer(bar: Control) -> Control:
	var layer := Feedback.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(layer)
	return layer


func read_display_state() -> Dictionary:
	return {"player": Vector3i(session.player.health, session.player.block, session.player.poison), "enemy": Vector3i(session.enemy.health, session.enemy.block, session.enemy.poison), "player_turn": session.player_turn, "round": session.round_number}


func feedback_changes(before: Vector3i, after: Vector3i, starts_turn: bool) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if after.x < before.x:
		var poison_tick := starts_turn and before.z > 0
		changes.append({"text": "−%d %s" % [before.x - after.x, "HP · POISON" if poison_tick else "HP"], "color": POISON_GREEN if poison_tick else Color("ef9b87")})
	elif after.x > before.x:
		changes.append({"text": "+%d HP" % (after.x - before.x), "color": Color("9ae2b4")})
	if after.y < before.y:
		changes.append({"text": "%d %s" % [before.y - after.y, "BLOCK EXPIRED" if starts_turn else "BLOCKED"], "color": Style.MUTED if starts_turn else Color("89cfff")})
	elif after.y > before.y:
		changes.append({"text": "+%d BLOCK" % (after.y - before.y), "color": Color("89cfff")})
	if after.z > before.z:
		changes.append({"text": "+%d POISON" % (after.z - before.z), "color": POISON_GREEN})
	return changes


func present_state_changes() -> void:
	if _display_state.is_empty():
		return
	var current := read_display_state()
	var player_starts: bool = int(current.round) > int(_display_state.round)
	var enemy_starts: bool = _display_state.player_turn and not current.player_turn
	var own := feedback_changes(_display_state.player, current.player, player_starts)
	var rival := feedback_changes(_display_state.enemy, current.enemy, enemy_starts)
	player_feedback.present(own)
	enemy_feedback.present(rival)
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	player_hp.modulate = Color.WHITE
	enemy_hp.modulate = Color.WHITE
	_feedback_tween = create_tween().set_parallel(true)
	if not own.is_empty():
		player_hp.modulate = own[0].color.lightened(0.65)
		_feedback_tween.tween_property(player_hp, "modulate", Color.WHITE, 0.25)
	if not rival.is_empty():
		enemy_hp.modulate = rival[0].color.lightened(0.65)
		_feedback_tween.tween_property(enemy_hp, "modulate", Color.WHITE, 0.25)
	if own.is_empty() and rival.is_empty():
		_feedback_tween.kill()


func make_health_bar(parent: Node, color: Color) -> ProgressBar:
	var bar := InfoProgress.new()
	bar.custom_minimum_size.y = 32
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", Style.box(Color("0b1c20")))
	var fill := Style.box(color, color)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var shield := InfoProgress.new()
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
	enemy_label.text = session.rival_definition.display_name.to_upper() if session.rival_definition != null else "RIVAL"
	enemy_label.add_theme_color_override("font_color", session.rival_definition.accent if session.rival_definition != null else Style.GOLD)
	enemy_label.tooltip_text = session.rival_definition.description + "\nPrepared order: " + session.rival_definition.doctrine_text() if session.rival_definition != null else "Custom rival deck"
	status_label.text = "YOU"
	status_label.tooltip_text = "YOU\nYour combatant. Health carries between journey encounters; block, Poison, energy, and encounter bonuses reset for the next duel."
	energy_label.text = "%d / 3 ENERGY" % session.energy if session.player_turn else "WAITING"
	enemy_energy_label.text = "%d / 3 ENERGY" % session.enemy_energy
	enemy_energy_label.visible = not session.player_turn and session.outcome.is_empty()
	energy_label.tooltip_text = "ENERGY\nPay the number on a card to play it. Restore 3 energy at the start of your turn. Surge can grant extra energy. Unspent energy does not carry forward."
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
	refresh_pattern()
	hand_title.text = "YOUR HAND" if session.player_turn else ("LAST RIVAL PLAY" if _last_presented_card != null and not _last_presented_by_player else "YOUR NEXT HAND")
	hand_title.tooltip_text = "YOUR HAND\nClick a card to play it. Tab focuses a card; Enter or Space plays it. Unplayed cards are discarded at the end of your turn." if session.player_turn else "RIVAL PLAYBACK\nThe most recently resolved rival card is displayed here for reference. It cannot be played. Your new hand arrives when the rival finishes."
	turn_label.text = "%s · %02d" % ["YOUR TURN" if session.player_turn else "RIVAL TURN", session.round_number]
	turn_label.add_theme_color_override("font_color", Style.GOLD if session.player_turn else Color("df9e8d"))
	turn_label.tooltip_text = "TURN\nYour turn: spend energy on cards, then end turn. The rival resolves its revealed line, then both hands are prepared again. Poison ticks at the affected side's turn start."
	artifact_label.text = "CADENCE %d/3" % session.cadence
	artifact_label.tooltip_text = "CADENCE & REWRITE\nThe first card each turn or a category change earns 1 Cadence, up to 3. Repeating the previous category earns none. Cadence carries between turns. Spend 2, once per turn, to move a rival card to the back of its hand."
	relic_label.text = "WAR DRUM +%d" % session.war_drum.damage_bonus if session.war_drum != null else "NO ARTIFACT"
	relic_label.tooltip_text = "WAR DRUM\nEach Strike adds +1 to your attack bonus before that Strike resolves. All your damage effects benefit. Resets each encounter; changing a Strike's category preserves its identity." if session.war_drum != null else "ARTIFACT\nNo artifact is equipped for this encounter. You can enable War Drum on the deck preparation screen."
	var log_text := "\n".join(session.history)
	if _last_log_text != log_text:
		_last_log_text = log_text
		var colored: PackedStringArray = []
		for line in session.history:
			var escaped: String = line.replace("[", "[lb]")
			colored.append("[color=#65ef94]%s[/color]" % escaped if line.contains("Poison") else ("[color=#f4cc70]%s[/color]" % escaped if line.begins_with("Pattern ") else escaped))
		combat_log.text = "\n".join(colored)
	end_button.disabled = not session.player_turn and session.outcome.is_empty()
	end_button.text = "Encounter results" if not session.outcome.is_empty() else ("End turn →" if session.player_turn else "Rival is playing…")
	end_button.tooltip_text = "ENCOUNTER RESULTS\nOpen the summary without changing the finished encounter." if not session.outcome.is_empty() else ("END TURN\nDiscard your remaining hand and energy. The rival acts next. Your next turn restores 3 energy and draws up to five cards." if session.player_turn else "RIVAL TURN\nWait for the rival's revealed cards to resolve. Player actions are unavailable until your next turn.")
	draw_button.visible = sandbox
	redraw_button.visible = sandbox
	draw_button.get_parent().visible = sandbox
	draw_button.disabled = not session.player_turn or not session.outcome.is_empty()
	redraw_button.disabled = not session.player_turn or not session.outcome.is_empty()
	for entry in [["Draw", player_piles.draw_pile], ["Discard", player_piles.discard_pile], ["Exhaust", player_piles.exhaust_pile]]:
		var pile := PileToken.new()
		pile.name = String(entry[0]) + "Pile"
		pile_row.add_child(pile)
		pile.setup(entry[0], entry[1].size(), Style.GOLD if entry[0] == "Draw" else (Color("96afbd") if entry[0] == "Discard" else Color("aa8b9f")), inspect_pile.bind(entry[0], entry[1]))
		var rules := "Cards waiting to be drawn. When empty, the discard pile is shuffled into it." if entry[0] == "Draw" else ("Played and unplayed cards arrive here. They can return through a reshuffle." if entry[0] == "Discard" else "Cards removed from the draw cycle for this encounter. They return in a fresh encounter.")
		pile.tooltip_text = "%s PILE · %d cards\n%s\nClick to inspect the contents. Rival playback pauses while the inspector is open." % [String(entry[0]).to_upper(), entry[1].size(), rules]
	if player_piles.hand.is_empty():
		if not session.player_turn and session.outcome.is_empty() and _last_presented_card != null and not _last_presented_by_player:
			var last_view := HandCard.new()
			hand_row.add_child(last_view)
			last_view.name = "LastRivalCard"
			last_view.setup(_last_presented_card, false, func(): pass, Callable(), session.last_action.description, "LAST RIVAL PLAY\n%s\n%s\nThis card has already resolved. Read the remaining line above to see what comes next." % [session.last_action.card, session.last_action.description], "", "Rival played")
		var empty_text := "Encounter complete. Review the log or open Encounter results." if not session.outcome.is_empty() else ("Your hand is empty. End turn to draw again." if session.player_turn else "Rival's turn — your next hand follows.")
		var empty_label := Style.label(hand_row, empty_text, 18, Style.MUTED)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size.x = 400
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for card in player_piles.hand:
		var view := HandCard.new()
		hand_row.add_child(view)
		var exhaust := move_card.bind(card, true) if sandbox and session.player_turn and session.outcome.is_empty() else Callable()
		var text: String = session.describe_card(card)
		var details := forecast_text(card)
		var pattern: Resource = session.preview_pattern(card)
		view.setup(card, session.can_play(card), play_card.bind(card), exhaust, text, details, pattern.display_name if pattern != null else "", card_action_hint(card))
		view.inspected.connect(show_card_forecast.bind(card))
		view.inspection_ended.connect(restore_action_message)
	_display_state = read_display_state()


func forecast_text(card: CardInstance) -> String:
	var text: String = "%s\n%s · %d energy\n%s" % [card.definition.display_name, CardDefinition.Category.keys()[card.get_category()].capitalize(), card.get_energy_cost(), session.describe_card(card)]
	var forecast: Dictionary = session.preview_attack(card)
	if forecast.damage > 0:
		text += "\nAttack forecast: rival loses %d HP; %d damage blocked." % [forecast.hp_loss, forecast.blocked]
		if forecast.lethal:
			text += " Lethal."
	if session.war_drum != null and forecast.damage > 0:
		var drum_bonus: int = session.war_drum.preview_bonus(card)
		if drum_bonus > 0:
			text += "\nWar Drum bonus: +%d." % drum_bonus
	var pattern: Resource = session.preview_pattern(card)
	if pattern != null:
		text += "\nPattern %s: %s" % [pattern.display_name, pattern.payoff]
	if not session.outcome.is_empty():
		text += " Encounter finished."
	elif not session.player_turn:
		text += " Wait for your turn."
	elif card.get_energy_cost() > session.energy:
		text += " Need %d energy; you have %d." % [card.get_energy_cost(), session.energy]
	if session.player_turn and session.outcome.is_empty():
		text += "\nCadence +%d from this category." % session.cadence_gain(card)
	for effect in card.definition.effects:
		if effect is ApplyPoisonEffect:
			text += "\nPoison: at the target's turn start, deal HP damage through block, then remove 1 stack. Applications add stacks."
		elif effect is GainBlockEffect:
			text += "\nBlock: absorbs incoming attacks and expires at the owner's next turn. Poison bypasses it."
		elif effect is DrawEffect:
			text += "\nDraw: takes available cards only. Discard reshuffles when needed; exhausted cards cannot be drawn."
	return text


func card_action_hint(card: CardInstance) -> String:
	if not session.outcome.is_empty():
		return "Encounter finished"
	if not session.player_turn:
		return "Wait for your turn"
	if card.get_energy_cost() > session.energy:
		return "Need %d energy; you have %d" % [card.get_energy_cost(), session.energy]
	return "This card has no playable effects"


func refresh_pattern() -> void:
	pattern_label.tooltip_text = session.pattern_rules()
	if not session.completed_pattern.is_empty():
		pattern_label.text = "PATTERN COMPLETE · " + session.completed_pattern
		return
	if not session.player_turn or not session.outcome.is_empty():
		pattern_label.text = "Patterns reset each player turn"
		return
	var names := CardDefinition.Category.keys()
	var sequence: PackedStringArray = []
	for index in session.pattern_history:
		sequence.append(names[index].capitalize())
	pattern_label.text = "Build a 3-card Pattern" if sequence.is_empty() else " → ".join(sequence) + " → ?"
	if sequence.size() >= 2:
		var history: Array[int] = session.pattern_history
		for pattern in session.PATTERNS:
			if history[-2] == pattern.first and history[-1] == pattern.second:
				pattern_label.text = "%s → %s → %s = %s" % [names[pattern.first].capitalize(), names[pattern.second].capitalize(), names[pattern.third].capitalize(), pattern.display_name]
				break


func show_pattern_guide() -> void:
	var resume_rival := not rival_timer.is_stopped()
	if resume_rival:
		rival_timer.stop()
	var dialog := AcceptDialog.new()
	dialog.name = "PatternGuide"
	dialog.title = "Patterns — rival playback paused" if resume_rival else "Patterns — shape your turn"
	var guide_theme := Style.theme()
	guide_theme.set_stylebox("panel", "AcceptDialog", Style.box(Color("142a2c"), Style.GOLD))
	dialog.theme = guide_theme
	dialog.dialog_text = session.pattern_rules()
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(dialog)
	dialog.confirmed.connect(close_board_dialog.bind(dialog, resume_rival))
	dialog.canceled.connect(close_board_dialog.bind(dialog, resume_rival))
	dialog.popup_centered(Vector2i(760, 320))


func close_board_dialog(dialog: Window, resume_rival: bool) -> void:
	dialog.queue_free()
	if resume_rival and not session.player_turn and session.outcome.is_empty():
		rival_timer.start()


func show_card_forecast(card: CardInstance) -> void:
	if session.player_turn and session.outcome.is_empty():
		message.tooltip_text = forecast_text(card)
		message.text = "%s · %s" % [card.definition.display_name, session.describe_card(card)]
		var forecast: Dictionary = session.preview_attack(card)
		if forecast.damage > 0:
			message.text += " %d HP / %d blocked.%s" % [forecast.hp_loss, forecast.blocked, " Lethal." if forecast.lethal else ""]
		var pattern: Resource = session.preview_pattern(card)
		if pattern != null:
			message.text += " Pattern " + pattern.display_name + "."
		if card.get_energy_cost() > session.energy:
			message.text += " Need %d energy." % card.get_energy_cost()


func restore_action_message() -> void:
	message.tooltip_text = ""
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
	bar.tooltip_text = "BLOCK · %d\nAbsorbs attacks before HP. Expires at the owner's next turn; Poison bypasses it. Full blue width represents %d block. Larger totals remain fully effective." % [actor.block, actor.max_health]
	var hp: ProgressBar = bar.get_parent()
	hp.tooltip_text = "HEALTH · %d / %d\nReach zero HP and this side is defeated. Block absorbs attacks before HP; Poison bypasses block.\nCurrent block: %d." % [actor.health, actor.max_health, actor.block]
	hp.get_node("Overlay/Health").tooltip_text = hp.tooltip_text
	var block_text: Label = hp.get_node("Overlay/BlockText")
	block_text.text = "BLOCK %d" % actor.block
	block_text.tooltip_text = bar.tooltip_text


func update_status(label: Label, actor: Combatant) -> void:
	label.text = "POISON %d" % actor.poison
	label.visible = actor.poison > 0
	label.add_theme_color_override("font_color", POISON_GREEN)
	label.tooltip_text = "POISON · %d stacks\nAt this side's turn start, lose HP equal to Poison through block, then remove 1 stack. Reapplying adds stacks. Lethal Poison prevents card plays." % actor.poison


func refresh_intent() -> void:
	empty(rewrite_row)
	intent_label.visible = true
	intent_scroll.visible = false
	if not session.outcome.is_empty():
		intent_label.text = "Combat finished — " + session.outcome
		return
	if session.player_turn and session.enemy.poison >= session.enemy.health:
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
	var heading := Style.label(rewrite_row, "RIVAL LINE\nREWRITE · 2 CADENCE" if session.player_turn else "RIVAL ACTING\n%d ENERGY LEFT" % session.enemy_energy, 11, Style.GOLD)
	heading.tooltip_text = "Click a card to spend 2 Cadence and move it to the back. Once per turn. Bright cards are currently affordable; dim cards are in reserve."
	if includes_draw:
		heading.tooltip_text += " Draw effects can add follow-up plays from reserve or newly drawn cards."
	for index in range(enemy_piles.hand.size()):
		var card: CardInstance = enemy_piles.hand[index]
		var planned := opening.has(card)
		var next_play: bool = not session.player_turn and not opening.is_empty() and card == opening[0]
		var state := "NEXT" if next_play else ("PLANNED" if planned else "RESERVE")
		var button := Style.button(rewrite_row, "%02d  %s\n%s · %d ENERGY" % [index + 1, card.definition.display_name, state, card.get_energy_cost()], rewrite_card.bind(card))
		button.set_meta("intent_state", state)
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 12)
		var compact := Style.box(Color("dbcfb1") if planned else Color("b1b5a7"), Style.GOLD if planned else Color("66796f"))
		compact.set_corner_radius_all(2)
		if next_play:
			compact.border_color = Color("fff0c4")
			compact.set_border_width_all(2)
		compact.content_margin_left = 8
		compact.content_margin_right = 8
		compact.content_margin_top = 5
		compact.content_margin_bottom = 5
		button.add_theme_stylebox_override("normal", compact)
		button.add_theme_stylebox_override("disabled", compact)
		var hover := compact.duplicate() as StyleBoxFlat
		hover.bg_color = Color("f1e4c6")
		hover.border_color = Color("f4cc70")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", compact)
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			button.add_theme_color_override(color, Color("26352e") if planned else Color("4d5d53"))
		button.disabled = not session.can_rewrite(card)
		var reason := "Click to rewrite this card."
		if not session.player_turn:
			reason = "Wait for your next turn. The rival follows this line; Rewrite is unavailable while it acts."
		elif session.rewrote_this_turn:
			reason = "Already used this turn."
		elif session.cadence < 2:
			reason = "Build more Cadence by changing card categories."
		elif index == enemy_piles.hand.size() - 1:
			reason = "This card is already at the back."
		button.tooltip_text = "%s · %s\n%s\n%s\nRewrite costs 2 Cadence and moves this card to the back of the prepared hand. Once per turn.\n%s" % [card.definition.display_name, state, "%s · %d energy" % [CardDefinition.Category.keys()[card.get_category()].capitalize(), card.get_energy_cost()], session.describe_card(card, false), reason]


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
	_last_presented_card = card
	_last_presented_by_player = by_player
	message.text = "%s played %s." % ["You" if by_player else "Rival", card.definition.display_name]


func on_session_changed() -> void:
	present_state_changes()
	restore_action_message()
	refresh()
	if not session.outcome.is_empty():
		rival_timer.stop()
		if not _result_reported:
			_result_reported = true
			combat_finished.emit(session.combat_summary())


func inspect_pile(title: String, cards: Array[CardInstance]) -> void:
	var resume_rival := not rival_timer.is_stopped()
	if resume_rival:
		rival_timer.stop()
	var dialog := AcceptDialog.new()
	dialog.title = title + " pile" + (" — rival playback paused" if resume_rival else "")
	var counts: Dictionary = {}
	for card in cards:
		var name: String = card.definition.display_name
		counts[name] = int(counts.get(name, 0)) + 1
	var lines: PackedStringArray = []
	for name in counts:
		lines.append("%s × %d" % [name, counts[name]])
	dialog.dialog_text = "Empty" if lines.is_empty() else "\n".join(lines)
	add_child(dialog)
	dialog.confirmed.connect(close_board_dialog.bind(dialog, resume_rival))
	dialog.canceled.connect(close_board_dialog.bind(dialog, resume_rival))
	dialog.popup_centered(Vector2i(360, 200))
