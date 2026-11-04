class_name CardInstance
extends RefCounted

var definition: CardDefinition
var cost_modifier: int = 0


func _init(card_definition: CardDefinition) -> void:
	assert(card_definition != null, "A card instance needs a definition.")
	definition = card_definition


func get_energy_cost() -> int:
	return maxi(definition.energy_cost + cost_modifier, 0)
