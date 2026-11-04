extends Resource
## Shared recipe and payoff. Encounter progress belongs to CombatSession.

@export var display_name: String
@export var first: CardDefinition.Category = CardDefinition.Category.ATTACK
@export var second: CardDefinition.Category = CardDefinition.Category.GUARD
@export var third: CardDefinition.Category = CardDefinition.Category.TACTIC
@export_range(0, 99) var block_gain: int = 0
@export_range(0, 99) var finishing_damage: int = 0
@export_range(0, 3) var energy_gain: int = 0
@export var payoff: String


func matches(history: Array[int]) -> bool:
	return history.size() == 3 and history[0] == first and history[1] == second and history[2] == third


func sequence_text() -> String:
	var names := CardDefinition.Category.keys()
	return "%s → %s → %s" % [names[first].capitalize(), names[second].capitalize(), names[third].capitalize()]
