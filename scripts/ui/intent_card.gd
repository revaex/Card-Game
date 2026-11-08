extends "res://scripts/ui/info_button.gd"
## A position in the rival's prepared line. Combat owns the card and the order.

const ACCENTS = [Color("b65f4b"), Color("487d99"), Color("88702c")]
var _caption := ""
var _preview_caption := ""
var _line_index := 0
var _sealed := false


func show_card(card: CardInstance, index: int, state: String, rewritable: bool, highlighted: bool = false, inspectable: bool = false, sealed: bool = false, carried: bool = false) -> void:
	set_meta("intent_state", state)
	_line_index = index
	_sealed = sealed
	%Index.text = "%02d   /   %s" % [index + 1, state]
	if sealed:
		%Index.text = "%02d / SEALED" % (index + 1)
	if carried:
		%Index.text += " ↪"
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
	if highlighted:
		paper.border_color = Color("e5ab52")
		paper.set_border_width_all(3)
	if sealed:
		paper.border_color = Color("8e4d6d")
		paper.set_border_width_all(3)
	var hover := paper.duplicate() as StyleBoxFlat
	hover.bg_color = Color("fff0cc")
	hover.border_color = Color("b97a42")
	hover.set_border_width_all(2)
	add_theme_stylebox_override("normal", paper)
	add_theme_stylebox_override("disabled", paper)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	var focus := paper.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Color("79f4c8")
	focus.set_border_width_all(4)
	focus.shadow_size = 0
	add_theme_stylebox_override("focus", focus)
	_caption = %Index.text
	focus_entered.connect(update_caption)
	focus_exited.connect(update_caption)
	disabled = not (rewritable or inspectable)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if rewritable else Control.CURSOR_ARROW


func preview_plan(planned: bool) -> void:
	_preview_caption = "%02d / → %s" % [_line_index + 1, "PLANNED" if planned else "RESERVE"]
	update_caption()


func clear_preview() -> void:
	_preview_caption = ""
	update_caption()


func update_caption() -> void:
	var caption := _caption if _preview_caption.is_empty() or _sealed else _preview_caption
	%Index.text = ("▶ " if has_focus() else "") + caption
