class_name GainBlockEffect
extends CardEffect

@export_range(0, 999) var block_amount: int = 8


func execute(source: Combatant, _target: Combatant) -> void:
	source.gain_block(block_amount)
