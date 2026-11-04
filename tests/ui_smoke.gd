extends SceneTree

const GameUI = preload("res://scenes/ui/game_ui.tscn")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, text: String) -> void:
	if not condition:
		failed = true
		push_error(text)


func run() -> void:
	var ui := GameUI.instantiate()
	root.add_child(ui)
	ui.library.save_path = "res://.godot/ui-test-decks.json"
	ui.library.decks.assign([{"name": "Test", "cards": {"strike": 5, "block": 5}}])
	check(ui.screen == "menu", "Main menu opens")
	ui.show_library(false)
	ui.show_editor(0, false)
	ui.change_count(0, "strike", 1, false)
	check(ui.library.total(ui.library.decks[0]) == 11, "Editor adds cards")
	ui.library.load_decks()
	check(ui.library.total(ui.library.decks[0]) == 11, "Deck survives save/reload")
	ui.change_count(0, "strike", -1, false)
	ui.show_setup()
	check(ui.valid_selection() and ui.player_index == 0 and ui.enemy_index == 0, "First usable deck is selected for both sides")
	ui.player_index = 0
	ui.enemy_index = 0
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
	check(is_equal_approx(tooltip.get_theme_stylebox("panel").bg_color.a, 1.0), "Custom card tooltip background is fully opaque")
	tooltip.free()
	check(is_equal_approx(ui.theme.get_stylebox("panel", "TooltipPanel").bg_color.a, 1.0), "Fallback tooltip theme is also opaque")
	check(table.energy_label.tooltip_text.contains("Surge") and table.energy_label.mouse_filter != Control.MOUSE_FILTER_IGNORE, "Energy help is hoverable")
	check(table.relic_label.tooltip_text.contains("WAR DRUM") and table.turn_label.tooltip_text.contains("TURN"), "Artifact and turn information have help")
	check(table.player_hp.get_node("Overlay/BlockText").tooltip_text.contains("Poison"), "Block text explains damage absorption and Poison")
	check(table.pile_row.get_node("DrawPile").tooltip_text.contains("shuffled"), "Draw pile stack explains recycling")
	check(table.session.energy == 2 and table.player_piles.discard_pile.has(played_card), "UI play resolves effect and spends energy")
	check(table.player_hp.value == table.session.player.health and table.enemy_hp.value == table.session.enemy.health, "HP bars match combat state")
	check(table.combat_log.text.contains("played"), "Combat log displays resolved actions")
	check(table.player_block.value == mini(table.session.player.block, table.session.player.max_health), "Player block bar matches combat state")
	check(table.enemy_block.value == mini(table.session.enemy.block, table.session.enemy.max_health), "Rival block bar matches combat state")
	check(table.intent_label.text.contains("RIVAL NEXT TURN"), "Rival intent appears during player turn")
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
	table.inspect_pile("Draw", table.player_piles.draw_pile)
	table.end_turn()
	check(not table.session.player_turn and table.end_button.disabled, "UI locks player input during paced rival turn")
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
	check(is_equal_approx(finale.rival_timer.wait_time, 0.2), "Fast-turn choice applies to new encounters")
	finale.session.enemy.take_damage(39)
	finale.session.enemy.apply_poison(3)
	finale.end_turn()
	check(ui.screen == "result" and is_instance_valid(ui.result_overlay), "Poison victory opens the result panel")
	check(finale.rival_timer.is_stopped(), "Lethal turn-start Poison does not start a presentation timer")
	ui.result_overlay.find_child("Review", true, false).pressed.emit()
	check(ui.screen == "table" and not is_instance_valid(ui.result_overlay), "Review closes the panel and preserves the finished table")
	check(finale.session.outcome == "Victory", "Review does not restart combat")
	finale.end_button.pressed.emit()
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
	check(first_view.find_child("Description", true, false).text == "Deal 11 damage.", "Hand card displays effective attack including pending artifact trigger")
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
	check(attacks.hand_row.get_child(0).find_child("Description", true, false).text == "Deal 12 damage.", "Card text refreshes after artifact activation")
	attacks.session.enemy.take_damage(28)
	attacks.hand_row.get_child(0).find_child("Play", true, false).pressed.emit()
	check(ui.screen == "result" and attacks.session.outcome == "Victory", "Lethal player card also opens encounter results")
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
	var rewrite_target: CardInstance = rhythm.enemy_piles.hand[0]
	var rewrite_button: Button = rhythm.rewrite_row.get_child(1)
	check(not rewrite_button.disabled, "Rival-line button unlocks when Cadence is available")
	rewrite_button.pressed.emit()
	check(rhythm.enemy_piles.hand[-1] == rewrite_target and rhythm.session.cadence == 0, "Rival-line button executes Rewrite")
	check(rhythm.combat_log.text.contains("Rewrite:"), "Rewrite appears in combat log")
	ui.library.decks.assign([{"name": "Patterns", "cards": {"strike": 2, "block": 2, "mend": 2}}])
	ui.show_table()
	var patterns = ui.body.get_node("CombatTable")
	for category in [CardDefinition.Category.GUARD, CardDefinition.Category.TACTIC]:
		for candidate in patterns.player_piles.hand:
			if candidate.definition.category == category:
				patterns.play_card(candidate)
				break
	check(patterns.pattern_label.text.contains("Riposte"), "Pattern tracker names the available finisher")
	for index in range(patterns.player_piles.hand.size()):
		var finisher: CardInstance = patterns.player_piles.hand[index]
		if finisher.definition.category == CardDefinition.Category.ATTACK:
			var view = patterns.hand_row.get_child(index)
			check(view.find_child("Description", true, false).text == "Deal 17 damage.", "Pattern-ready card shows its full effective damage")
			view.inspected.emit()
			check(patterns.message.text.contains("Pattern Riposte") and view.tooltip_text.contains("War Drum bonus: +1"), "Forecast distinguishes Pattern and artifact bonuses")
			view.find_child("Play", true, false).pressed.emit()
			break
	check(patterns.pattern_label.text.contains("PATTERN COMPLETE") and patterns.combat_log.text.contains("Pattern Riposte"), "Completed Pattern appears in tracker and log")
	patterns.find_child("PatternGuideButton", true, false).pressed.emit()
	var guide: AcceptDialog = patterns.get_node("PatternGuide")
	check(guide.dialog_text.contains("Shelter") and guide.dialog_text.contains("Surge"), "In-game guide explains all Pattern recipes")
	guide.confirmed.emit()
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
	ui.start_custom_duel()
	check(ui.selected_rival == null and ui.valid_selection(), "Custom duel restores editable deck-versus-deck setup")
	ui.show_journey_setup()
	ui.begin_journey()
	check(ui.screen == "journey" and ui.journey != null, "Journey preparation opens the route overview")
	ui.show_journey_encounter()
	var journey_table = ui.body.get_node("CombatTable")
	var retained: RefCounted = journey_table.session
	retained.player.gain_block(100)
	journey_table.end_turn()
	ui.show_journey_overview()
	ui.show_menu()
	ui.show_journey_overview()
	ui.show_journey_encounter()
	journey_table = ui.body.get_node("CombatTable")
	check(journey_table.session == retained and not journey_table.rival_timer.is_stopped(), "Paused rival turn resumes the same encounter and restarts presentation")
	while retained.outcome.is_empty() and not retained.player_turn:
		journey_table.rival_timer.timeout.emit()
	retained.enemy.apply_poison(99)
	journey_table.end_turn()
	check(ui.screen == "result", "Journey duel shows encounter results")
	ui.result_overlay.find_child("Rematch", true, false).pressed.emit()
	check(ui.screen == "journey_reward", "Journey result offers reward instead of rematch")
	ui.take_journey_edit(0, (ui.journey.roster[0].get_category() + 1) % 3)
	check(ui.screen == "journey" and ui.journey.stage == 1, "UI card edit advances the journey")
	ui.show_journey_encounter()
	check(ui.body.get_node("CombatTable").session.enemy.max_health == 46, "UI advances to Warden after reward")
	ui.end_journey()
	check(ui.screen == "menu" and ui.journey == null, "Ending a journey clears run state")
	ui.show_library(false)
	ui.show_menu()
	ui.queue_free()
	await process_frame
	print("UI flow checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
