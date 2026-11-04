class_name DrawEffect
extends CardEffect

@export_range(0, 10) var amount: int = 2


func execute(_source: Combatant, _target: Combatant, context: EffectContext = null) -> void:
	if context != null:
		context.piles.draw_cards(amount)


func describe(_damage_bonus: int = 0) -> String:
	return "Draw up to %d %s." % [amount, "card" if amount == 1 else "cards"]
