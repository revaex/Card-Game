extends RefCounted
## Per-encounter state. Each Strike adds +1 before its damage resolves.

var damage_bonus: int = 0


func before_card(card: CardInstance) -> bool:
	if card.definition.id != &"strike":
		return false
	damage_bonus += 1
	return true


func preview_bonus(card: CardInstance) -> int:
	return damage_bonus + (1 if card.definition.id == &"strike" else 0)
