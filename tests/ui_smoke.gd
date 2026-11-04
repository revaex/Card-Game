extends SceneTree

const GameUI = preload("res://scripts/ui/game_ui.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, text: String) -> void:
	if not condition:
		failed = true
		push_error(text)


func run() -> void:
	var ui := GameUI.new()
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
	check(not ui.valid_selection(), "Confirm requires both decks")
	ui.player_index = 0
	ui.enemy_index = 0
	ui.show_table()
	var table = ui.body.get_child(ui.body.get_child_count() - 2)
	check(table.player_piles.hand.size() == 5, "Player draws opening hand")
	check(table.enemy_piles.draw_pile.size() == 10, "Enemy deck waits for enemy turn")
	check(table.player_piles.hand[0] != table.enemy_piles.draw_pile[0], "Same recipe creates independent sides")
	var played_card = table.player_piles.hand[0]
	table.play_card(played_card)
	check(table.session.energy == 2 and table.player_piles.discard_pile.has(played_card), "UI play resolves effect and spends energy")
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
	ui.show_setup()
	ui.confirm_remove(0, true)
	for child in ui.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
	check(ui.library.decks.is_empty(), "Remove deck updates library")
	check(not ui.valid_selection(), "Removal clears selections")
	ui.show_library(false)
	ui.show_menu()
	ui.queue_free()
	await process_frame
	print("UI flow checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
