class_name DamageEffect
extends CardEffect

@export_range(0, 999) var damage: int = 10


func execute(_source: Combatant, target: Combatant, context: EffectContext = null) -> void:
	target.take_damage(effective_damage(context.damage_bonus if context != null else 0))


func effective_damage(bonus: int = 0) -> int:
	return maxi(0, damage + bonus)


func describe(damage_bonus: int = 0) -> String:
	return "Deal %d damage." % effective_damage(damage_bonus)
