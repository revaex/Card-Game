extends VBoxContainer
## Combat presentation. Session owns energy, effects, turns, and results.

const Style = preload("res://scripts/ui/ui_style.gd")
const Session = preload("res://scripts/combat/combat_session.gd")
const HandCard = preload("res://scenes/ui/card.tscn")
const HandPlayButton = preload("res://scripts/ui/hand_play_button.gd")
const CardBrowser = preload("res://scenes/ui/card_browser.tscn")
const IntentCard = preload("res://scenes/ui/intent_card.tscn")
const FolioReader = preload("res://scenes/ui/folio_reader.tscn")
const Bindings = preload("res://scripts/ui/control_bindings.gd")
const POISON_GREEN = Color("65ef94")
const REWRITE_READY = "✦   REWRITE READY   /   CHOOSE A CARD"
const CATEGORY_COLORS = [Color("efa58e"), Color("96d4f0"), Color("ebc77b")]

const PileToken = preload("res://scripts/ui/pile_token.gd")

var player_feedback: Control
var enemy_feedback: Control
var _display_state: Dictionary = {}
var _last_presented_card: CardInstance
var _last_presented_by_player: bool = true
signal combat_finished(summary: Dictionary)
var _result_reported: bool = false
var _feedback_tween: Tween
var _hand_tween: Tween
var _cadence_tween: Tween
var _pattern_tween: Tween
var _hand_order: Array[CardInstance] = []
var _dragging: CardInstance
var _drag_face: Control
@onready var card_stage = %CardStage
var motion_enabled: bool = true
var _controller_shortcuts: bool = true
var _swap_shoulders: bool = false
var _log_scroll_device := -1
var _controller_hand_focus: bool = false
var _navigation_feedback := false
var _touch_pointer: bool = false
var _selected_card: CardInstance
var _selected_face: Control
var guided: bool = false
@onready var lesson = %DuelLesson
@onready var rewrite_fx = %RewriteFX
@onready var combat_audio = $CombatAudio
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
var _phase_tween: Tween
var _counterwrite_tween: Tween


class MarginBurnDialog extends ConfirmationDialog:
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			set_input_as_handled()
			canceled.emit()


func setup(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], use_war_drum: bool = false, rival: Resource = null, existing_session: RefCounted = null) -> void:
	session = existing_session if existing_session != null else Session.new(player_cards, enemy_cards, true, use_war_drum, rival)
	player_piles = session.player_piles
	enemy_piles = session.enemy_piles
	_bind_scene_nodes()
	get_viewport().size_changed.connect(apply_compact_layout)
	if guided:
		lesson.changed.connect(_on_lesson_changed)
		lesson.reading_requested.connect(show_lesson_folio)
		lesson.start()
		show_lesson_folio.call_deferred()
	card_stage.table = self
	rewrite_fx.landed.connect(combat_audio.rewrite_seal)
	rewrite_fx.finished.connect(show_rewrite_destination)
	rewrite_fx.resized.connect(rewrite_fx.cancel)
	intent_scroll.get_h_scroll_bar().value_changed.connect(func(_offset: float): rewrite_fx.cancel())
	session.changed.connect(on_session_changed)
	session.card_played.connect(on_card_presented)
	if existing_session != null and not session.player_turn and not session.last_action.is_empty() and not session.last_action.by_player and not enemy_piles.discard_pile.is_empty():
		var last: CardInstance = enemy_piles.discard_pile.back()
		if last.definition.display_name == session.last_action.card:
			_last_presented_card = last
			_last_presented_by_player = false
	refresh()
	apply_compact_layout()
	restore_action_message()
	if session.player_turn and session.outcome.is_empty():
		animate_hand_arrival()


func _bind_scene_nodes() -> void:
	status_label = $Actors/PlayerPanel/Content/Heading/ActorName
	energy_label = $Actors/PlayerPanel/Content/Heading/Energy
	player_status = $Actors/PlayerPanel/Content/Heading/Poison
	player_hp = $Actors/PlayerPanel/Content/HealthBar
	player_block = player_hp.get_node("Block")
	player_feedback = player_hp.get_node("Feedback")
	enemy_label = $Actors/EnemyPanel/Content/Heading/ActorName
	enemy_energy_label = $Actors/EnemyPanel/Content/Heading/Energy
	enemy_status = $Actors/EnemyPanel/Content/Heading/Poison
	enemy_hp = $Actors/EnemyPanel/Content/HealthBar
	enemy_block = enemy_hp.get_node("Block")
	enemy_feedback = enemy_hp.get_node("Feedback")
	intent_label = %IntentStatus
	intent_scroll = %IntentScroll
	rewrite_row = %RewriteRow
	message = %ActionMessage
	turn_label = %TurnLabel
	artifact_label = %CadenceLabel
	relic_label = %RelicLabel
	pile_row = %PileRow
	end_button = %EndTurnButton
	draw_button = %DrawButton
	redraw_button = %RedrawButton
	combat_log = %CombatLog
	combat_log.tooltip_text = "Review earlier actions with the mouse wheel or right stick."
	hand_title = %HandTitle
	pattern_label = %PatternLabel
	hand_row = %HandRow
	rival_timer = %RivalTimer
	enemy_energy_label.tooltip_text = "RIVAL ENERGY\nThe rival has 3 energy each turn. It resolves affordable cards in the revealed order. Draw effects can add follow-up plays."


func apply_compact_layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var compact := get_viewport_rect().size.y <= 760
	add_theme_constant_override("separation", 4 if compact else 8)
	$HandScroll.custom_minimum_size.y = 224 if compact else 250
	hand_row.custom_minimum_size.y = 218 if compact else 244
	for face: Control in hand_row.get_children():
		if face.has_method("set_compact"):
			face.set_compact(compact)


func _on_lab_toggled(enabled: bool) -> void:
	sandbox = enabled
	refresh()


func read_display_state() -> Dictionary:
	return {
		"player": Vector3i(session.player.health, session.player.block, session.player.poison),
		"enemy": Vector3i(session.enemy.health, session.enemy.block, session.enemy.poison),
		"player_turn": session.player_turn,
		"round": session.round_number,
		"cadence": session.cadence,
		"pattern_steps": session.pattern_history.size(),
		"patterns": session.statistics.player.patterns,
		"final_phase": session.rival_final_phase,
	}


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
	player_feedback.present(own, motion_enabled)
	enemy_feedback.present(rival, motion_enabled)
	var player_guard: bool = current.player.y > _display_state.player.y or (not player_starts and current.player.y < _display_state.player.y)
	var rival_guard: bool = current.enemy.y > _display_state.enemy.y or (not enemy_starts and current.enemy.y < _display_state.enemy.y)
	if current.player.x < _display_state.player.x or current.enemy.x < _display_state.enemy.x:
		combat_audio.impact(false)
	elif player_guard or rival_guard:
		combat_audio.impact(true)
	if current.patterns > _display_state.patterns:
		combat_audio.pattern()
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	player_hp.modulate = Color.WHITE
	enemy_hp.modulate = Color.WHITE
	if not motion_enabled:
		return
	_feedback_tween = create_tween().set_parallel(true)
	if not own.is_empty():
		player_hp.modulate = own[0].color.lightened(0.65)
		_feedback_tween.tween_property(player_hp, "modulate", Color.WHITE, 0.25)
	if not rival.is_empty():
		enemy_hp.modulate = rival[0].color.lightened(0.65)
		_feedback_tween.tween_property(enemy_hp, "modulate", Color.WHITE, 0.25)
	if own.is_empty() and rival.is_empty():
		_feedback_tween.kill()


