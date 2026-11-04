extends VBoxContainer
## Editor-authored view: layout lives in main_menu.tscn; navigation stays in GameUI.

signal journey_requested
signal single_duel_requested
signal custom_duel_requested
signal decks_requested
signal quit_requested


func set_has_journey(active: bool) -> void:
	%JourneyButton.text = "Continue journey  →" if active else "Begin a journey  →"


func _on_journey_pressed() -> void:
	journey_requested.emit()


func _on_single_pressed() -> void:
	single_duel_requested.emit()


func _on_custom_pressed() -> void:
	custom_duel_requested.emit()


func _on_decks_pressed() -> void:
	decks_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
