extends ProgressBar

const Tooltip = preload("res://scripts/ui/board_tooltip.gd")


func _make_custom_tooltip(text: String) -> Object:
	return Tooltip.create(text)
