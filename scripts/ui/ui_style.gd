extends RefCounted
## Small shared visual helpers. Screen behavior stays in its own controller.

const INK = Color("eee2c9")
const GOLD = Color("cfaa66")
const MUTED = Color("9ba9a4")
const InfoLabel = preload("res://scripts/ui/info_label.gd")
const InfoButton = preload("res://scripts/ui/info_button.gd")


static func box(color: Color, border: Color = Color("334546")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_stylebox("normal", "Button", box(Color("203436")))
	result.set_stylebox("hover", "Button", box(Color("304c4c"), GOLD))
	result.set_stylebox("pressed", "Button", box(Color("42605a"), GOLD))
	result.set_stylebox("disabled", "Button", box(Color("182526")))
	var focus := box(Color(0, 0, 0, 0), GOLD)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_disabled_color", "Button", Color("7c8985"))
	result.set_stylebox("panel", "PopupMenu", box(Color("142428"), GOLD))
	result.set_stylebox("normal", "OptionButton", box(Color("203436")))
	result.set_stylebox("hover", "OptionButton", box(Color("304c4c"), GOLD))
	result.set_color("font_color", "OptionButton", INK)
	result.set_stylebox("normal", "LineEdit", box(Color("102426")))
	result.set_color("font_color", "LineEdit", INK)
	var tooltip := box(Color("101c22"), GOLD)
	tooltip.content_margin_left = 16
	tooltip.content_margin_right = 16
	result.set_stylebox("panel", "TooltipPanel", tooltip)
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	result.set_font_size("font_size", "TooltipLabel", 14)
	result.set_stylebox("panel", "AcceptDialog", box(Color("142428"), GOLD))
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 14)
	return result


static func label(parent: Node, text: String, size: int = 18, color: Color = INK) -> Label:
	var node := InfoLabel.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


static func heading(parent: Node, text: String, size: int = 32, color: Color = INK) -> Label:
	var node := label(parent, text, size, color)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman"])
	node.add_theme_font_override("font", serif)
	return node


static func primary(button_node: Button) -> void:
	button_node.add_theme_stylebox_override("normal", box(Color("b9985c"), Color("efd4a0")))
	button_node.add_theme_stylebox_override("hover", box(Color("d0ae70"), Color("f4e0b5")))
	button_node.add_theme_stylebox_override("pressed", box(Color("a78852"), GOLD))
	button_node.add_theme_color_override("font_color", Color("152426"))
	button_node.add_theme_color_override("font_hover_color", Color("152426"))
	button_node.add_theme_color_override("font_pressed_color", Color("152426"))


static func button(parent: Node, text: String, action: Callable) -> Button:
	var node := InfoButton.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	parent.add_child(node)
	return node


static func quiet(node: Button) -> void:
	var normal := box(Color("142428"), Color("142428"))
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("203436")
	hover.border_color = Color("52635a")
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_font_size_override("font_size", 13)


static func column(parent: Node, expand: bool = false) -> VBoxContainer:
	var node := VBoxContainer.new()
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node


static func row(parent: Node) -> HBoxContainer:
	var node := HBoxContainer.new()
	parent.add_child(node)
	return node


static func panel(parent: Node) -> VBoxContainer:
	var node := PanelContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("panel", box(Color("142a2c")))
	parent.add_child(node)
	return column(node, true)
