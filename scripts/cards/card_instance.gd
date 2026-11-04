class_name CardInstance
extends RefCounted

var definition: CardDefinition
var cost_modifier: int = 0
var category_override: int = -1


func _init(card_definition: CardDefinition) -> void:
	assert(card_definition != null, "A card instance needs a definition.")
	definition = card_definition


func get_energy_cost() -> int:
	return maxi(definition.energy_cost + cost_modifier, 0)


func get_category() -> int:
	return category_override if category_override >= 0 else definition.category


func copy_for_combat() -> CardInstance:
	var copy := CardInstance.new(definition)
	copy.cost_modifier = cost_modifier
	copy.category_override = category_override
	return copy
