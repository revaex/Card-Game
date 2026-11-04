class_name CardDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var energy_cost: int = 1
@export var effects: Array[CardEffect] = []
