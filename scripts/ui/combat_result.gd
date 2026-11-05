extends Control

func set_spoils(text: String) -> void:
	%Spoils.text = text
	%Spoils.visible = not text.is_empty()
## Encounter summary and navigation. No progression or saved-deck mutation.

const STAT_KEYS = ["cards", "energy", "damage", "absorbed", "healed", "poison_applied", "rewrites", "patterns"]


func setup(summary: Dictionary, rematch: Callable, choose_decks: Callable, review: Callable, primary_text: String = "", secondary_text: String = "") -> void:
	var won: bool = summary.outcome == "Victory"
	%Outcome.text = "Victory" if won else "Defeat"
	if not won:
		%Outcome.add_theme_color_override("font_color", Color("e59d8d"))
	%Summary.text = "%d %s  ·  Your HP %d  ·  Rival HP %d" % [summary.rounds, "turn" if summary.rounds == 1 else "turns", summary.player_health, summary.enemy_health]
	%RivalStatistics.get_node("ActorName").text = summary.get("rival_name", "Rival").to_upper()
	for key in STAT_KEYS:
		var value_path := "%s/Value" % key
		%PlayerStatistics.get_node(value_path).text = str(summary.statistics.player[key])
		%RivalStatistics.get_node(value_path).text = str(summary.statistics.enemy[key])

	if not primary_text.is_empty():
		%Rematch.text = primary_text
	if not secondary_text.is_empty():
		%ChooseDecks.text = secondary_text
	%Rematch.pressed.connect(rematch)
	%ChooseDecks.pressed.connect(choose_decks)
	%Review.pressed.connect(review)
	%Rematch.grab_focus()