func empty(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func refresh() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var previous_card: Control
	if focus_owner != null and hand_row.is_ancestor_of(focus_owner):
		previous_card = focus_owner.get_parent().get_parent() as Control
	var focus_index := previous_card.get_index() if previous_card != null else -1
	var focus_card: Variant = previous_card.get_meta("card", null) if focus_index >= 0 and previous_card.has_meta("card") else null
	cancel_card_selection()
	var previous_lesson_step: int = lesson.step
	lesson.observe(session)
	var lesson_advanced: bool = lesson.active and lesson.step != previous_lesson_step
	if lesson_advanced and motion_enabled:
		%LessonDelay.start()
	lesson.get_node("%Read").disabled = lesson_briefing_pending()
	lesson.get_node("%Continue").disabled = lesson_briefing_pending()
	$Middle/RecordPanel.visible = not lesson.active
	$Middle/Field/Actions/LabToggle.visible = not lesson.active
	if _hand_tween != null:
		_hand_tween.kill()
		_hand_tween = null
	if _counterwrite_tween != null:
		_counterwrite_tween.kill()
		_counterwrite_tween = null
	empty(pile_row)
	empty(hand_row)
	enemy_label.text = session.rival_definition.display_name.to_upper() if session.rival_definition != null else "RIVAL"
	enemy_label.add_theme_color_override("font_color", session.rival_definition.accent if session.rival_definition != null else Style.GOLD)
	enemy_label.tooltip_text = session.rival_definition.description + "\nPrepared order: " + session.rival_definition.doctrine_text(session.rival_final_phase) if session.rival_definition != null else "Custom rival deck"
	status_label.text = "YOU"
	status_label.tooltip_text = "YOU\nYour combatant. Health carries between journey encounters; block, Poison, energy, and encounter bonuses reset for the next duel."
	energy_label.text = ("%d ENERGY" % session.energy if session.energy > 3 else "%d / 3 ENERGY" % session.energy) if session.player_turn else "WAITING"
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
	hand_title.tooltip_text = "YOUR HAND\nUse arrows, D-pad, or left stick to inspect nearby cards. Click a card or focus it and use Confirm to play it." if session.player_turn else "RIVAL PLAYBACK\nThe most recently resolved rival card is displayed here for reference. It cannot be played. Your new hand arrives when the rival finishes."
	update_combat_shortcuts()
	turn_label.text = "%s · %02d" % ["YOUR TURN" if session.player_turn else "RIVAL TURN", session.round_number]
	turn_label.add_theme_color_override("font_color", Style.GOLD if session.player_turn else Color("df9e8d"))
	turn_label.tooltip_text = "TURN\nYour turn: spend energy on cards, then end turn. The rival resolves its revealed line, then both hands are prepared again. Poison ticks at the affected side's turn start."
	artifact_label.text = "CADENCE %d/3" % session.cadence
	artifact_label.tooltip_text = "CADENCE\nThe first card each turn or a category change earns 1 Cadence, up to 3. Cadence carries between turns. Spend 2 to Rewrite a rival card, Brace for Block, or draw a card."
	%CadencePips.text = "◆ ".repeat(session.cadence) + "◇ ".repeat(session.CADENCE_CAP - session.cadence)
	%CadencePips.tooltip_text = artifact_label.tooltip_text
	%Brace.visible = not lesson.active
	%CadenceDraw.visible = not lesson.active
	var brace_ready: bool = session.can_spend_cadence(Session.CadenceAction.BRACE)
	var draw_ready: bool = session.can_spend_cadence(Session.CadenceAction.DRAW)
	for entry in [[%Brace, brace_ready], [%CadenceDraw, draw_ready]]:
		var action: Button = entry[0]
		action.modulate = Color.WHITE if entry[1] else Color(0.67, 0.71, 0.70)
		action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if entry[1] else Control.CURSOR_ARROW
	%Brace.text = "Brace ◆%d" % session.CADENCE_ACTION_COST
	%CadenceDraw.text = "Draw ◆%d" % session.CADENCE_ACTION_COST
	%Brace.tooltip_text = "BRACE\nSpend %d Cadence to gain %d Block." % [session.CADENCE_ACTION_COST, session.BRACE_BLOCK]
	%CadenceDraw.tooltip_text = "DRAW\nSpend %d Cadence to draw 1 card. If both piles are empty, no Cadence is spent." % session.CADENCE_ACTION_COST
	var burn: Button = %MarginBurn
	burn.visible = session.margin_burn_enabled
	burn.disabled = player_piles.hand.is_empty() or not session.can_margin_burn(player_piles.hand.front())
	burn.text = "Burn used" if session.margin_burn_used else "Margin Burn"
	if not brace_ready or not draw_ready:
		var availability := "\nYou have %d Cadence." % session.cadence if session.player_turn else "\nAvailable on your turn."
		if not brace_ready:
			%Brace.tooltip_text += availability
		if not draw_ready:
			%CadenceDraw.tooltip_text += availability
	relic_label.text = "WAR DRUM +%d" % session.war_drum.damage_bonus if session.war_drum != null else (session.equipped_relic.title.to_upper() if session.equipped_relic != null else "NO RELIC")
	relic_label.tooltip_text = "WAR DRUM\nEach Strike adds +1 to your attack bonus before that Strike resolves. All your damage effects benefit. Resets each encounter." if session.war_drum != null else ("%s\n%s" % [session.equipped_relic.title, session.equipped_relic.description] if session.equipped_relic != null else "RELIC\nYou can equip a relic before starting a duel.")
	var log_text := "\n".join(session.history)
	if _last_log_text != log_text:
		_last_log_text = log_text
		var colored: PackedStringArray = []
		for line in session.history:
			var escaped: String = line.replace("[", "[lb]")
			if line.begins_with("Rewrite:") or line.begins_with("Pattern "):
				escaped = "[color=#f4cc70]%s[/color]" % escaped
			elif line.contains("Poison"):
				escaped = "[color=#65ef94]%s[/color]" % escaped
			colored.append(escaped)
		combat_log.text = "\n".join(colored)
	end_button.disabled = (not session.player_turn or not lesson.allows_end_turn() or lesson_briefing_pending()) and session.outcome.is_empty()
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
		pile.tooltip_text = "%s PILE · %d cards\n%s\nSelect to inspect. Rival playback pauses while the inspector is open." % [String(entry[0]).to_upper(), entry[1].size(), rules]
	var piles := link_focus_row(pile_row)
	var actions := link_focus_row(end_button.get_parent())
	if not actions.is_empty():
		for index in range(piles.size()):
			piles[index].focus_neighbor_bottom = piles[index].get_path_to(actions[mini(index, actions.size() - 1)])
		for index in range(actions.size()):
			actions[index].focus_neighbor_top = actions[index].get_path_to(piles[mini(index, piles.size() - 1)])
	if player_piles.hand.is_empty():
		if not session.player_turn and session.outcome.is_empty() and _last_presented_card != null and not _last_presented_by_player:
			var last_view := HandCard.instantiate()
			hand_row.add_child(last_view)
			last_view.name = "LastRivalCard"
			last_view.setup(_last_presented_card, false, func(): pass, Callable(), session.last_action.description, "LAST RIVAL PLAY\n%s\n%s\nThis card has already resolved. Read the remaining line above to see what comes next." % [session.last_action.card, session.last_action.description], "", "Rival played")
		var empty_text := "Encounter complete. Review the log or open Encounter results." if not session.outcome.is_empty() else ("Your hand is empty. End turn to draw again." if session.player_turn else "Rival's turn — your next hand follows.")
		var empty_label := Style.label(hand_row, empty_text, 18, Style.MUTED)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size.x = 400
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for card in _hand_order.duplicate():
		if not player_piles.hand.has(card):
			_hand_order.erase(card)
	for card in player_piles.hand:
		if not _hand_order.has(card):
			_hand_order.append(card)
	for card in _hand_order:
		var view := HandCard.instantiate()
		hand_row.add_child(view)
		var exhaust := move_card.bind(card, true) if sandbox and session.player_turn and session.outcome.is_empty() else Callable()
		var text: String = session.describe_card(card)
		var details := forecast_text(card)
		var pattern: Resource = session.preview_pattern(card)
		view.setup(card, can_play_card(card), activate_hand_card.bind(card, view), exhaust, text, details, pattern.display_name if pattern != null else "", card_action_hint(card), session.rewrote_this_turn)
		view.show_pattern_badge(session.pattern_for_card(card) if can_play_card(card) else null)
		view.enable_hand_drag(self, card, session.player_turn and session.outcome.is_empty() and not lesson.active)
		view.set_meta("card", card)
		view.inspected.connect(show_card_forecast.bind(card))
		view.inspection_ended.connect(restore_action_message)
		view.get_node("%Play").focus_entered.connect(_on_hand_focus)
	if focus_card != null and not lesson.active and session.player_turn:
		var remaining_index := _hand_order.find(focus_card)
		focus_hand(remaining_index if remaining_index >= 0 else focus_index)
	_display_state = read_display_state()
	apply_compact_layout()
	if lesson_advanced and not lesson_briefing_pending():
		show_lesson_folio.call_deferred()


func _on_lesson_changed() -> void:
	if not lesson.active:
		%LessonDelay.stop()
	refresh()
	if lesson.active:
		focus_lesson_action()


func link_focus_row(container: Control) -> Array[Control]:
	var row: Array[Control] = []
	for child in container.get_children():
		if child is BaseButton and child.visible and not child.disabled:
			row.append(child)
	for index in range(row.size()):
		row[index].focus_neighbor_left = row[index].get_path_to(row[maxi(index - 1, 0)])
		row[index].focus_neighbor_right = row[index].get_path_to(row[mini(index + 1, row.size() - 1)])
	return row


func focus_lesson_action() -> void:
	var next: Button = lesson.get_node("%Continue")
	if next.visible:
		next.grab_focus()
	elif not end_button.disabled:
		end_button.grab_focus()
	else:
		for tile: Button in rewrite_row.get_children():
			if not tile.disabled:
				tile.grab_focus()
				return
		focus_hand()


func forecast_text(card: CardInstance) -> String:
	var text: String = "%s\n%s · %d energy\n%s" % [card.definition.display_name, CardDefinition.Category.keys()[card.get_category()].capitalize(), card.get_energy_cost(), session.describe_card(card)]
	return text + "\n" + forecast_details(card)


func forecast_details(card: CardInstance) -> String:
	var lines := PackedStringArray()
	var forecast: Dictionary = session.preview_attack(card)
	if forecast.damage > 0:
		lines.append("Attack forecast: rival loses %d HP; %d damage blocked.%s" % [forecast.hp_loss, forecast.blocked, " Lethal." if forecast.lethal else ""])
	if session.war_drum != null and forecast.damage > 0:
		var drum_bonus: int = session.war_drum.preview_bonus(card)
		if drum_bonus > 0:
			lines.append("War Drum bonus: +%d." % drum_bonus)
	var pattern: Resource = session.pattern_for_card(card)
	if pattern != null:
		lines.append("Pattern %s · %s\n%s" % [pattern.display_name, pattern.sequence_text(), pattern.payoff_text()])
	if not session.outcome.is_empty():
		lines.append("Encounter finished.")
	elif not session.player_turn:
		lines.append("Wait for your turn.")
	elif card.get_energy_cost() > session.energy:
		lines.append("Need %d energy; you have %d." % [card.get_energy_cost(), session.energy])
	elif not lesson.allows_card(card):
		lines.append("This card is locked for the current lesson step.")
	if session.player_turn and session.outcome.is_empty():
		lines.append("Cadence +%d from this category if played." % session.cadence_gain(card))
	for effect in card.definition.effects:
		if effect is ApplyPoisonEffect:
			lines.append("Poison: at the target's turn start, deal HP damage through block, then remove 1 stack. Applications add stacks.")
		elif effect is GainBlockEffect:
			lines.append("Block: absorbs incoming attacks and expires at the owner's next turn. Poison bypasses it.")
		elif effect is DrawEffect:
			lines.append("Draw: takes available cards only. Discard reshuffles when needed; exhausted cards cannot be drawn.")
	return "\n".join(lines)


func inspect_hand_card(card: CardInstance, return_focus: BaseButton) -> void:
	if lesson_briefing_pending() or not player_piles.hand.has(card) or has_node("CardInspection"):
		return
	var dialog := FolioReader.instantiate()
	dialog.name = "CardInspection"
	add_child(dialog)
	dialog.close_requested.connect(func():
		close_board_dialog(dialog, false)
		if is_instance_valid(return_focus) and not return_focus.disabled:
			return_focus.grab_focus())
	dialog.open_card(card, session.describe_card(card), forecast_details(card), motion_enabled)


func card_action_hint(card: CardInstance) -> String:
	if not session.outcome.is_empty():
		return "Encounter finished"
	if not session.player_turn:
		return "Wait for your turn"
	if card.get_energy_cost() > session.energy:
		return "Need %d energy; you have %d" % [card.get_energy_cost(), session.energy]
	if not lesson.allows_card(card):
		return "Follow the lesson"
	return "This card has no playable effects"


func refresh_pattern() -> void:
	pattern_label.tooltip_text = session.pattern_rules()
	var pattern: Resource = session.active_pattern
	var progress: int = session.pattern_history.size()
	var names := CardDefinition.Category.keys()
	for index in range(3):
		var step: Label = %PatternSteps.get_child(index)
		var category: int = pattern.category_at(index) if pattern != null else index
		var filled := index < progress
		var next := pattern != null and index == progress
		step.text = ("✓ " if filled else ("› " if next else "")) + names[category].capitalize()
		if pattern == null:
			step.text += " ↻" if index == 2 else " →"
		step.add_theme_color_override("font_color", CATEGORY_COLORS[category] if filled or next or pattern == null else Style.MUTED)
		step.tooltip_text = pattern_label.tooltip_text
	pattern_label.remove_theme_color_override("font_color")
	if not session.completed_pattern.is_empty():
		pattern_label.text = "PATTERN COMPLETE · " + session.completed_pattern
		pattern_label.add_theme_color_override("font_color", Color("f3cf85"))
		return
	if not session.player_turn or not session.outcome.is_empty():
		pattern_label.text = "Patterns reset each player turn"
		return
	pattern_label.text = "PATTERN CYCLE  /  Pick a starting card" if pattern == null else "%s locked  /  Next: %s" % [pattern.display_name, names[pattern.category_at(progress)].capitalize()]
	if pattern != null:
		if pattern.block_gain > 0:
			pattern_label.text += "  ·  +%d Block" % pattern.block_gain
		elif pattern.finishing_damage > 0:
			pattern_label.text += "  ·  +%d damage/hit" % pattern.finishing_damage
		elif pattern.energy_gain > 0:
			pattern_label.text += "  ·  +%d energy" % pattern.energy_gain


func _on_brace_pressed() -> void:
	if not lesson.active and session.spend_cadence(Session.CadenceAction.BRACE):
		message.text = "Cadence spent · gained %d Block." % session.BRACE_BLOCK


func _on_cadence_draw_pressed() -> void:
	if not lesson.active and session.spend_cadence(Session.CadenceAction.DRAW):
		message.text = "Cadence spent · drew 1 card."
		combat_audio.paper(true)


func show_pattern_guide() -> void:
	if lesson_briefing_pending() or has_node("PatternGuide"):
		return
	var resume_rival := not rival_timer.is_stopped()
	if resume_rival:
		rival_timer.stop()
	var pages: Array[Dictionary] = [{
		"section": "PATTERN FIELD GUIDE",
		"title": "Pattern rewards",
		"body": "",
		"route": "ATTACK → GUARD → TACTIC → ATTACK",
		"plate": 3,
	}]
	var overview := PackedStringArray()
	for pattern in session.PATTERNS:
		overview.append("%s · %s\n%s" % [pattern.display_name, pattern.sequence_text(), pattern.payoff_text()])
		pages.append({
			"section": "PATTERN FIELD GUIDE",
			"title": pattern.display_name,
			"body": "Open with %s to lock this Pattern. %s" % [CardDefinition.Category.keys()[pattern.first].capitalize(), pattern.payoff_text()],
			"route": pattern.sequence_text(),
			"plate": [4, 2, 1][pattern.first],
			"pattern_icon": pattern.first,
		})
	pages[0].body = "\n\n".join(overview)
	var dialog := FolioReader.instantiate()
	dialog.name = "PatternGuide"
	add_child(dialog)
	dialog.close_requested.connect(close_board_dialog.bind(dialog, resume_rival))
	dialog.open(pages, "Return to duel", motion_enabled)
	dialog.get_node("%Hint").text += "\n%s / %s to close" % [Bindings.active_label(&"ui_cancel", 0), Bindings.active_label(&"ui_cancel", 1)]


func show_lesson_folio() -> void:
	if not lesson.active or lesson_briefing_pending() or has_node("LessonFolio"):
		return
	var step: int = lesson.step
	if rewrite_fx.is_active():
		await rewrite_fx.finished
	if not is_inside_tree() or not lesson.active or lesson.step != step or has_node("LessonFolio"):
		return
	var resume_rival := not rival_timer.is_stopped()
	if resume_rival:
		rival_timer.stop()
	var dialog := FolioReader.instantiate()
	dialog.name = "LessonFolio"
	add_child(dialog)
	dialog.close_requested.connect(func():
		close_board_dialog(dialog, resume_rival)
		lesson.reading_closed()
		focus_lesson_action())
	dialog.open(lesson.pages(session), "Back to duel", motion_enabled)


func lesson_briefing_pending() -> bool:
	return not %LessonDelay.is_stopped()


func pause_lesson_delay(paused: bool) -> void:
	%LessonDelay.paused = paused


func _on_lesson_delay_timeout() -> void:
	if lesson.active:
		refresh()
		show_lesson_folio()


func close_board_dialog(dialog: Window, resume_rival: bool) -> void:
	dialog.hide()
	dialog.queue_free()
	if resume_rival and not session.player_turn and session.outcome.is_empty():
		rival_timer.start()


func show_margin_burn() -> void:
	if %MarginBurn.disabled or has_node("MarginBurnDialog"):
		return
	var cards: Array[CardInstance] = player_piles.hand.duplicate()
	var dialog := MarginBurnDialog.new()
	dialog.name = "MarginBurnDialog"
	dialog.title = "Margin Burn"
	dialog.ok_button_text = "Exhaust card"
	dialog.dialog_hide_on_ok = false
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var content := Style.column(dialog)
	Style.label(content, "Choose one card to exhaust for the rest of this duel.", 16)
	var picker := OptionButton.new()
	picker.name = "Sacrifice"
	content.add_child(picker)
	for card in cards:
		var category: String = CardDefinition.Category.keys()[card.get_category()].capitalize()
		picker.add_item("%s · %s" % [card.definition.display_name, category])
	var forecast := RichTextLabel.new()
	forecast.name = "Forecast"
	forecast.custom_minimum_size = Vector2(370, 92)
	forecast.add_theme_font_size_override("normal_font_size", 15)
	forecast.add_theme_color_override("default_color", Style.INK)
	content.add_child(forecast)
	var preview := func(index: int):
		var card := cards[index]
		var result: Dictionary = session.preview_margin_burn(card)
		dialog.get_ok_button().disabled = result.is_empty()
		if result.is_empty():
			forecast.text = "Margin Burn is unavailable."
			return
		var rewrite := "Rewrite available" if result.rewrite_available else "Rewrite unavailable this turn"
		forecast.text = "%s\n0 energy · Cadence %d → %d/%d\n%s" % [session.describe_card(card), session.cadence, result.cadence, session.CADENCE_CAP, rewrite]
	picker.item_selected.connect(preview)
	var cancel := func():
		close_board_dialog(dialog, false)
		if not %MarginBurn.disabled:
			%MarginBurn.grab_focus()
	dialog.canceled.connect(cancel)
	dialog.confirmed.connect(func():
		var card := cards[picker.selected]
		close_board_dialog(dialog, false)
		if session.margin_burn(card):
			message.text = "Exhausted %s · Cadence %d/%d" % [card.definition.display_name, session.cadence, session.CADENCE_CAP]
			focus_hand())
	picker.select(0)
	preview.call(0)
	dialog.popup_centered()
	dialog.get_cancel_button().grab_focus()


func show_card_forecast(card: CardInstance) -> void:
	if session.player_turn and session.outcome.is_empty():
		message.tooltip_text = forecast_text(card)
		var cost := card.get_energy_cost()
		if cost > session.energy:
			message.text = "%s · Need %d energy, have %d" % [card.definition.display_name, cost, session.energy]
			return
		var summary: String = session.describe_card(card)
		var forecast: Dictionary = session.preview_attack(card)
		if forecast.damage > 0:
			summary = "%d HP" % forecast.hp_loss
			if forecast.blocked > 0:
				summary += " / %d blocked" % forecast.blocked
			if forecast.lethal:
				summary += " · Lethal"
		message.text = "%s · %s" % [card.definition.display_name, summary]
		var pattern: Resource = session.pattern_for_card(card)
		if pattern != null:
			message.text += " · Pattern %s%s" % [pattern.display_name, " starts" if session.active_pattern == null else (" completes" if session.pattern_history.size() == 2 else " advances")]


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
	rewrite_fx.cancel()
	empty(rewrite_row)
	var phase: Label = %RivalPhase
	phase.visible = session.rival_definition != null and session.rival_definition.final_phase_health > 0 and session.outcome.is_empty()
	if phase.visible:
		phase.text = "FINAL REVISION · " + session.rival_definition.final_phase_rules() if session.rival_final_phase else "AT %d HP · Next line: %s" % [session.rival_definition.final_phase_health, session.rival_definition.final_phase_rules()]
		if session.rival_phase_pending:
			phase.text = "NEXT LINE · " + session.rival_definition.final_phase_rules()
	intent_label.visible = true
	%IntentBand.hide()
	if not session.outcome.is_empty():
		intent_label.text = "Combat finished — " + session.outcome
		return
	if session.player_turn and session.enemy.poison >= session.enemy.health:
		intent_label.text = "RIVAL NEXT TURN  ·  Lethal Poison — defeated before playing."
		intent_label.tooltip_text = "Poison ticks before cards are played."
		return
	if enemy_piles.hand.is_empty():
		intent_label.text = "RIVAL LINE  ·  No prepared cards"
		return

	intent_label.visible = false
	%IntentBand.show()
	var opening: Array[CardInstance] = session.enemy_opening_plan()
	show_line_threat()
	var ready: bool = enemy_piles.hand.any(func(card: CardInstance): return can_rewrite_card(card))
	var cost: int = session.REWRITE_COST
	var status: Label = %RewriteStatus
	status.add_theme_color_override("font_color", Color("f3cf85") if ready or session.rewrote_this_turn else Style.MUTED)
	if not session.player_turn:
		status.text = "RIVAL ACTING   /   %d ENERGY LEFT" % session.enemy_energy
	elif session.rewrote_this_turn:
		status.text = "LINE REWRITTEN   /   −%d CADENCE" % cost
	elif ready:
		status.text = REWRITE_READY
	else:
		status.text = "REWRITE   /   %d OF %d CADENCE" % [mini(session.cadence, cost), cost]
	status.tooltip_text = "Spend %d Cadence to move a card to the back of the rival's line, once per turn. Planned cards are affordable. Reserve cards may still play if the line changes." % cost

	for index in range(enemy_piles.hand.size()):
		var card: CardInstance = enemy_piles.hand[index]
		var next_play: bool = not session.player_turn and not opening.is_empty() and card == opening[0]
		var state := "NEXT" if next_play else ("PLANNED" if opening.has(card) else "RESERVE")
		var button := IntentCard.instantiate()
		rewrite_row.add_child(button)
		button.show_card(card, index, state, can_rewrite_card(card), lesson.marks_threat(card), session.player_turn and not lesson.active, card == session.anchored_intent)
		button.set_meta("card", card)
		button.pressed.connect(rewrite_card.bind(card))
		button.gui_input.connect(handle_intent_pointer.bind(card, button))
		if not button.disabled:
			button.mouse_entered.connect(show_rewrite_hint.bind(card))
			button.mouse_exited.connect(clear_rewrite_hint.bind(card))
			button.focus_entered.connect(show_rewrite_hint.bind(card))
			button.focus_exited.connect(clear_rewrite_hint.bind(card))
		var reason := "Move this card to the back of the line."
		if not session.player_turn:
			reason = "Rewrite is available on your turn."
		elif session.rewrote_this_turn:
			reason = "Rewrite was already used this turn."
		elif card == session.anchored_intent:
			reason = "Sealed: this card cannot be rewritten. Block its damage or change the rest of the line."
		elif index == enemy_piles.hand.size() - 1:
			reason = "This card is already at the back."
		elif session.cadence < cost:
			reason = "Build Cadence by changing card categories."
		button.tooltip_text = "%s · %s\n%s · %d energy\n%s\n%s" % [card.definition.display_name, state, CardDefinition.Category.keys()[card.get_category()].capitalize(), card.get_energy_cost(), session.describe_card(card, false), reason]
	link_focus_row(rewrite_row)


func show_rewrite_hint(card: CardInstance) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	if can_rewrite_card(card):
		%RewriteStatus.text = "%s   →   BACK OF LINE   /   −%d CADENCE" % [card.definition.display_name.to_upper(), session.REWRITE_COST]
		var preview: Dictionary = session.preview_rewrite(card)
		%ThreatPreview.text = "REWRITE PREVIEW · HP loss %d → %d · Poison added %d → %d%s" % [preview.before.hp_loss, preview.after.hp_loss, preview.before.poison, preview.after.poison, " · Draw follow-ups unknown" if preview.before.draws or preview.after.draws else ""]
		for tile: Control in rewrite_row.get_children():
			var in_plan: bool = preview.plan.has(tile.get_meta("card"))
			tile.preview_plan(in_plan)
			tile.modulate = Color(1.08, 1.05, 0.9) if in_plan else Color(0.67, 0.72, 0.73)
	elif card == session.anchored_intent:
		%ThreatPreview.text = "SEALED · This card resists Rewrite. Block it, or rewrite another card."
	elif session.player_turn:
		message.text = "%s · %s" % [card.definition.display_name, session.describe_card(card, false)]


func clear_rewrite_hint(card: CardInstance) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	if can_rewrite_card(card):
		%RewriteStatus.text = REWRITE_READY
	show_line_threat()
	for tile: Control in rewrite_row.get_children():
		tile.modulate = Color.WHITE
		tile.clear_preview()


func show_line_threat() -> void:
	var threat: Dictionary = session.line_threat(session.enemy_opening_plan())
	%ThreatPreview.text = "VISIBLE LINE · %d HP loss after Block · %d Poison added%s" % [threat.hp_loss, threat.poison, " · Draw follow-ups unknown" if threat.draws else ""]


func handle_intent_pointer(event: InputEvent, card: CardInstance, button: BaseButton) -> void:
	if not event is InputEventMouseButton or lesson.active:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		button.accept_event()
		if event.pressed:
			inspect_intent_card(card, button)
	elif event.button_index == MOUSE_BUTTON_LEFT and event.device == InputEvent.DEVICE_ID_EMULATION:
		# Route the tap itself, so a previous touch or modal never changes Confirm.
		button.accept_event()
		if not event.pressed and Rect2(Vector2.ZERO, button.size).has_point(event.position):
			inspect_intent_card(card, button)


func intent_names(cards: Array[CardInstance]) -> String:
	var names := PackedStringArray()
	for card in cards:
		names.append(card.definition.display_name)
	return ", ".join(names)


func inspect_intent_card(card: CardInstance, return_focus: BaseButton) -> void:
	if lesson.active or lesson_briefing_pending() or not session.player_turn or not enemy_piles.hand.has(card) or has_node("IntentInspection"):
		return
	var dialog := FolioReader.instantiate()
	dialog.name = "IntentInspection"
	add_child(dialog)
	var details := "Planned: this card fits the rival's energy budget." if session.enemy_opening_plan().has(card) else "Reserve: this card does not currently fit the rival's energy budget. Unplayed cards go to discard after this line resolves."
	if can_rewrite_card(card):
		var preview: Dictionary = session.preview_rewrite(card)
		details += "\nRewrite moves it to the back for 2 Cadence.\nVisible HP loss: %d → %d. Poison added: %d → %d." % [preview.before.hp_loss, preview.after.hp_loss, preview.before.poison, preview.after.poison]
		if preview.leaving.is_empty() and preview.entering.is_empty():
			details += "\nThe same cards fit the rival's energy budget."
		else:
			if not preview.leaving.is_empty():
				details += "\nMoves to reserve: " + intent_names(preview.leaving)
			if not preview.entering.is_empty():
				details += "\nEnters the affordable line: " + intent_names(preview.entering)
		if preview.before.draws or preview.after.draws:
			details += "\nDraw follow-ups are unknown."
	elif card == session.anchored_intent:
		details += "\nSEALED: cannot be rewritten. Block its damage or rewrite the rest of the line."
	elif session.rewrote_this_turn:
		details += "\nYou have already used Rewrite this turn."
	elif enemy_piles.hand[-1] == card:
		details += "\nAlready at the back of the line."
	else:
		details += "\nRewrite needs 2 Cadence. Change card categories to build it."
	dialog.close_requested.connect(func():
		close_board_dialog(dialog, false)
		if is_instance_valid(return_focus):
			return_focus.grab_focus())
	dialog.open_card(card, session.describe_card(card, false), details, motion_enabled)
	dialog.get_node("%Heading").text = "Rival intent"
	dialog.get_node("%Next").text = "Return to duel"
	if can_rewrite_card(card):
		var confirm := Button.new()
		confirm.name = "ConfirmRewrite"
		confirm.text = "Rewrite · 2 Cadence"
		confirm.custom_minimum_size.y = 40
		dialog.get_node("%Next").get_parent().add_child(confirm)
		confirm.focus_neighbor_left = confirm.get_path_to(dialog.get_node("%Next"))
		dialog.get_node("%Next").focus_neighbor_right = dialog.get_node("%Next").get_path_to(confirm)
		confirm.pressed.connect(func():
			close_board_dialog(dialog, false)
			rewrite_card(card)
			end_button.grab_focus())


func rewrite_card(card: CardInstance) -> void:
	if not can_rewrite_card(card):
		if session.player_turn and session.outcome.is_empty() and not lesson.active:
			if card == session.anchored_intent:
				message.text = "Sealed · choose another intent."
			elif session.rewrote_this_turn:
				message.text = "Rewrite was already used this turn."
			elif enemy_piles.hand.back() == card:
				message.text = "This intent is already at the back."
			elif session.cadence < session.REWRITE_COST:
				message.text = "Rewrite needs %d Cadence · you have %d." % [session.REWRITE_COST, session.cadence]
			else:
				message.text = "Rewrite is unavailable for this intent."
		return
	var index := enemy_piles.hand.find(card)
	var snapshot: Array[Dictionary] = []
	if motion_enabled:
		snapshot = rewrite_fx.capture(rewrite_row)
	var old_tile := rewrite_row.get_child(index) as Control
	var had_focus := old_tile != null and old_tile.has_focus()
	if not session.rewrite_intent(card):
		return
	message.text = "Rewrite · %s moved to the back of the rival's line." % card.definition.display_name
	if motion_enabled:
		animate_counterwritten_cards()
	if had_focus and not lesson.active:
		end_button.grab_focus()
	if motion_enabled and rewrite_fx.play(snapshot, rewrite_row, index):
		combat_audio.rewrite_lift()
	else:
		combat_audio.rewrite_seal()


func show_rewrite_destination() -> void:
	if rewrite_row.get_child_count() > 0:
		intent_scroll.ensure_control_visible(rewrite_row.get_child(-1))


func animate_counterwritten_cards() -> void:
	if _counterwrite_tween != null:
		_counterwrite_tween.kill()
	_counterwrite_tween = create_tween().set_parallel()
	var count := 0
	for face: Control in hand_row.get_children():
		var card: CardInstance = face.get_meta("card", null)
		if card != null and card.definition.effects.any(func(effect: CardEffect): return effect != null and effect.after_rewrite):
			face.modulate = Color(1.25, 1.12, 0.72)
			_counterwrite_tween.tween_property(face, "modulate", Color.WHITE, 0.45).set_delay(count * 0.05)
			count += 1
	if count == 0:
		_counterwrite_tween.kill()


func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		rewrite_fx.cancel()
		card_stage.settle()
		for tween in [_hand_tween, _feedback_tween, _cadence_tween, _pattern_tween, _phase_tween, _counterwrite_tween]:
			if tween != null:
				tween.kill()
		for card in hand_row.get_children():
			card.modulate = Color.WHITE
		%CadencePips.modulate = Color.WHITE
		%CadencePips.scale = Vector2.ONE
		pattern_label.modulate = Color.WHITE
		%RivalPhase.modulate = Color.WHITE
		for step in %PatternSteps.get_children():
			step.scale = Vector2.ONE
		player_hp.modulate = Color.WHITE
		enemy_hp.modulate = Color.WHITE
		var no_changes: Array[Dictionary] = []
		player_feedback.present(no_changes, false)
		enemy_feedback.present(no_changes, false)


func animate_hand_arrival() -> void:
	combat_audio.paper(true)
	if not motion_enabled or hand_row.get_child_count() == 0:
		return
	if _hand_tween != null:
		_hand_tween.kill()
	_hand_tween = create_tween().set_parallel(true)
	for index in range(hand_row.get_child_count()):
		var card: Control = hand_row.get_child(index)
		card.modulate = Color(0.88, 0.73, 0.55, 0.45)
		_hand_tween.tween_property(card, "modulate", Color.WHITE, 0.21).set_delay(index * 0.035)


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


func can_rewrite_card(card: CardInstance) -> bool:
	return not lesson_briefing_pending() and session.can_rewrite(card) and lesson.allows_rewrite(card)


func can_play_card(card: CardInstance) -> bool:
	return not lesson_briefing_pending() and session.can_play(card) and lesson.allows_card(card)


func play_card(card: CardInstance) -> void:
	if can_play_card(card):
		session.play_card(card)


func activate_hand_card(card: CardInstance, face: Control) -> void:
	if not _touch_pointer:
		play_card(card)
		return
	if not can_play_card(card):
		return
	var same_card := _selected_card == card
	cancel_card_selection()
	if same_card:
		return
	_selected_card = card
	_selected_face = face
	face.set_touch_selected(true)
	show_card_forecast(card)
	card_stage.show_selection(card.definition.display_name)


func has_selected_card() -> bool:
	return _selected_card != null


func confirm_selected_card() -> void:
	var selected := _selected_card
	cancel_card_selection()
	if selected != null and can_play_card(selected):
		play_card(selected)


func cancel_card_selection() -> void:
	if _selected_card == null:
		return
	if is_instance_valid(_selected_face):
		_selected_face.set_touch_selected(false)
	_selected_card = null
	_selected_face = null
	card_stage.show_selection("")


func configure_controller(shortcuts: bool, swap: bool) -> void:
	_controller_shortcuts = shortcuts
	_swap_shoulders = swap
	if not shortcuts:
		_controller_hand_focus = false
	update_combat_shortcuts()


func update_combat_shortcuts() -> void:
	var show_hints: bool = session != null and session.player_turn and session.outcome.is_empty() and not guided
	var hint: Label = %HandShortcut
	hint.visible = show_hints and _controller_shortcuts
	var action := &"menu_next" if _swap_shoulders else &"menu_previous"
	hint.text = "FOCUS  %s / %s" % [Bindings.active_label(action, 0), Bindings.active_label(action, 1)]
	hint.tooltip_text = "Focus your hand\n" + hint.text.trim_prefix("FOCUS  ")
	var rival_hint: Label = %RivalShortcut
	var rival_action := &"menu_previous" if _swap_shoulders else &"menu_next"
	var rival_binding := "%s / %s" % [Bindings.active_label(rival_action, 0), Bindings.active_label(rival_action, 1)]
	rival_hint.visible = hint.visible
	rival_hint.text = "FOCUS LINE  " + rival_binding
	rival_hint.tooltip_text = "Focus the rival's prepared line. With enough Cadence, this previews a Rewrite.\n" + rival_binding
	var inspect: Label = %InspectShortcut
	inspect.visible = show_hints
	var inspect_key := Bindings.active_label(&"combat_inspect", 0)
	inspect.text = "INSPECT  " + inspect_key
	inspect.tooltip_text = "Inspect a focused card: %s / %s, or right-click." % [inspect_key, Bindings.active_label(&"combat_inspect", 1)]
	if inspect.visible:
		hand_title.tooltip_text = "YOUR HAND\nUse arrows, D-pad, or left stick to move focus. Use Confirm to play.\n" + inspect.tooltip_text
	%PatternGuideButton.tooltip_text = "PATTERNS\nView all three recipes. Rival playback pauses while the guide is open.\n%s / %s" % [
		Bindings.active_label(&"combat_guide", 0), Bindings.active_label(&"combat_guide", 1),
	]


func _input(event: InputEvent) -> void:
	_navigation_feedback = (
		event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)
		or event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true)
		or event.is_action_pressed("ui_focus_next", true) or event.is_action_pressed("ui_focus_prev", true)
		or event.is_action_pressed("menu_previous") or event.is_action_pressed("menu_next")
	)
	if event is InputEventMouseButton and event.pressed:
		_controller_hand_focus = false
		_touch_pointer = event.device == InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventKey or event is InputEventJoypadButton:
		_touch_pointer = false


