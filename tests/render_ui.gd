extends SceneTree
## Render-only QA. Uses in-memory decks and does not touch saved recipes.

const GameUI = preload("res://scenes/ui/game_ui.tscn")


func _initialize() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100, 700)
	var ui := GameUI.instantiate()
	root.add_child(ui)
	await capture("res://.godot/menu-preview.png")
	ui.show_options()
	await capture("res://.godot/options-preview.png")
	ui.get_node("OptionsMenu").close_requested.emit()
	ui.show_rivals()
	await capture("res://.godot/rivals-preview.png")
	ui.select_rival(0)
	await capture("res://.godot/rival-setup-preview.png")
	ui.library.decks.append(ui.library.counterpoint_recipe())
	ui.player_index = ui.library.decks.size() - 1
	ui.show_setup()
	await capture("res://.godot/counterpoint-setup-preview.png")
	ui.show_table()
	await capture("res://.godot/rival-table-preview.png")
	ui.start_custom_duel()
	ui.library.decks.assign([{"name": "Starter", "cards": {"strike": 5, "block": 5}}])
	ui.player_index = 0
	ui.enemy_index = 0
	ui.show_setup()
	await capture("res://.godot/setup-preview.png")
	ui.show_editor(0, false)
	await capture("res://.godot/editor-preview.png")
	ui.show_table()
	var table = ui.body.get_node("CombatTable")
	table.session.player.gain_block(8)
	table.session.enemy.gain_block(4)
	table.session.enemy.apply_poison(3)
	table.refresh()
	await capture("res://.godot/table-preview.png")
	table.inspect_pile("Draw", table.player_piles.draw_pile)
	await capture("res://.godot/pile-preview.png")
	table.get_node("PileBrowser").get_node("%Close").pressed.emit()
	root.mode = Window.MODE_MAXIMIZED
	await capture("res://.godot/table-maximized-preview.png")
	ui.library.decks.assign([{"name": "Effects demo", "cards": {"strike": 1, "block": 1, "mend": 1, "insight": 1, "siphon": 1, "venom": 1}}])
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	table.player_piles.draw_cards(1)
	table.refresh()
	await capture("res://.godot/effects-cards-preview.png")
	for card in table.player_piles.hand.duplicate():
		if card.definition.id == &"venom":
			table.play_card(card)
			break
	await capture("res://.godot/poison-log-preview.png")
	for card in table.player_piles.hand:
		if card.definition.id == &"strike":
			table.show_card_forecast(card)
			break
	await capture("res://.godot/forecast-preview.png")
	table.session.enemy.take_damage(39)
	table.end_turn()
	await capture("res://.godot/victory-preview.png")
	ui.review_result()
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	table.session.player.take_damage(29)
	table.session.player.apply_poison(5)
	table.end_turn()
	while table.session.outcome.is_empty() and not table.session.player_turn:
		table.advance_rival_presentation()
	await capture("res://.godot/defeat-preview.png")
	ui.review_result()
	ui.library.decks.assign([ui.library.counterpoint_recipe()])
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	var opener: CardInstance = table.player_piles.hand[0]
	var followup: CardInstance = null
	for candidate in table.player_piles.hand:
		if candidate.definition.category != opener.definition.category:
			followup = candidate
			break
	table.play_card(opener)
	table.play_card(followup)
	await capture("res://.godot/cadence-preview.png")
	table.rewrite_card(table.enemy_piles.hand[0])
	await create_timer(0.25).timeout
	await capture("res://.godot/rewrite-flight-preview.png")
	await create_timer(0.53).timeout
	await capture("res://.godot/rewrite-preview.png")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100, 700)
	await capture("res://.godot/rewrite-small-preview.png")
	ui.library.decks.assign([{"name": "Patterns", "cards": {"strike": 2, "block": 2, "mend": 2}}])
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	for category in [CardDefinition.Category.GUARD, CardDefinition.Category.TACTIC]:
		for card in table.player_piles.hand:
			if card.definition.category == category:
				table.play_card(card)
				break
	var finisher: CardInstance = null
	for card in table.player_piles.hand:
		if card.definition.category == CardDefinition.Category.ATTACK:
			finisher = card
			break
	table.show_card_forecast(finisher)
	await capture("res://.godot/pattern-ready-preview.png")
	table.play_card(finisher)
	await capture("res://.godot/pattern-complete-preview.png")
	table.show_pattern_guide()
	await capture("res://.godot/pattern-guide-preview.png")
	ui.show_journey_setup()
	ui.begin_journey()
	await capture("res://.godot/journey-preview.png")
	ui.show_journey_encounter()
	table = ui.body.get_node("CombatTable")
	table.session.player.take_damage(10)
	table.session.enemy.apply_poison(99)
	table.end_turn()
	ui.result_overlay.find_child("Rematch", true, false).pressed.emit()
	await capture("res://.godot/journey-reward-preview.png")
	ui.take_journey_edit(0, (ui.journey.roster[0].get_category() + 1) % 3)
	await capture("res://.godot/journey-edit-preview.png")
	ui.show_journey_encounter()
	table = ui.body.get_node("CombatTable")
	table.player_piles.draw_cards(6)
	table.refresh()
	await capture("res://.godot/revised-cards-preview.png")
	table.session.enemy.apply_poison(99)
	table.end_turn()
	ui.take_journey_recovery()
	ui.show_journey_encounter()
	table = ui.body.get_node("CombatTable")
	table.session.enemy.apply_poison(99)
	table.end_turn()
	ui.result_overlay.find_child("Rematch", true, false).pressed.emit()
	await capture("res://.godot/journey-summary-preview.png")
	ui.end_journey()
	ui.library.decks.assign([ui.library.counterpoint_recipe()])
	ui.player_index = 0
	ui.enemy_index = 0
	ui.start_custom_duel()
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	await capture("res://.godot/board-polish-preview.png")
	var first_view: Control = table.hand_row.get_child(0)
	var play: Button = first_view.find_child("Play", true, false)
	var tooltip: Control = play.call("_make_custom_tooltip", play.tooltip_text)
	root.add_child(tooltip)
	tooltip.position = Vector2(720, 240)
	await capture("res://.godot/board-tooltip-preview.png")
	tooltip.queue_free()
	ui.library.decks.assign([{"name": "Guard", "cards": {"block": 5}}, {"name": "Assault", "cards": {"strike": 5}}])
	ui.player_index = 0
	ui.enemy_index = 1
	ui.show_table()
	table = ui.body.get_node("CombatTable")
	await process_frame
	await process_frame
	table.play_card(table.player_piles.hand[0])
	await capture("res://.godot/block-feedback-preview.png")
	table.end_turn()
	await capture("res://.godot/rival-next-preview.png")
	table.advance_rival_presentation()
	await capture("res://.godot/rival-feedback-preview.png")
	table.rival_timer.stop()
	quit()
