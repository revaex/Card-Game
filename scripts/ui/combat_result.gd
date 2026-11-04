extends Control
## Encounter summary and navigation. No progression or saved-deck mutation.

const Style = preload("res://scripts/ui/ui_style.gd")


func setup(summary: Dictionary, rematch: Callable, choose_decks: Callable, review: Callable, primary_text: String = "Rematch", secondary_text: String = "Choose decks") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Style.panel(center)
	panel.get_parent().custom_minimum_size.x = 520
	Style.label(panel, "ENCOUNTER COMPLETE", 14, Style.GOLD)
	var won: bool = summary.outcome == "Victory"
	Style.heading(panel, "Victory" if won else "Defeat", 38, Color("8bd2ac") if won else Color("e59d8d"))
	Style.label(panel, "%d %s  ·  Your HP %d  ·  Rival HP %d" % [summary.rounds, "turn" if summary.rounds == 1 else "turns", summary.player_health, summary.enemy_health], 16, Style.MUTED)
	var columns := Style.row(panel)
	for side in ["player", "enemy"]:
		var column := Style.column(columns, true)
		var totals: Dictionary = summary.statistics[side]
		Style.label(column, "YOU" if side == "player" else summary.get("rival_name", "Rival").to_upper(), 16, Style.GOLD)
		for entry in [["Cards played", totals.cards], ["Energy spent", totals.energy], ["HP damage dealt", totals.damage], ["Damage blocked", totals.absorbed], ["HP healed", totals.healed], ["Poison applied", totals.poison_applied], ["Intent rewrites", totals.rewrites], ["Patterns completed", totals.patterns]]:
			Style.label(column, "%s: %d" % [entry[0], entry[1]], 15)
	var actions := Style.row(panel)
	var again := Style.button(actions, primary_text, rematch)
	again.name = "Rematch"
	Style.button(actions, secondary_text, choose_decks).name = "ChooseDecks"
	Style.button(panel, "Review the table and log", review).name = "Review"
	again.grab_focus()
