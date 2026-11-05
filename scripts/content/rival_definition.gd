extends Resource
## Shared rival content. A doctrine orders a newly prepared hand exactly once.

enum Doctrine { PRESSURE, BASTION, INTRIGUE }
@export var id: String
@export var display_name: String
@export var epithet: String
@export_multiline var description: String
@export var doctrine: Doctrine = Doctrine.PRESSURE
@export_range(1, 999) var health: int = 40
@export var accent: Color = Color("d88b78")
@export var cards: Array[CardDefinition] = []
@export var opening_line: Array[CardDefinition] = []
@export_multiline var opening_advice: String


func create_deck() -> Array[CardInstance]:
	var deck: Array[CardInstance] = []
	for definition in cards:
		deck.append(CardInstance.new(definition))
	return deck


func arrange_opening_draw(piles: CardPiles) -> void:
	if opening_line.is_empty():
		return
	if opening_line.size() != 5:
		push_warning("%s needs five cards in its opening line." % display_name)
		return
	var remaining := piles.draw_pile.duplicate()
	var selected: Array[CardInstance] = []
	for definition in opening_line:
		var index := remaining.find_custom(func(card: CardInstance): return card.definition == definition)
		if index < 0:
			push_warning("%s has an opening card missing from its deck." % display_name)
			return
		selected.append(remaining.pop_at(index))
	selected.reverse()
	remaining.append_array(selected)
	piles.draw_pile.assign(remaining)


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