func _process(delta: float) -> void:
	if _log_scroll_device < 0 or combat_log == null or not is_processing_unhandled_input() or not get_window().has_focus() or not combat_log.is_visible_in_tree():
		return
	var axis := Input.get_joy_axis(_log_scroll_device, JOY_AXIS_RIGHT_Y)
	if absf(axis) < 0.25:
		return
	var scrollbar := combat_log.get_v_scroll_bar()
	scrollbar.value += axis * 420.0 * delta


func _on_hand_focus() -> void:
	if _navigation_feedback:
		_navigation_feedback = false
		combat_audio.focus_card()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_log_scroll_device = event.device
		get_viewport().set_input_as_handled()
		return
	if _selected_card != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_card_selection()
		restore_action_message()
		return
	if session != null and session.player_turn and event.is_action_pressed("combat_inspect"):
		get_viewport().set_input_as_handled()
		var focus := get_viewport().gui_get_focus_owner()
		if focus is HandPlayButton and hand_row.is_ancestor_of(focus):
			inspect_hand_card(focus.card, focus)
		elif focus is BaseButton and rewrite_row.is_ancestor_of(focus):
			inspect_intent_card(focus.get_meta("card"), focus)
		else:
			message.text = "Focus a card in your hand or the rival's line to inspect it."
		return
	if session != null and event.is_action_pressed("combat_guide"):
		get_viewport().set_input_as_handled()
		show_pattern_guide()
		return
	if session != null and session.player_turn and session.outcome.is_empty() and event.is_action_pressed("combat_end"):
		get_viewport().set_input_as_handled()
		end_turn()
		return
	if session != null and session.player_turn and session.outcome.is_empty() and get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			focus_hand()
			return
	if not _controller_shortcuts or session == null or not session.player_turn or not session.outcome.is_empty():
		return
	if event.is_action_pressed("menu_previous") or event.is_action_pressed("menu_next"):
		get_viewport().set_input_as_handled()
		_controller_hand_focus = event.is_action_pressed("menu_previous") != _swap_shoulders
		if _controller_hand_focus:
			focus_hand()
		else:
			focus_rival_line()
	elif event.is_action_pressed("combat_pile"):
		get_viewport().set_input_as_handled()
		inspect_pile("Draw", player_piles.draw_pile)


