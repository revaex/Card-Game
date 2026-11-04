class_name EffectContext
extends RefCounted
## One card resolution. Shared effect Resources never retain this state.

var piles: CardPiles
var damage_bonus: int = 0


func _init(actor_piles: CardPiles, bonus: int = 0) -> void:
	piles = actor_piles
	damage_bonus = bonus
