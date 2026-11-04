class_name StarterDeck
extends RefCounted
## Starter content. Each call creates independent runtime copies.

const STRIKE: CardDefinition = preload("res://data/cards/strike.tres")
const BLOCK: CardDefinition = preload("res://data/cards/block.tres")


static func create() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index in range(5):
		cards.append(CardInstance.new(STRIKE))
	for index in range(5):
		cards.append(CardInstance.new(BLOCK))
	return cards
