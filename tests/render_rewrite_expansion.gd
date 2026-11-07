extends SceneTree
## Run without --headless to capture the added board states at 1100 × 700.
const UI = preload("res://scenes/ui/game_ui.tscn")
const Session = preload("res://scripts/combat/combat_session.gd")
const Scribe = preload("res://data/rivals/scribe.tres")
const Library = preload("res://scripts/content/deck_library.gd")


func _initialize() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")


func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100, 700)
	var ui := UI.instantiate()
	var suffix := str(Time.get_ticks_usec())
	ui.options_path = "res://.godot/render-rewrite-options-" + suffix + ".cfg"
	ui.journey_checkpoint.path = "res://.godot/render-rewrite-journey-" + suffix + ".checkpoint"
	ui.relics.save_path = "res://.godot/render-rewrite-relics-" + suffix + ".cfg"
	root.add_child(ui)
	ui.combat_sound = false
	ui.combat_motion = false
	var library := Library.new()
	var deck := library.instantiate_deck(library.counterwritten_recipe())
	deck.reverse()
	var session := Session.new(deck, Scribe.create_deck(), false, false, Scribe)
	ui.mount_table(deck, Scribe.create_deck(), "Counterwritten", "The Scribe", Scribe, session)
	var table = ui.body.get_node("CombatTable")
	session.cadence = 2
	table.refresh()
	await capture("rewrite-opening")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	root.push_input(pad, true)
	table.get_node("%Brace").grab_focus()
	await capture("controller-tooltip")
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = true
	root.push_input(key, true)
	for face: Control in table.hand_row.get_children():
		assert(face.get_global_rect().end.y <= root.size.y, "Whole hand must fit the 700px window")
	var intent: CardInstance = session.enemy_piles.hand[0]
	table.show_rewrite_hint(intent)
	await capture("rewrite-forecast")
	table.inspect_intent_card(intent, table.rewrite_row.get_child(0))
	await capture("rewrite-inspection")
	table.get_node("IntentInspection").close_requested.emit()
	await process_frame
	table.rewrite_card(intent)
	await capture("rewrite-counterwritten")
	session.enemy.take_damage(16)
	session.check_outcome()
	session.player.gain_block(100)
	session.end_turn()
	session.cadence = 2
	table.refresh()
	await capture("rewrite-final-phase")
	root.size = Vector2i(1280, 800)
	await capture("rewrite-final-phase-wide")
	root.size = Vector2i(1100, 700)
	await process_frame
	await process_frame
	session.enemy.take_damage(999)
	session.check_outcome()
	ui.show_result(session.combat_summary())
	await capture("rewrite-results")
	ui.queue_free()
	await process_frame
	quit()
