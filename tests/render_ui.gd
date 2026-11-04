extends SceneTree
## Render-only QA. Uses in-memory decks and does not touch saved recipes.

const GameUI = preload("res://scripts/ui/game_ui.gd")


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
	var ui := GameUI.new()
	root.add_child(ui)
	await capture("res://.godot/menu-preview.png")
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
	await capture("res://.godot/rewrite-preview.png")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100, 700)
	await capture("res://.godot/rewrite-small-preview.png")
	quit()
