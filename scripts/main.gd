extends Node

const GameUI = preload("res://scripts/ui/game_ui.gd")


func _ready() -> void:
	add_child(GameUI.new())
