extends PanelContainer
## Opaque, wrapped help content shared by board controls.


func _init(text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("101c22")
	panel.border_color = Color("b99962")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 5
	add_theme_stylebox_override("panel", panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var first_break := text.find("\n")
	if first_break > 0 and first_break < 60:
		add_text(content, text.left(first_break), Color("e2c186"), 16)
		add_text(content, text.substr(first_break + 1), Color("eee2c9"), 14)
	else:
		add_text(content, text, Color("eee2c9"), 14)


func add_text(parent: Node, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 304
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
