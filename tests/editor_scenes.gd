extends SceneTree
## Verify saved scene ownership and navigation after moving layout out of code.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func run() -> void:
	var menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	var actions := {"JourneyButton": "journey_requested", "SingleDuelButton": "single_duel_requested", "CustomDuelButton": "custom_duel_requested", "DecksButton": "decks_requested", "QuitButton": "quit_requested"}
	for button_name in actions:
		var button: Button = menu.find_child(button_name, true, false)
		check(button != null and button.owner == menu, "%s is editor-owned before entering the tree" % button_name)
	root.add_child(menu)
	for button_name in actions:
		var button: Button = menu.find_child(button_name, true, false)
		var fired: Array[bool] = []
		menu.connect(actions[button_name], func(): fired.append(true))
		button.pressed.emit()
		check(fired.size() == 1, "%s has a working saved signal connection" % button_name)
		for state in ["normal", "hover", "pressed"]:
			check(is_equal_approx(button.get_theme_stylebox(state).bg_color.a, 1.0), "%s has an opaque %s style" % [button_name, state])
	menu.set_has_journey(true)
	check(menu.get_node("%JourneyButton").text.contains("Continue"), "Menu reflects a continuing journey")
	menu.free()
	var board = preload("res://scenes/ui/combat_table.tscn").instantiate()
	for path in ["Actors/PlayerPanel", "Actors/EnemyPanel", "Middle/RecordPanel/Content/CombatLog", "HandScroll/HandRow", "RivalTimer"]:
		check(board.has_node(path) and board.get_node(path).owner == board, "%s exists in the saved board without setup" % path)
	var player_bar: ProgressBar = board.get_node("Actors/PlayerPanel/Content/HealthBar")
	var enemy_bar: ProgressBar = board.get_node("Actors/EnemyPanel/Content/HealthBar")
	check(player_bar.get_theme_stylebox("fill").bg_color != enemy_bar.get_theme_stylebox("fill").bg_color, "Enemy scene instance retains its health colour override")
	root.add_child(board)
	var cards: Array[CardInstance] = []
	for index in range(10):
		cards.append(CardInstance.new(StarterDeck.STRIKE))
	board.setup(cards, cards)
	var lab: CheckButton = board.get_node("Middle/Field/Actions/LabToggle")
	lab.button_pressed = true
	check(board.sandbox and board.draw_button.get_parent().visible, "Saved Lab signal reveals testing controls")
	lab.button_pressed = false
	check(not board.sandbox and not board.draw_button.get_parent().visible, "Saved Lab signal hides testing controls")
	board.end_button.pressed.emit()
	check(not board.session.player_turn, "Saved End Turn connection advances combat")
	board.free()
	var ui = preload("res://scenes/ui/game_ui.tscn").instantiate()
	root.add_child(ui)
	for step in [{"button": "SingleDuelButton", "screen": "rivals"}, {"button": "CustomDuelButton", "screen": "setup"}, {"button": "DecksButton", "screen": "library"}]:
		ui.main_menu.find_child(step.button, true, false).pressed.emit()
		check(ui.screen == step.screen and not ui.main_menu.visible, "Main menu navigates to %s" % step.screen)
		ui.show_menu()
		check(ui.main_menu.visible and not ui.body.visible, "Returning to menu restores the authored scene")
	ui.free()
	var main = preload("res://scenes/main.tscn").instantiate()
	check(main.has_node("GameUI") and main.get_node("GameUI").scene_file_path.ends_with("game_ui.tscn"), "Entry scene contains the UI instance before runtime")
	main.free()
	print("Editor scene checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
