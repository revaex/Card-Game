extends Resource
## Shared rival content. A doctrine orders a newly prepared hand exactly once.

enum Doctrine { PRESSURE, BASTION, INTRIGUE }
@export var display_name: String
@export var epithet: String
@export_multiline var description: String
@export var doctrine: Doctrine = Doctrine.PRESSURE
@export_range(1, 999) var health: int = 40
@export var accent: Color = Color("d88b78")
@export var cards: Array[CardDefinition] = []


func create_deck() -> Array[CardInstance]:
	var deck: Array[CardInstance] = []
	for definition in cards:
		deck.append(CardInstance.new(definition))
	return deck


func doctrine_text() -> String:
	match doctrine:
		Doctrine.PRESSURE: return "Attack → Guard → Tactic"
		Doctrine.BASTION: return "Guard → Attack → Tactic"
		_: return "Tactic → Attack → Guard"


func arrange_hand(piles: CardPiles) -> void:
	var priority: Array[int] = [0, 1, 2]
	if doctrine == Doctrine.BASTION:
		priority = [1, 0, 2]
	elif doctrine == Doctrine.INTRIGUE:
		priority = [2, 0, 1]
	var ordered: Array[CardInstance] = []
	for category in priority:
		for card in piles.hand:
			if card.get_category() == category:
				ordered.append(card)
	piles.hand.assign(ordered)
