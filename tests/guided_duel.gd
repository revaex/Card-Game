extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func play_named(table: Control, id: StringName) -> void:
	for face: Control in table.hand_row.get_children():
		var card: CardInstance = face.get_meta("card")
		if card.definition.id == id:
			var button: Button = face.get_node("%Play")
			check(not button.disabled, "The lesson enables %s" % id)
			button.pressed.emit()
			return
	check(false, "Missing lesson card: %s" % id)


func finish_folio(table: Control) -> void:
	await process_frame
	var folio := table.get_node_or_null("LessonFolio")
	check(folio != null, "The next lesson opens its illustrated folio")
	if folio != null:
		while folio.page_index < folio.pages.size() - 1:
			folio.get_node("%Next").pressed.emit()
		folio.get_node("%Next").pressed.emit()
	await process_frame


func run() -> void:
	var ui := preload("res://scenes/ui/game_ui.tscn").instantiate()
	ui.journey_checkpoint.path = "res://.godot/guided_duel-journey-%d.checkpoint" % Time.get_ticks_usec()
	ui.options_path = "res://.godot/guided-duel-test.cfg"
	root.add_child(ui)
	ui.combat_sound = false
	ui.combat_motion = false
	ui.main_menu.find_child("LessonButton", true, false).pressed.emit()
	var table: Control = ui.body.get_node("CombatTable")
	var lesson = table.lesson
	var original_decks: Array = ui.library.decks.duplicate(true)
	check(lesson.visible and table.end_button.disabled, "First prompt asks the player to read before acting")
	check(table.session.enemy_opening_plan()[0].definition.id == &"strike", "The visible opening plan starts with Strike")
	table.end_turn()
	check(table.session.player_turn, "End turn shortcuts cannot skip a required step")
	await process_frame
	var opening: Window = table.get_node("LessonFolio")
	check(opening.get_node("%PageNumber").text == "PAGE 01 / 02", "The opening briefing displays its page count")
	opening.get_node("%Next").pressed.emit()
	check(opening.get_node("%Heading").text == "What Cadence buys" and opening.get_node("%Body").get_parsed_text().contains("Brace"), "Cadence teaching covers its current uses")
	opening.get_node("%Previous").pressed.emit()
	check(opening.get_node("%PageNumber").text == "PAGE 01 / 02", "The lesson can revisit an earlier page")
	await finish_folio(table)
	table.play_card(table.player_piles.hand[1])
	check(table.session.energy == 3, "Out-of-sequence cards cannot be played through another input path")
	table.set_motion_enabled(true)
	play_named(table, &"strike")
	await process_frame
	check(table.get_node_or_null("LessonFolio") == null and table.lesson_briefing_pending(), "The board stays visible after playing a tutorial card")
	check(table.card_stage.get_node("%CardMotion").get_child_count() == 1, "The card presentation starts before the next folio")
	await create_timer(1.35).timeout
	await finish_folio(table)
	table.set_motion_enabled(false)
	play_named(table, &"block")
	await finish_folio(table)
	check(table.session.cadence == 2 and lesson.get_node("%Heading").text.contains("Rewrite"), "Changing categories makes Rewrite the next step")
	check(table.session.line_threat(table.session.enemy_opening_plan()).hp_loss == 12, "Both Strikes would pierce the player's 8 Block")
	check(table.rewrite_row.get_child(1).disabled, "The lesson highlights and enables only the threatening intent")
	var opening_strike: CardInstance = table.enemy_piles.hand.front()
	table._touch_pointer = true
	table.rewrite_row.get_child(0).pressed.emit()
	table._touch_pointer = false
	await finish_folio(table)
	check(table.session.cadence == 0 and table.enemy_piles.hand.back() == opening_strike, "Rewrite spends Cadence and moves the highlighted copy to the back")
	check(not table.session.enemy_opening_plan().has(opening_strike) and table.session.line_threat(table.session.enemy_opening_plan()).hp_loss == 2, "The remaining Strike still threatens 2 HP before Shelter")
	var hand_size: int = table.player_piles.hand.size()
	play_named(table, &"insight")
	await finish_folio(table)
	check(table.session.completed_pattern == "Shelter" and not table.end_button.disabled, "The correct sequence completes Shelter and unlocks End turn")
	check(table.player_piles.hand.size() == hand_size + 1 and table.session.line_threat(table.session.enemy_opening_plan()).hp_loss == 0, "Insight draws two cards and Shelter covers the remaining damage")
	table.end_button.pressed.emit()
	for index in range(8):
		if table.session.player_turn:
			break
		table.advance_rival_presentation()
	check(table.session.round_number == 2 and table.session.player.health == 30 and table.session.statistics.player.absorbed == 10, "Shelter absorbs the attack during playback")
	check(lesson.get_node("%Heading").text == "Lesson complete", "Lesson confirms the result")
	await finish_folio(table)
	lesson.get_node("%Continue").pressed.emit()
	check(ui.screen == "setup" and ui.preparing_journey and ui.library.decks == original_decks, "Lesson leads into journey setup without changing the saved decks")
	ui.show_lesson()
	table = ui.body.get_node("CombatTable")
	table.lesson.get_node("%Skip").pressed.emit()
	check(ui.screen == "menu", "Leaving the tutorial returns to the main menu")
	ui.show_lesson()
	ui.show_options()
	ui.get_node("OptionsMenu").get_node("%MainMenu").pressed.emit()
	check(ui.screen == "menu" and not ui.body.has_node("CombatTable"), "Options can leave a match for the main menu")
	ui.free()
	await process_frame
	print("Guided duel: ", "PASSED" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
