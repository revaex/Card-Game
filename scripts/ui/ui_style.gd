extends RefCounted
## Small shared visual helpers. Screen behavior stays in its own controller.

const INK = Color("e8eadf")
const GOLD = Color("dbc28b")
const MUTED = Color("929f9e")


static func box(color: Color, border: Color = Color("334546")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
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
	result.set_stylebox("focus", "Button", box(Color("304c4c"), GOLD))
	result.set_stylebox("normal", "LineEdit", box(Color("102426")))
	result.set_color("font_color", "LineEdit", INK)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 14)
	return result


static func label(parent: Node, text: String, size: int = 18, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


static func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.pressed.connect(action)
	parent.add_child(node)
	return node


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
