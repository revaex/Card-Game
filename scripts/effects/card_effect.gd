class_name CardEffect
extends Resource
## Shared configuration. Never store a combatant or encounter state here.


func execute(_source: Combatant, _target: Combatant, _context: EffectContext = null) -> void:
	pass


func describe(_damage_bonus: int = 0) -> String:
	return ""
