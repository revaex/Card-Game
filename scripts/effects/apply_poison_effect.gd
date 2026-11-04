class_name ApplyPoisonEffect
extends CardEffect
## Shared application amount; stacks live on the target Combatant.

@export_range(0, 999) var stacks: int = 3


func execute(_source: Combatant, target: Combatant, _context: EffectContext = null) -> void:
	target.apply_poison(stacks)


func describe(_damage_bonus: int = 0) -> String:
	return "Apply %d Poison." % stacks
