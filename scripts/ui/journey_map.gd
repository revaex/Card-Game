extends VBoxContainer
## The chart previews encounters. Journey state decides which duel may begin.

const Rivals = preload("res://scripts/content/rival_catalog.gd")
const Journey = preload("res://scripts/combat/journey_state.gd")
const Style = preload("res://scripts/ui/ui_style.gd")
const CardBrowser = preload("res://scenes/ui/card_browser.tscn")
const CURRENT_INK := Color("97e4c1")

var _journey: RefCounted
var _selected := -1
var _motion := true
var _reveal: Tween


func setup(journey: RefCounted, enter_encounter: Callable, motion: bool) -> void:
	_journey = journey
	_motion = motion
	var track_step := 0.66 / (Rivals.ALL.size() - 1)
	var destination: float = 0.17 + track_step * journey.stage
	%Traveled.anchor_right = destination
	if motion and journey.stage > 0:
		%Traveled.anchor_right = destination - track_step
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(%Traveled, "anchor_right", destination, 0.55)
	Style.primary(%Enter)
	%Enter.pressed.connect(enter_encounter)
	%Scout.pressed.connect(scout_deck)
	for index in range(Rivals.ALL.size()):
		var stop := %Stops.get_child(index)
		var rival: Resource = Rivals.ALL[index]
		var inspect: Button = stop.get_node("Inspect")
		var state: Label = stop.get_node("State")
		var active: bool = index == journey.stage
		stop.get_node("Region").text = "%02d  /  %s" % [index + 1, rival.route_region.to_upper()]
		stop.get_node("Rival").text = rival.display_name
		if index < journey.stage:
			state.text = "✓  CLEARED"
		elif active:
			state.text = "◆  DUEL IN PROGRESS" if journey.phase == Journey.Phase.DUEL else "◆  NEXT DUEL"
		else:
			state.text = "◇  AHEAD"
		state.add_theme_color_override("font_color", CURRENT_INK if index <= journey.stage else Style.MUTED)
		var art: Control = inspect.get_node("Emblem")
		art.motif = rival.display_name
		art.accent = rival.accent if index <= journey.stage else rival.accent.lerp(Style.MUTED, 0.6)
		inspect.toggle_mode = true
		inspect.tooltip_text = "Scout %s · %s" % [rival.display_name, rival.route_region]
		inspect.add_theme_stylebox_override("normal", seal(Color("14262c"), rival.accent if active else Color("687465")))
		inspect.add_theme_stylebox_override("hover", seal(Color("213d42"), rival.accent))
		inspect.add_theme_stylebox_override("pressed", seal(Color("22413f"), CURRENT_INK, 2))
		inspect.add_theme_stylebox_override("focus", seal(Color.TRANSPARENT, Style.GOLD, 3))
		inspect.focus_entered.connect(select_stop.bind(index))
		inspect.pressed.connect(select_stop.bind(index))
	select_stop(journey.stage)
	%Enter.grab_focus()


func seal(paper: Color, ink: Color, weight: int = 1) -> StyleBoxFlat:
	var stamp := Style.box(paper, ink)
	stamp.set_corner_radius_all(46)
	stamp.set_border_width_all(weight)
	return stamp


func select_stop(index: int) -> void:
	for stop in %Stops.get_children():
		stop.get_node("Inspect").set_pressed_no_signal(stop.get_index() == index)
	if index == _selected:
		return
	_selected = index
	var rival: Resource = Rivals.ALL[index]
	var current: bool = index == _journey.stage
	var cleared: bool = index < _journey.stage
	%Title.text = "%s  /  %s" % [rival.route_region, rival.display_name]
	%Doctrine.text = "%d HP  ·  %d cards  ·  %s" % [rival.health, rival.cards.size(), rival.doctrine_text()]
	%Doctrine.add_theme_color_override("font_color", rival.accent)
	if cleared:
		var record: Dictionary = _journey.summaries[index]
		%Advice.text = "Cleared in %d rounds with %d HP remaining." % [record.rounds, record.player_health]
	else:
		%Advice.text = rival.description if rival.opening_advice.is_empty() else rival.opening_advice
	var opening := PackedStringArray()
	for card: CardDefinition in rival.opening_line:
		opening.append(card.display_name)
	%Opening.visible = not opening.is_empty() and not cleared
	%Opening.text = "Scouted opening  ·  " + "  /  ".join(opening)
	%Enter.disabled = not current
	if current:
		%Enter.text = "Resume duel  →" if _journey.phase == Journey.Phase.DUEL else "Enter chapter %d  →" % (index + 1)
	else:
		%Enter.text = "Cleared" if cleared else "Ahead on the route"
	if _motion and _reveal == null:
		_reveal = create_tween()
		$Briefing.modulate.a = 0.78
		_reveal.tween_property($Briefing, "modulate:a", 1.0, 0.18)
		_reveal.finished.connect(func(): _reveal = null)


func scout_deck() -> void:
	var rival: Resource = Rivals.ALL[_selected]
	var dialog := CardBrowser.instantiate()
	dialog.name = "ScoutDeck"
	add_child(dialog)
	dialog.close_requested.connect(func():
		dialog.hide()
		dialog.queue_free()
		%Scout.grab_focus())
	dialog.show_cards(rival.display_name, rival.create_deck(), "Scouted deck · draw order hidden")
