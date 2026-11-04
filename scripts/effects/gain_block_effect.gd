class_name GainBlockEffect
extends CardEffect

@export_range(0, 999) var block_amount: int = 8


func execute(source: Combatant, _target: Combatant, _context: EffectContext = null) -> void:
	source.gain_block(block_amount)


func describe(_damage_bonus: int = 0) -> String:
	return "Gain %d block." % block_amount