func focus_rival_line() -> void:
	var first_inspectable: Button
	for button: Button in rewrite_row.get_children():
		if button.disabled:
			continue
		if can_rewrite_card(button.get_meta("card")):
			button.grab_focus()
			return
		if first_inspectable == null:
			first_inspectable = button
	if first_inspectable != null:
		first_inspectable.grab_focus()
	else:
		message.text = "No rival card can be rewritten right now."


func focus_hand(start: int = 0) -> void:
	var count := hand_row.get_child_count()
	for offset in range(count):
		var card: Control = hand_row.get_child((mini(start, count - 1) + offset) % count)
		var play := card.get_node_or_null("%Play") as Button
		if play != null and not play.disabled:
			play.grab_focus()
			return
	end_button.grab_focus()


func can_drag_card(card: CardInstance) -> bool:
	return session != null and session.player_turn and session.outcome.is_empty() and player_piles.hand.has(card)


func begin_hand_drag(face: Control, card: CardInstance) -> void:
	cancel_card_selection()
	_dragging = card
	_drag_face = face
	face.modulate.a = 0.35
	card_stage.show_drag(can_play_card(card), true)


func is_hand_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("table") == get_instance_id() and data.get("card") == _dragging and can_drag_card(_dragging)


func reorder_hand(card: CardInstance, before: CardInstance) -> void:
	var destination := _hand_order.find(before)
	var from := _hand_order.find(card)
	if destination < 0 or from < 0 or destination == from:
		return
	_hand_order.remove_at(from)
	_hand_order.insert(destination, card)
	hand_row.move_child(hand_row.get_child(from), destination)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging != null:
		if is_instance_valid(_drag_face):
			_drag_face.modulate = Color.WHITE
		_dragging = null
		_drag_face = null
		card_stage.show_drag(false, false)


