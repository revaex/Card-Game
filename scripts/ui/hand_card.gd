extends PanelContainer
## Card presentation only: shared definitions describe content; callbacks request actions.

const Style = preload("res://scripts/ui/ui_style.gd")
const CATEGORY_INK = [Color("862b22"), Color("155479"), Color("684c19")]
const TextInk = preload("res://scripts/ui/text_ink.gd")
signal inspected
signal inspection_ended
const Tooltip = preload("res://scripts/ui/board_tooltip.gd")

func setup(card: CardInstance, playable: bool, play_action: Callable, exhaust_action: Callable = Callable(), effective_text: String = "", details: String = "", pattern_name: String = "", action_hint: String = "Unavailable") -> void:
	var preview := play_action.is_null()
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
	var frame := Style.box(Color("eadbb8"), accent)
	if not playable and not preview:
		frame.bg_color = Color("c4bea9")
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
	%Cost.text = str(card.get_energy_cost())
	%Cost.add_theme_color_override("font_color", Color("a6efbd") if card.get_energy_cost() == 0 else Color("ffe0a0"))
	var coin := Style.box(Color("263b40"), accent)
	coin.set_corner_radius_all(13)
	coin.content_margin_left = 3
	coin.content_margin_right = 3
	coin.content_margin_top = 0
	coin.content_margin_bottom = 0
	%Cost.add_theme_stylebox_override("normal", coin)
	%Cost.tooltip_text = "%d energy" % card.get_energy_cost()
	%Title.text = card.definition.display_name
	%ArtFrame.add_theme_stylebox_override("panel", Style.box(Color("122229"), accent))
	%Emblem.kind = kind
	%Emblem.accent = accent
	%Emblem.queue_redraw()
	var category: String = CardDefinition.Category.keys()[card.get_category()]
	var detail := pattern_name.to_upper() if not pattern_name.is_empty() else ("REVISED" if card.category_override >= 0 else (kind if kind != category and kind != "TACTIC" else ""))
	%Category.text = category + (" · " + detail if not detail.is_empty() else "")
	%Category.add_theme_color_override("font_color", CATEGORY_INK[card.get_category()])
	%Description.text = TextInk.format(effective_text if not effective_text.is_empty() else card.definition.description)
	%Footer.text = "CLICK TO PLAY" if playable else action_hint.to_upper()
	var play: Button = %Play
	if preview:
		play.hide()
		return
	play.pressed.connect(play_action)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("fff0c4")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(6)
	play.add_theme_stylebox_override("focus", focus)
	play.disabled = not playable
	play.tooltip_text = tooltip_text + "\n" + ("Click this card, or focus it and press Enter / Space to play." if playable else action_hint)
	play.mouse_entered.connect(func(): inspected.emit())
	play.mouse_exited.connect(func(): inspection_ended.emit())
	play.focus_entered.connect(func(): inspected.emit())
	play.focus_exited.connect(func(): inspection_ended.emit())
	if not exhaust_action.is_null():
		var exhaust := Style.button(play, "×", exhaust_action)
		exhaust.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		exhaust.offset_left = -28
		exhaust.offset_bottom = 28
		exhaust.custom_minimum_size = Vector2(28, 28)
		Style.quiet(exhaust)
		exhaust.tooltip_text = "Exhaust this card (testing tool)"


func setup_preview(card: CardInstance, caption: String = "") -> void:
	setup(card, false, Callable())
	set_caption(caption)


func enable_hand_drag(table: Control, card: CardInstance) -> void:
	%Play.table = table
	%Play.card = card
	%Play.face = self
	if not %Play.disabled:
		set_caption("Click or drag to play")
		%Play.tooltip_text = tooltip_text + "\nClick, press Enter / Space, or drag this card onto the table. Drag it onto another card to reorder your hand."


func set_touch_selected(selected: bool) -> void:
	self_modulate = Color(1.15, 1.06, 0.86) if selected else Color.WHITE
	set_caption("Selected · tap again to cancel" if selected else "Click or drag to play")


func make_snapshot() -> Control:
	var copy: Control = duplicate(Node.DUPLICATE_SCRIPTS)
	copy.get_node("HitArea").hide()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in copy.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.modulate = Color.WHITE
	copy.size = size
	return copy


func set_caption(caption: String) -> void:
	%Footer.text = caption.to_upper()


func _make_custom_tooltip(text: String) -> Object:
	return Tooltip.create(text)
