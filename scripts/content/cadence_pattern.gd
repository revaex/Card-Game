extends Resource
## Shared recipe and payoff. Encounter progress belongs to CombatSession.

@export var display_name: String
@export var first: CardDefinition.Category = CardDefinition.Category.ATTACK
@export_range(0, 99) var block_gain: int = 0
@export_range(0, 99) var finishing_damage: int = 0
@export_range(0, 3) var energy_gain: int = 0


func category_at(step: int) -> int:
	return (first + step) % CardDefinition.Category.size()


func sequence_text() -> String:
	var names := CardDefinition.Category.keys()
	return "%s → %s → %s" % [names[category_at(0)].capitalize(), names[category_at(1)].capitalize(), names[category_at(2)].capitalize()]


func payoff_text() -> String:
	var parts: PackedStringArray = []
	if block_gain > 0:
		parts.append("Gain %d Block before the finishing card." % block_gain)
	if energy_gain > 0:
		parts.append("Gain %d energy before the finishing card." % energy_gain)
	if finishing_damage > 0:
		parts.append("The finishing card deals +%d damage per hit." % finishing_damage)
	return " ".join(parts)
