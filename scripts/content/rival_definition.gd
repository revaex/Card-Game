extends Resource
## Shared rival content. A doctrine orders a newly prepared hand exactly once.

enum Doctrine { PRESSURE, BASTION, INTRIGUE }
@export var id: String
@export var display_name: String
@export var route_region: String
@export var epithet: String
@export_multiline var description: String
@export var doctrine: Doctrine = Doctrine.PRESSURE
@export_range(1, 999) var health: int = 40
@export var accent: Color = Color("d88b78")
@export var cards: Array[CardDefinition] = []
@export var opening_line: Array[CardDefinition] = []
@export_multiline var opening_advice: String
@export_range(0, 999) var final_phase_health: int = 0
@export var final_phase_name: String = "Final revision"
@export var final_phase_doctrine: Doctrine = Doctrine.PRESSURE
@export var final_phase_anchor: bool = false


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


func doctrine_text(final_phase: bool = false) -> String:
	match final_phase_doctrine if final_phase else doctrine:
		Doctrine.PRESSURE: return "Attack → Guard → Tactic"
		Doctrine.BASTION: return "Guard → Attack → Tactic"
		_: return "Tactic → Attack → Guard"


func final_phase_rules() -> String:
	return "%s · %s" % [doctrine_text(true), "First card sealed against Rewrite" if final_phase_anchor else "All cards remain rewritable"]


func arrange_hand(piles: CardPiles, final_phase: bool = false, carried_count: int = 0) -> void:
	var active_doctrine := final_phase_doctrine if final_phase else doctrine
	var priority: Array[int] = [0, 1, 2]
	if active_doctrine == Doctrine.BASTION:
		priority = [1, 0, 2]
	elif active_doctrine == Doctrine.INTRIGUE:
		priority = [2, 0, 1]
	var ordered: Array[CardInstance] = piles.hand.slice(0, carried_count)
	var fresh: Array[CardInstance] = piles.hand.slice(carried_count)
	for category in priority:
		for card in fresh:
			if card.get_category() == category:
				ordered.append(card)
	piles.hand.assign(ordered)
