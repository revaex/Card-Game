extends VBoxContainer
## Editor-authored view: layout lives in main_menu.tscn; navigation stays in GameUI.

signal journey_requested
signal lesson_requested
signal relics_requested
signal single_duel_requested
signal custom_duel_requested
signal decks_requested
signal options_requested
signal quit_requested


func set_has_journey(active: bool) -> void:
	%JourneyButton.text = "Continue journey  →" if active else "Begin a journey  →"


func set_relic_marks(marks: int) -> void:
	%RelicsButton.text = "Relics · %d Marks" % marks if marks > 0 else "Relic collection"


func _on_journey_pressed() -> void:
	journey_requested.emit()


func _on_lesson_pressed() -> void:
	lesson_requested.emit()


func _on_relics_pressed() -> void:
	relics_requested.emit()


func _on_single_pressed() -> void:
	single_duel_requested.emit()


func _on_custom_pressed() -> void:
	custom_duel_requested.emit()


func _on_decks_pressed() -> void:
	decks_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _on_options_pressed() -> void:
	options_requested.emit()
