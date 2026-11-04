class_name HealEffect
extends CardEffect

@export_range(0, 999) var amount: int = 6


func execute(source: Combatant, _target: Combatant, _context: EffectContext = null) -> void:
	source.heal(amount)


func describe(_damage_bonus: int = 0) -> String:
	return "Heal up to %d HP." % amount
