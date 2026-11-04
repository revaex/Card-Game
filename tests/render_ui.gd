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
	await capture("res://.godot/table-preview.png")
	quit()
