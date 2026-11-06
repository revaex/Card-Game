extends SceneTree

const Table = preload("res://scenes/ui/combat_table.tscn")
const Style = preload("res://scripts/ui/ui_style.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func copies(definition: CardDefinition) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index in range(5):
		cards.append(CardInstance.new(definition))
	return cards


func board(own: CardDefinition, rival: CardDefinition) -> Control:
	var view := Table.instantiate()
	view.theme = Style.theme()
	root.add_child(view)
	view.combat_audio.set_enabled(false)
	view.setup(copies(own), copies(rival))
	return view


func texts(layer: Control) -> PackedStringArray:
	var result: PackedStringArray = []
	for badge in layer.get_children():
		result.append(badge.get_child(0).text)
	return result


func run() -> void:
	var view = board(StarterDeck.BLOCK, StarterDeck.STRIKE)
	view.play_card(view.player_piles.hand[0])
	check(texts(view.player_feedback).has("+8 BLOCK"), "Block gain displays on the source combatant")
	check(texts(view.enemy_feedback).is_empty(), "Support cards do not flash the opposing combatant")
	view.end_turn()
	check(view.intent_scroll.is_visible_in_tree() and view.rewrite_row.get_child_count() == 5, "Rival line stays visible during execution")
	check(view.rewrite_row.get_child(0).get_meta("intent_state") == "NEXT", "Next affordable rival card is marked")
	check(view.rewrite_row.get_child(3).get_meta("intent_state") == "RESERVE", "Cards outside the energy budget are explicitly marked reserve")
	check(view.energy_label.text == "WAITING" and view.enemy_energy_label.visible, "Energy display identifies the acting side")
	view.advance_rival_presentation()
	check(texts(view.player_feedback).has("−2 HP") and texts(view.player_feedback).has("8 BLOCKED"), "Partially blocked attack shows separate actual HP loss and absorption")
	check(view.player_hp.value == 28 and view.enemy_energy_label.text == "2 / 3 ENERGY", "Bars and rival energy update after one play")
	check(view.hand_row.has_node("LastRivalCard"), "Last rival card occupies the empty hand area")
	check(view.hand_title.text == "LAST RIVAL PLAY", "Hand area clearly identifies the rival's reference card")
	var last: Control = view.hand_row.get_node("LastRivalCard")
	check(last.find_child("Play", true, false).disabled and last.tooltip_text.contains("already resolved"), "Last rival card is informational and cannot be played")
	check(view.rewrite_row.get_child(0).get_meta("intent_state") == "NEXT", "Next marker advances after a resolved card")
	view.show_pattern_guide()
	check(view.rival_timer.is_stopped(), "Reading the Pattern guide pauses rival presentation")
	view.get_node("PatternGuide").close_requested.emit()
	check(not view.rival_timer.is_stopped(), "Closing the guide resumes rival presentation")
	var retained: RefCounted = view.session
	view.queue_free()
	await process_frame
	view = Table.instantiate()
	root.add_child(view)
	view.combat_audio.set_enabled(false)
	var empty_cards: Array[CardInstance] = []
	view.setup(empty_cards, empty_cards, false, null, retained)
	check(view.hand_row.has_node("LastRivalCard"), "Resuming a rival turn restores the last played card")
	while not retained.player_turn and retained.outcome.is_empty():
		view.advance_rival_presentation()
	check(not view.hand_row.has_node("LastRivalCard") and view.hand_row.get_child_count() == 5, "New player hand replaces the presentation card")
	check(not view.enemy_energy_label.visible and view.energy_label.text == "3 / 3 ENERGY", "Energy display returns to the player")
	view.queue_free()
	view = board(StarterDeck.BLOCK, StarterDeck.BLOCK)
	view.play_card(view.player_piles.hand[0])
	view.end_turn()
	while not view.session.player_turn:
		view.advance_rival_presentation()
	check(texts(view.player_feedback).has("8 BLOCK EXPIRED") and not texts(view.player_feedback).has("8 BLOCKED"), "Turn-start expiry is not presented as blocked damage")
	view.session.player.apply_poison(3)
	view.refresh()
	view.end_turn()
	while not view.session.player_turn:
		view.advance_rival_presentation()
	check(texts(view.player_feedback).has("−3 HP · POISON"), "Poison HP loss is identified at the affected turn start")
	var feedback_layer: Control = view.player_feedback
	view.queue_free()
	await process_frame
	check(not is_instance_valid(feedback_layer), "Leaving the table frees feedback and its animation owners")
	view = board(load("res://data/cards/mend.tres"), StarterDeck.BLOCK)
	view.session.player.take_damage(6)
	view.refresh()
	view.play_card(view.player_piles.hand[0])
	check(texts(view.player_feedback).has("+6 HP"), "Healing shows the actual recovered amount")
	view.play_card(view.player_piles.hand[0])
	check(texts(view.player_feedback).is_empty(), "Full-health healing creates no misleading gain feedback")
	view.queue_free()
	view = board(load("res://data/cards/venom.tres"), StarterDeck.BLOCK)
	view.play_card(view.player_piles.hand[0])
	check(texts(view.enemy_feedback).has("+3 POISON"), "Poison application is shown on the target")
	view.queue_free()
	await process_frame
	print("Board feedback checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
