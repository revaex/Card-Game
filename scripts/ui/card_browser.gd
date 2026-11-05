extends Window
## Read-only snapshot of a recipe or pile. Display order never reveals draw order.

const CardView = preload("res://scenes/ui/card.tscn")


func show_cards(heading: String, cards: Array[CardInstance], note: String = "") -> void:
	title = heading
	%Summary.text = "%d %s" % [cards.size(), "card" if cards.size() == 1 else "cards"]
	if not note.is_empty():
		%Summary.text += "   /   " + note
	%Empty.visible = cards.is_empty()
	%Scroll.visible = not cards.is_empty()
	var groups: Dictionary = {}
	for card in cards:
		var key := "%s/%s/%d/%d" % [card.definition.display_name, card.definition.id, card.category_override, card.get_energy_cost()]
		if not groups.has(key):
			groups[key] = {"card": card, "count": 0}
		groups[key].count += 1
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = groups[key]
		var view := CardView.instantiate()
		%Cards.add_child(view)
		var caption := "×%d copies" % entry.count if entry.count > 1 else "1 copy"
		view.setup_preview(entry.card, caption)
	var available := Vector2i(get_parent().get_viewport().get_visible_rect().size) - Vector2i(32, 72)
	var height := 500 if groups.size() > 4 else (240 if groups.is_empty() else 360)
	popup_centered(Vector2i(820, height).min(available))
	%Close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
