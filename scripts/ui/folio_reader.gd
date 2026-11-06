extends Window

var pages: Array[Dictionary] = []
var page_index := 0
var animate_pages := true
var last_caption := "Close"
var _fade: Tween

const TextInk = preload("res://scripts/ui/text_ink.gd")
const PLATES = preload("res://data/ui/folio_plates.svg")
const PATTERN_BADGES = preload("res://data/ui/pattern_badges.svg")


func open(entries: Array[Dictionary], caption: String, motion: bool) -> void:
	pages = entries
	last_caption = caption
	animate_pages = motion
	update_page()
	var available := get_parent().get_window().size - Vector2i(32, 48)
	popup_centered(Vector2i(800, 460).min(available))
	%Next.grab_focus()


func update_page() -> void:
	var page: Dictionary = pages[page_index]
	%PageNumber.text = "PAGE %02d / %02d" % [page_index + 1, pages.size()]
	%Section.text = page.get("section", "DUELIST’S ALMANAC")
	%Heading.text = page.title
	%Body.text = TextInk.format(page.body, true)
	%Route.text = TextInk.format(page.get("route", ""), true)
	%Route.visible = not %Route.text.is_empty()
	%PatternSeal.visible = page.has("pattern_icon")
	if %PatternSeal.visible:
		var seal := AtlasTexture.new()
		seal.atlas = PATTERN_BADGES
		seal.region = Rect2(int(page.pattern_icon) * 32, 0, 32, 32)
		%PatternSeal.texture = seal
	var plate := AtlasTexture.new()
	plate.atlas = PLATES
	plate.region = Rect2(int(page.get("plate", 0)) * 160, 0, 160, 160)
	%Plate.texture = plate
	%Previous.disabled = page_index == 0
	%Next.text = last_caption if page_index == pages.size() - 1 else "Next page  →"
	if animate_pages:
		if _fade != null:
			_fade.kill()
		%Leaf.modulate.a = 0.62
		_fade = create_tween()
		_fade.tween_property(%Leaf, "modulate:a", 1.0, 0.20)
	else:
		%Leaf.modulate.a = 1.0


func previous_page() -> void:
	if page_index > 0:
		page_index -= 1
		update_page()


func next_page() -> void:
	if page_index < pages.size() - 1:
		page_index += 1
		update_page()
	else:
		close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_requested.emit()
	elif event.is_action_pressed("ui_page_down") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		set_input_as_handled()
		if page_index < pages.size() - 1:
			next_page()
	elif event.is_action_pressed("ui_page_up") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER):
		set_input_as_handled()
		previous_page()
