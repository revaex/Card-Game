class_name CardDefinition
extends Resource

enum Category { ATTACK, GUARD, TACTIC }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var energy_cost: int = 1
@export var category: Category = Category.TACTIC
@export var effects: Array[CardEffect] = []
