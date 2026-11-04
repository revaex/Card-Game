class_name DamageEffect
extends CardEffect

@export_range(0, 999) var damage: int = 10


func execute(_source: Combatant, target: Combatant) -> void:
	target.take_damage(damage)
