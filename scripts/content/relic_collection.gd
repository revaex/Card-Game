extends RefCounted
## The local collection stores Marks, milestone IDs, and the equipped relic ID.

const Relic = preload("res://scripts/artifacts/relic_definition.gd")
const CATALOG = [
	preload("res://data/relics/war_drum.tres"),
	preload("res://data/relics/guard_sigil.tres"),
	preload("res://data/relics/warden_aegis.tres"),
	preload("res://data/relics/scribe_quill.tres"),
	preload("res://data/relics/gilded_seal.tres"),
]
const DUEL_MARKS := 20
const JOURNEY_BONUS := 35

var save_path := "user://relics.cfg"
var marks := 0
var owned: PackedStringArray = ["war_drum"]
var defeated: PackedStringArray = []
var journey_won := false
var equipped_id := "war_drum"
var error_message := ""


func load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			error_message = "Could not read relic progress."
		return
	marks = maxi(0, int(config.get_value("relics", "marks", config.get_value("relics", "coins", 0))))
	var stored_owned: Variant = config.get_value("relics", "owned", PackedStringArray(["war_drum"]))
	var stored_defeated: Variant = config.get_value("relics", "defeated", PackedStringArray())
	if stored_owned is PackedStringArray:
		owned = stored_owned
	if not owned.has("war_drum"):
		owned.append("war_drum")
	if stored_defeated is PackedStringArray:
		defeated = stored_defeated
	journey_won = bool(config.get_value("relics", "journey_won", false))
	equipped_id = str(config.get_value("relics", "equipped", "war_drum"))
	if not owned.has(equipped_id):
		equipped_id = ""


func save_profile() -> bool:
	var config := ConfigFile.new()
	config.set_value("relics", "marks", marks)
	config.set_value("relics", "owned", owned)
	config.set_value("relics", "defeated", defeated)
	config.set_value("relics", "journey_won", journey_won)
	config.set_value("relics", "equipped", equipped_id)
	var error := config.save(save_path)
	error_message = "" if error == OK else "Could not save relic progress. Try again."
	return error == OK


func equipped() -> Relic:
	for relic in CATALOG:
		if relic.id == equipped_id:
			return relic
	return null


func meets_milestone(relic: Relic) -> bool:
	return (relic.required_rival.is_empty() or defeated.has(relic.required_rival)) and (not relic.requires_journey or journey_won)


func buy(relic: Relic) -> bool:
	if not CATALOG.has(relic) or owned.has(relic.id) or not meets_milestone(relic) or marks < relic.price:
		return false
	marks -= relic.price
	owned.append(relic.id)
	if save_profile():
		return true
	owned.remove_at(owned.size() - 1)
	marks += relic.price
	return false


func equip(id: String) -> bool:
	if not id.is_empty() and not owned.has(id):
		return false
	var previous := equipped_id
	equipped_id = id
	if save_profile():
		return true
	equipped_id = previous
	return false


func record_victory(rival_id: String, finished_journey: bool) -> int:
	if rival_id.is_empty():
		return 0
	var amount := DUEL_MARKS + (JOURNEY_BONUS if finished_journey else 0)
	var was_defeated := defeated.has(rival_id)
	var old_journey := journey_won
	if not was_defeated:
		defeated.append(rival_id)
	journey_won = journey_won or finished_journey
	marks += amount
	if save_profile():
		return amount
	marks -= amount
	if not was_defeated:
		defeated.remove_at(defeated.size() - 1)
	journey_won = old_journey
	return 0
