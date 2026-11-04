extends Label

const Tooltip = preload("res://scripts/ui/board_tooltip.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _make_custom_tooltip(text: String) -> Object:
	return Tooltip.create(text)
