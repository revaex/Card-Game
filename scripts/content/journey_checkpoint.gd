extends RefCounted
## Persists campaign boundaries. Combat objects and presentation never go on disk.

const Journey = preload("res://scripts/combat/journey_state.gd")
const Library = preload("res://scripts/content/deck_library.gd")
const Relics = preload("res://scripts/content/relic_collection.gd")
const SaveFile = preload("res://scripts/content/save_file.gd")
const VERSION := 1

var path := "user://journey.checkpoint"
var error_message := ""
var has_run := false
var _read_failed := false


func save_run(run: RefCounted, deck_name: String) -> bool:
	if run.phase == Journey.Phase.DUEL:
		return false
	var cards: Array[Dictionary] = []
	for card: CardInstance in run.roster:
		cards.append({"id": String(card.definition.id), "cost": card.cost_modifier, "category": card.category_override})
	var relic_id: String = run.equipped_relic.id if run.equipped_relic != null else ""
	return write({
		"id": run.checkpoint_id, "deck": deck_name, "cards": cards, "health": run.health,
		"phase": int(run.phase), "stage": run.stage, "relic": relic_id, "war_drum": run.use_war_drum,
		"summaries": run.summaries, "edits": run.edits,
	})


func write(checkpoint: Dictionary) -> bool:
	if _read_failed:
		return false
	var error := SaveFile.replace(path, var_to_bytes({"version": VERSION, "run": checkpoint}))
	error_message = "" if error == OK else "Could not save Journey progress. Keep the game open and try again."
	if error == OK:
		has_run = not checkpoint.is_empty()
	return error == OK


func load_run() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var stored: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	if stored is Dictionary and stored.get("version") == VERSION and stored.get("run") is Dictionary:
		if stored.run.is_empty():
			return {}
		var restored := restore(stored.run)
		if not restored.is_empty():
			has_run = true
			return restored
	_read_failed = true
	error_message = "This Journey checkpoint could not be read. The file was kept."
	return {}


func restore(data: Dictionary) -> Dictionary:
	var stage: Variant = data.get("stage")
	var phase: Variant = data.get("phase")
	if not stage is int or stage < 0 or stage >= Journey.Rivals.ALL.size():
		return {}
	if not phase is int or phase not in [Journey.Phase.READY, Journey.Phase.REWARD, Journey.Phase.COMPLETE, Journey.Phase.DEFEAT]:
		return {}
	if phase == Journey.Phase.COMPLETE and stage != Journey.Rivals.ALL.size() - 1:
		return {}
	if phase == Journey.Phase.REWARD and stage >= Journey.DRAFTS.size():
		return {}
	var run_id: Variant = data.get("id")
	if not run_id is String or run_id.is_empty() or not data.get("deck") is String or not data.get("relic") is String or not data.get("war_drum") is bool:
		return {}
	if not data.get("cards") is Array or data.cards.is_empty() or not data.get("edits") is Array or not data.get("summaries") is Array:
		return {}
	if data.summaries.size() != stage + int(phase != Journey.Phase.READY):
		return {}
	var definitions := {}
	for card: CardDefinition in Library.CARDS:
		definitions[String(card.id)] = card
	var cards: Array[CardInstance] = []
	for entry in data.cards:
		if not entry is Dictionary or not definitions.has(entry.get("id")) or not entry.get("cost") is int or not entry.get("category") is int or entry.category not in [-1, 0, 1, 2]:
			return {}
		var card := CardInstance.new(definitions[entry.id])
		card.cost_modifier = entry.cost
		card.category_override = entry.category
		cards.append(card)
	var relic: Resource
	for candidate: Resource in Relics.CATALOG:
		if candidate.id == data.relic:
			relic = candidate
	if relic == null and not data.relic.is_empty():
		return {}
	var run := Journey.new(cards, data.war_drum, relic)
	if not data.get("health") is int or data.health < 0 or data.health > run.max_health:
		return {}
	if (data.health == 0) != (phase == Journey.Phase.DEFEAT):
		return {}
	for entry in data.edits:
		if not entry is String:
			return {}
		run.edits.append(entry)
	for index in range(data.summaries.size()):
		var summary: Variant = data.summaries[index]
		var outcome := "Defeat" if phase == Journey.Phase.DEFEAT and index == stage else "Victory"
		if not valid_summary(summary, outcome):
			return {}
		run.summaries.append(summary)
	run.checkpoint_id = run_id
	run.phase = phase
	run.stage = stage
	run.health = data.health
	return {"journey": run, "deck": data.deck}


func valid_summary(summary: Variant, outcome: String) -> bool:
	if not summary is Dictionary or summary.get("outcome") != outcome or not summary.get("rounds") is int or not summary.get("player_health") is int:
		return false
	if not summary.get("statistics") is Dictionary or not summary.statistics.get("player") is Dictionary:
		return false
	for key in ["cards", "damage", "rewrites", "patterns"]:
		if not summary.statistics.player.get(key) is int:
			return false
	return true
