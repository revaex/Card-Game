extends "res://scripts/ui/info_button.gd"
## A position in the rival's prepared line. Combat owns the card and the order.

const ACCENTS = [Color("b65f4b"), Color("487d99"), Color("88702c")]


func show_card(card: CardInstance, index: int, state: String, rewritable: bool) -> void:
	set_meta("intent_state", state)
	%Index.text = "%02d   /   %s" % [index + 1, state]
	%CardName.text = card.definition.display_name
	%Energy.text = "%d E" % card.get_energy_cost()
	var paper := get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	paper.border_color = ACCENTS[card.get_category()]
	if state == "RESERVE":
		paper.bg_color = Color("a6aca0")
	elif state == "NEXT":
		paper.bg_color = Color("fae0ac")
		paper.set_border_width_all(2)
	if rewritable:
		paper.shadow_color = Color("c7914850")
		paper.shadow_size = 3
	var hover := paper.duplicate() as StyleBoxFlat
	hover.bg_color = Color("fff0cc")
	hover.border_color = Color("b97a42")
	hover.set_border_width_all(2)
	add_theme_stylebox_override("normal", paper)
	add_theme_stylebox_override("disabled", paper)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	disabled = not rewritable
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if rewritable else Control.CURSOR_ARROW