func end_turn() -> void:
	if not session.outcome.is_empty():
		combat_finished.emit(session.combat_summary())
		return
	if not lesson.allows_end_turn() or lesson_briefing_pending():
		return
	if session.begin_rival_turn() and session.outcome.is_empty():
		rival_timer.start()


func advance_rival_presentation() -> void:
	session.advance_rival_turn()
	if session.player_turn or not session.outcome.is_empty():
		rival_timer.stop()


func on_card_presented(card: CardInstance, by_player: bool) -> void:
	combat_audio.paper()
	var row := hand_row if by_player else rewrite_row
	var origin: Vector2 = card_stage.get_global_transform_with_canvas() * (card_stage.size * 0.5)
	var has_origin := false
	for node: Control in row.get_children():
		if node.get_meta("card", null) == card:
			origin = node.get_global_transform_with_canvas() * (node.size * 0.5)
			has_origin = true
			break
	if card == _dragging:
		origin = get_viewport().get_mouse_position()
	card_stage.present(card, by_player, origin, motion_enabled and has_origin, session.last_action.get("description", ""))
	_last_presented_card = card
	_last_presented_by_player = by_player
	message.text = "%s played %s." % ["You" if by_player else "Rival", card.definition.display_name]


func on_session_changed() -> void:
	var phase_started: bool = session.rival_final_phase and not _display_state.get("final_phase", false)
	var new_hand: bool = session.player_turn and session.outcome.is_empty() and session.round_number > _display_state.get("round", 0)
	var previous_cadence: int = _display_state.get("cadence", 0)
	var cadence_changed: bool = session.cadence != previous_cadence
	var completed_pattern: bool = session.statistics.player.patterns > _display_state.get("patterns", 0)
	var advanced_pattern: bool = session.player_turn and session.pattern_history.size() > _display_state.get("pattern_steps", 0)
	present_state_changes()
	restore_action_message()
	refresh()
	if phase_started:
		message.text = "Final Revision — " + session.rival_definition.final_phase_name
		combat_audio.rewrite_seal()
		if motion_enabled:
			if _phase_tween != null:
				_phase_tween.kill()
			%RivalPhase.modulate = Color(1.8, 1.3, 0.8)
			_phase_tween = create_tween()
			_phase_tween.tween_property(%RivalPhase, "modulate", Color.WHITE, 0.7)
	if _controller_hand_focus and is_inside_tree() and not lesson.active and session.player_turn and session.outcome.is_empty() and get_viewport().gui_get_focus_owner() == null:
		focus_hand()
	if new_hand:
		animate_hand_arrival()
	if cadence_changed and motion_enabled:
		var pips: Label = %CadencePips
		if _cadence_tween != null:
			_cadence_tween.kill()
		pips.modulate = Color(1.4, 1.22, 0.9)
		_cadence_tween = create_tween().set_parallel()
		_cadence_tween.tween_property(pips, "modulate", Color.WHITE, 0.30)
		pips.pivot_offset = pips.size * 0.5
		pips.scale = Vector2.ONE * (1.22 if session.cadence > previous_cadence else 0.78)
		_cadence_tween.tween_property(pips, "scale", Vector2.ONE, 0.33).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if advanced_pattern and motion_enabled:
		if _pattern_tween != null:
			_pattern_tween.kill()
		_pattern_tween = create_tween().set_parallel()
		for index in range(3):
			var step: Label = %PatternSteps.get_child(index)
			step.scale = Vector2.ONE
			if completed_pattern or index == session.pattern_history.size() - 1:
				step.pivot_offset = step.size * 0.5
				step.scale = Vector2.ONE * (1.20 if completed_pattern else 1.13)
				_pattern_tween.tween_property(step, "scale", Vector2.ONE, 0.30).set_delay(index * 0.045 if completed_pattern else 0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pattern_label.modulate = Color(1.4, 1.23, 0.9) if completed_pattern else Color.WHITE
		_pattern_tween.tween_property(pattern_label, "modulate", Color.WHITE, 0.50)
	if not session.outcome.is_empty():
		rival_timer.stop()
		if not _result_reported:
			_result_reported = true
			combat_finished.emit(session.combat_summary())


func inspect_pile(title: String, cards: Array[CardInstance]) -> void:
	if lesson_briefing_pending():
		return
	var resume_rival := not rival_timer.is_stopped()
	if resume_rival:
		rival_timer.stop()
	var dialog := CardBrowser.instantiate()
	dialog.name = "PileBrowser"
	add_child(dialog)
	dialog.close_requested.connect(close_board_dialog.bind(dialog, resume_rival))
	var note := "Draw order is hidden." if title == "Draw" else ("Returns after a reshuffle." if title == "Discard" else "Out of play for this encounter.")
	if resume_rival:
		note += " Rival playback paused."
	dialog.show_cards(title + " pile", cards, note)
