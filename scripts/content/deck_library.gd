extends RefCounted
## Saved deck recipes contain IDs/counts, never live CardInstance objects.

const CARDS = [preload("res://data/cards/strike.tres"), preload("res://data/cards/block.tres")]
const SAVE_PATH = "user://decks.json"
var save_path: String = SAVE_PATH
var decks: Array[Dictionary] = []
var error_message: String = ""


func load_decks() -> void:
	decks.clear()
	if not FileAccess.file_exists(save_path):
		decks = [{"name": "Starter", "cards": {"strike": 5, "block": 5}}]
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Array:
		error_message = "Could not read saved decks. Original save has been preserved."
		return
	for entry in parsed:
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("cards") is Dictionary:
			continue
		var counts: Dictionary = {}
		for card in CARDS:
			counts[String(card.id)] = clampi(int(entry.cards.get(String(card.id), 0)), 0, 50)
		decks.append({"name": entry.name, "cards": counts})


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		error_message = "Could not save decks (%s)." % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(decks, "\t"))
	error_message = ""
	return true


func total(recipe: Dictionary) -> int:
	var count := 0
	for value in recipe.cards.values():
		count += int(value)
	return count


func instantiate_deck(recipe: Dictionary) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for definition in CARDS:
		for index in range(int(recipe.cards.get(String(definition.id), 0))):
			result.append(CardInstance.new(definition))
	return result
