extends PanelContainer
## Card presentation only: shared definitions describe content; callbacks request actions.

const Style = preload("res://scripts/ui/ui_style.gd")
signal inspected
signal inspection_ended

class Emblem extends Control:
	var kind: String
	var accent: Color

	func _draw() -> void:
		var center := size / 2
		draw_circle(center, 26, Color(accent, 0.12))
		draw_arc(center, 26, 0, TAU, 48, Color(accent, 0.4), 1.0, true)
		match kind:
			"ATTACK":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-11, 14), center + Vector2(-5, 16), center + Vector2(18, -18), center + Vector2(9, -14)]), accent)
				draw_line(center + Vector2(-15, 5), center + Vector2(1, 17), accent, 4, true)
				draw_line(center + Vector2(-7, 12), center + Vector2(-16, 24), accent, 5, true)
			"GUARD":
				var points := PackedVector2Array([center + Vector2(-17, -17), center + Vector2(17, -17), center + Vector2(13, 9), center + Vector2(0, 22), center + Vector2(-13, 9), center + Vector2(-17, -17)])
				draw_polyline(points, accent, 3, true)
				draw_line(center + Vector2(0, -13), center + Vector2(0, 15), accent, 2, true)
			"POISON":
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -24), center + Vector2(16, 0), center + Vector2(12, 17), center + Vector2(-12, 17), center + Vector2(-16, 0)]), accent)
				draw_circle(center + Vector2(-4, 3), 3, Color("122e25"))
				draw_circle(center + Vector2(5, 10), 2, Color("122e25"))
			"RESTORE":
				draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), accent, 10, true)
				draw_line(center + Vector2(0, -18), center + Vector2(0, 18), accent, 10, true)
			_:
				for index in range(3):
					var offset := Vector2(index * 8 - 18, index * -5 - 10)
					draw_rect(Rect2(center + offset, Vector2(22, 30)), accent, false, 2)


func setup(card: CardInstance, playable: bool, play_action: Callable, exhaust_action: Callable = Callable(), effective_text: String = "", details: String = "", pattern_name: String = "") -> void:
	custom_minimum_size = Vector2(174, 226)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var kind := "TACTIC"
	var accent := Color("c5ae77")
	for effect in card.definition.effects:
		if effect is DamageEffect:
			kind = "ATTACK"
			accent = Color("d88b78")
		elif effect is GainBlockEffect:
			kind = "GUARD"
			accent = Color("79bce0")
		elif effect is ApplyPoisonEffect:
			kind = "POISON"
			accent = Color("75e69b")
		elif effect is HealEffect and kind != "ATTACK":
			kind = "RESTORE"
			accent = Color("8bd2ac")
	if card.category_override >= 0:
		accent = [Color("d88b78"), Color("79bce0"), Color("c5ae77")][card.get_category()]
	var frame := Style.box(Color("dfd3b6"), accent)
	if not pattern_name.is_empty():
		frame.border_color = Color("f4cc70")
	frame.set_border_width_all(2)
	frame.content_margin_left = 8
	frame.content_margin_right = 8
	frame.content_margin_top = 8
	frame.content_margin_bottom = 8
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 3
	frame.shadow_offset = Vector2(2, 2)
	add_theme_stylebox_override("panel", frame)
	var hover := frame.duplicate() as StyleBoxFlat
	hover.border_color = Color("fff0c4")
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", hover))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", frame))
	mouse_entered.connect(func(): inspected.emit())
	mouse_exited.connect(func(): inspection_ended.emit())
	tooltip_text = details if not details.is_empty() else card.definition.description
	if card.category_override >= 0:
		tooltip_text += "\nRevised category: %s. Card effects unchanged." % CardDefinition.Category.keys()[card.get_category()].capitalize()
	var content := Style.column(self)
	content.add_theme_constant_override("separation", 4)
	var heading := Style.row(content)
	heading.add_theme_constant_override("separation", 6)
	var cost := Style.label(heading, str(card.get_energy_cost()), 18, Color("fff1ce"))
	cost.custom_minimum_size = Vector2(28, 26)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var coin := Style.box(Color("263b40"), accent)
	coin.set_corner_radius_all(13)
	coin.content_margin_left = 3
	coin.content_margin_right = 3
	coin.content_margin_top = 0
	coin.content_margin_bottom = 0
	cost.add_theme_stylebox_override("normal", coin)
	cost.tooltip_text = "%d energy" % card.get_energy_cost()
	var title := Style.label(heading, card.definition.display_name, 18, Color("26302d"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size.y = 64
	art_frame.add_theme_stylebox_override("panel", Style.box(Color("182d30"), accent))
	content.add_child(art_frame)
	var art := Emblem.new()
	art.kind = kind
	art.accent = accent
	art_frame.add_child(art)
	var category: String = CardDefinition.Category.keys()[card.get_category()]
	var detail := pattern_name.to_upper() if not pattern_name.is_empty() else ("REVISED" if card.category_override >= 0 else (kind if kind != category and kind != "TACTIC" else ""))
	var type_label := Style.label(content, category + (" · " + detail if not detail.is_empty() else ""), 10, Color("5c6252"))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var description := Style.label(content, effective_text if not effective_text.is_empty() else card.definition.description, 14, Color("26302d"))
	description.name = "Description"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(140, 36)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := Style.row(content)
	actions.add_theme_constant_override("separation", 4)
	var play := Style.button(actions, "Play", play_action)
	play.name = "Play"
	play.custom_minimum_size.y = 30
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.add_theme_font_size_override("font_size", 14)
	play.disabled = not playable
	play.focus_entered.connect(func(): inspected.emit())
	play.focus_exited.connect(func(): inspection_ended.emit())
	if not exhaust_action.is_null():
		var exhaust := Style.button(actions, "×", exhaust_action)
		exhaust.custom_minimum_size.y = 30
		exhaust.tooltip_text = "Exhaust this card (testing tool)"
