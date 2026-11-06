extends SceneTree

const GameUI = preload("res://scenes/ui/game_ui.tscn")
var failed := false
var fixture := "res://.godot/journey-checkpoint-%d" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)


func boot() -> Control:
	var ui := GameUI.instantiate()
	ui.journey_checkpoint.path = fixture + ".run"
	ui.relics.save_path = fixture + ".relics"
	ui.library.save_path = fixture + ".decks"
	ui.options_path = fixture + ".options"
	root.add_child(ui)
	ui.combat_motion = false
	ui.combat_sound = false
	return ui


func win_chapter(ui) -> void:
	ui.show_journey_encounter()
	var table: Control = ui.body.get_node("CombatTable")
	table.session.enemy.apply_poison(99)
	table.end_turn()


func run() -> void:
	var ui = boot()
	ui.show_journey_setup()
	ui.begin_journey()
	check(ui.journey_checkpoint.has_run, "Starting a Journey writes a checkpoint")
	ui.show_journey_encounter()
	ui.journey.active_session.player.take_damage(7)
	ui.free()

	ui = boot()
	check(ui.journey != null and ui.journey.stage == 0 and ui.journey.health == 30 and ui.journey.active_session == null, "A relaunch during battle returns to chapter entry")
	win_chapter(ui)
	check(ui.relics.marks == 20, "Winning awards Marks after the chapter checkpoint")
	ui.free()

	ui = boot()
	ui.main_menu.get_node("%JourneyButton").pressed.emit()
	check(ui.screen == "journey_reward" and ui.relics.marks == 20, "Relaunch restores the pending reward without paying Marks twice")
	var category: int = (ui.journey.roster[0].get_category() + 1) % 3
	ui.take_journey_edit(0, category)
	ui.free()

	ui = boot()
	check(ui.journey.stage == 1 and ui.journey.roster[0].get_category() == category and ui.journey.edits.size() == 1, "The next chapter restores the revised deck")
	ui.relics.save_path = fixture + "-missing/profile"
	win_chapter(ui)
	check(ui.relics.marks == 20, "A failed profile write leaves the previous balance in memory")
	ui.free()

	ui = boot()
	check(ui.journey.stage == 1 and ui.relics.marks == 40, "Relaunch reconciles a saved victory whose Marks write failed")
	ui.show_journey_reward()
	var reward: Control = ui.body.get_node("JourneyReward")
	var original_recipe: Dictionary = ui.library.decks[0].duplicate(true)
	var roster_size: int = ui.journey.roster.size()
	reward.get_node("%RemovalToggle").button_pressed = true
	check(reward.get_node("%Removal").visible and not reward.get_node("%Draft").visible, "The reward screen opens the card removal gallery")
	var cut: Button = reward.get_node("%Cuts").get_child(0).get_node("%Draft")
	cut.grab_focus()
	check(reward.get_node("%DeckProfile").text.contains("%d cards" % (roster_size - 1)), "Focusing a cut previews the resulting deck")
	cut.pressed.emit()
	check(ui.journey.stage == 2 and ui.journey.roster.size() == roster_size - 1 and ui.library.decks[0] == original_recipe, "A cut consumes one reward and leaves the saved recipe intact")
	ui.free()

	ui = boot()
	check(ui.journey.roster.size() == roster_size - 1 and ui.journey.edits.back().begins_with("Removed"), "The card cut survives relaunch")
	win_chapter(ui)
	ui.free()

	ui = boot()
	ui.main_menu.get_node("%JourneyButton").pressed.emit()
	check(ui.screen == "journey_summary" and ui.journey.totals().wins == 3 and ui.relics.marks == 95, "A completed run restores its recap and pays the final bonus once")
	ui.end_journey()
	ui.free()

	ui = boot()
	check(ui.journey == null and not ui.journey_checkpoint.has_run and ui.relics.marks == 95, "An ended Journey stays ended on relaunch")
	ui.show_journey_setup()
	ui.begin_journey()
	ui.show_journey_encounter()
	var table: Control = ui.body.get_node("CombatTable")
	table.session.player.apply_poison(99)
	table.end_turn()
	for index in range(12):
		if not table.session.outcome.is_empty():
			break
		table.advance_rival_presentation()
	ui.free()

	ui = boot()
	ui.main_menu.get_node("%JourneyButton").pressed.emit()
	check(ui.screen == "journey_summary" and ui.journey.health == 0 and ui.relics.marks == 95, "A lost Journey restores the defeat recap without awarding Marks")
	ui.free()

	var incompatible := var_to_bytes({"version": 999, "run": {}})
	var file := FileAccess.open(fixture + ".run", FileAccess.WRITE)
	file.store_buffer(incompatible)
	file.close()
	ui = boot()
	check(ui.journey == null and not ui.journey_checkpoint.error_message.is_empty(), "An unsupported checkpoint produces a warning")
	ui.show_journey_setup()
	ui.begin_journey()
	check(FileAccess.get_file_as_bytes(fixture + ".run") == incompatible, "An unsupported checkpoint is preserved")
	ui.free()
	await process_frame
	print("Journey checkpoints: ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
