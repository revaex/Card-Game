extends Node

const GameUI = preload("res://scripts/ui/game_ui.gd")


func _ready() -> void:
	# Keep the native title bar and taskbar while using the available desktop.
	if DisplayServer.get_name() != "headless" and not get_window().is_embedded():
		get_window().mode = Window.MODE_MAXIMIZED
	add_child(GameUI.new())
