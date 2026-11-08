extends RefCounted
## Saved deck recipes contain IDs/counts, never live CardInstance objects.

const CARDS = [
	preload("res://data/cards/errata.tres"),
	preload("res://data/cards/paper_trail.tres"),
	preload("res://data/cards/second_reading.tres"),
	preload("res://data/cards/strike.tres"),
	preload("res://data/cards/block.tres"),
	preload("res://data/cards/mend.tres"),
	preload("res://data/cards/insight.tres"),
	preload("res://data/cards/siphon.tres"),
	preload("res://data/cards/venom.tres"),
	preload("res://data/cards/crosscut.tres"),
	preload("res://data/cards/switchback.tres"),
	preload("res://data/cards/redline.tres"),
	preload("res://data/cards/iron_seal.tres"),
	preload("res://data/cards/marginalia.tres"),
	preload("res://data/cards/inkblot.tres"),
	preload("res://data/cards/parry_cut.tres"),
	preload("res://data/cards/double_notch.tres"),
	preload("res://data/cards/venom_edge.tres"),
	preload("res://data/cards/reclaiming_cut.tres"),
	preload("res://data/cards/field_dressing.tres"),
	preload("res://data/cards/loose_leaf.tres"),
	preload("res://data/cards/folio_wall.tres"),
	preload("res://data/cards/bitter_guard.tres"),
	preload("res://data/cards/breathing_room.tres"),
	preload("res://data/cards/tainted_index.tres"),
	preload("res://data/cards/restoration.tres"),
	preload("res://data/cards/revision_note.tres"),
]
const SAVE_PATH = "user://decks.json"
const JOURNEY_MIN_CARDS := 10
const JOURNEY_MAX_CARDS := 14
const JOURNEY_COPY_LIMIT := 2
const STARTER_IDS := ["strike", "block"]
const RECIPE_COPY_LIMIT := 50
var save_path: String = SAVE_PATH
var decks: Array[Dictionary] = []
var error_message: String = ""


func load_decks() -> void:
	decks.clear()
	if not FileAccess.file_exists(save_path):
		decks = [{"name": "Starter", "cards": {"strike": 5, "block": 5}}, {"name": "Effects demo", "cards": {"strike": 3, "block": 3, "mend": 1, "insight": 2, "siphon": 1}}]
		decks.append(counterpoint_recipe())
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
			counts[String(card.id)] = clampi(int(entry.cards.get(String(card.id), 0)), 0, RECIPE_COPY_LIMIT)
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


func journey_issues(recipe: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	var size := total(recipe)
	if size < JOURNEY_MIN_CARDS or size > JOURNEY_MAX_CARDS:
		issues.append("Use %d–%d cards (currently %d)." % [JOURNEY_MIN_CARDS, JOURNEY_MAX_CARDS, size])
	for definition in CARDS:
		var id := String(definition.id)
		var copies := int(recipe.cards.get(id, 0))
		if id not in STARTER_IDS and copies > JOURNEY_COPY_LIMIT:
			issues.append("%s has %d copies. Use at most %d." % [definition.display_name, copies, JOURNEY_COPY_LIMIT])
	return issues


func instantiate_deck(recipe: Dictionary) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for definition in CARDS:
		for index in range(int(recipe.cards.get(String(definition.id), 0))):
			result.append(CardInstance.new(definition))
	return result


func counterpoint_recipe() -> Dictionary:
	return {"name": "Counterpoint", "cards": {"strike": 2, "block": 2, "crosscut": 2, "switchback": 2, "venom": 1, "mend": 1}}


func palimpsest_recipe() -> Dictionary:
	return {"name": "Palimpsest", "cards": {"redline": 2, "iron_seal": 2, "marginalia": 2, "inkblot": 1, "crosscut": 2, "block": 1}}


func counterpoint_sustain_recipe() -> Dictionary:
	var recipe := counterpoint_recipe()
	recipe.name = "Counterpoint · Sustain"
	recipe.cards.mend = 2
	recipe.cards.venom = 0
	return recipe


func category_counts(recipe: Dictionary) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for definition in CARDS:
		counts[definition.category] += int(recipe.cards.get(String(definition.id), 0))
	return counts


func profile_text(recipe: Dictionary) -> String:
	var curve := {}
	var healing := 0
	var damage := 0
	var block := 0
	var draw := 0
	var counterwritten := 0
	for definition in CARDS:
		var copies := int(recipe.cards.get(String(definition.id), 0))
		if copies == 0:
			continue
		var cost: int = definition.energy_cost
		curve[cost] = curve.get(cost, 0) + copies
		if definition.effects.any(func(effect): return effect is HealEffect):
			healing += copies
		if definition.effects.any(func(effect): return effect is DamageEffect or effect is ApplyPoisonEffect):
			damage += copies
		if definition.effects.any(func(effect): return effect is GainBlockEffect):
			block += copies
		if definition.effects.any(func(effect): return effect is DrawEffect):
			draw += copies
		if definition.effects.any(func(effect): return effect != null and effect.after_rewrite):
			counterwritten += copies
	var costs := curve.keys()
	costs.sort()
	var buckets := PackedStringArray()
	for cost in costs:
		buckets.append("%dE ×%d" % [cost, curve[cost]])
	return "Energy · %s\nHealing cards %d · Damage cards %d\nBlock cards %d · Draw cards %d\nCounterwritten cards %d" % [" / ".join(buckets) if not buckets.is_empty() else "—", healing, damage, block, draw, counterwritten]


func style_recipes() -> Array[Dictionary]:
	return [
		{"name": "Poison Pressure", "cards": {"strike": 2, "block": 2, "venom": 2, "inkblot": 2, "siphon": 2}},
		{"name": "Riposte Guard", "cards": {"strike": 3, "block": 2, "iron_seal": 2, "insight": 2, "mend": 1}},
		{"name": "Surge Cycle", "cards": {"redline": 2, "crosscut": 2, "switchback": 2, "insight": 2, "block": 2}},
		{"name": "Measured Guard", "cards": {"parry_cut": 2, "field_dressing": 2, "breathing_room": 2, "strike": 2, "insight": 2}},
		{"name": "Twin Riposte", "cards": {"double_notch": 2, "folio_wall": 2, "breathing_room": 2, "block": 2, "strike": 2}},
		{"name": "Toxic Ledger", "cards": {"venom_edge": 2, "bitter_guard": 2, "tainted_index": 2, "inkblot": 2, "block": 2}},
		{"name": "Rewrite Engine", "cards": {"reclaiming_cut": 2, "loose_leaf": 2, "revision_note": 2, "errata": 2, "paper_trail": 2}},
		{"name": "Recovery Line", "cards": {"reclaiming_cut": 2, "field_dressing": 2, "restoration": 2, "strike": 2, "switchback": 2}},
		{"name": "Zero Margin", "cards": {"redline": 2, "loose_leaf": 2, "revision_note": 2, "crosscut": 2, "insight": 2}},
		{"name": "Shelter Archive", "cards": {"parry_cut": 2, "folio_wall": 2, "restoration": 2, "block": 2, "insight": 2}},
		{"name": "Poison and Steel", "cards": {"venom_edge": 2, "double_notch": 2, "bitter_guard": 2, "tainted_index": 2, "field_dressing": 2}},
	]


func counterwritten_recipe() -> Dictionary:
	return {"name": "Counterwritten", "cards": {"errata": 2, "paper_trail": 2, "second_reading": 2, "redline": 2, "switchback": 2}}
