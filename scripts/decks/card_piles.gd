class_name CardPiles
extends RefCounted

signal card_drawn(card: CardInstance)
signal card_discarded(card: CardInstance)
signal card_exhausted(card: CardInstance)

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []


func _init(cards: Array[CardInstance], shuffle: bool = true) -> void:
	draw_pile = cards.duplicate()
	if shuffle:
		draw_pile.shuffle()


func draw_card() -> CardInstance:
	if draw_pile.is_empty():
		reshuffle_discard_into_draw()
		if draw_pile.is_empty():
			return null
	var drawn_card: CardInstance = draw_pile.pop_back()
	hand.append(drawn_card)
	card_drawn.emit(drawn_card)
	return drawn_card

func discard_card(card: CardInstance) -> void:
	if card == null or not hand.has(card):
		return
	hand.erase(card)
	discard_pile.append(card)
	card_discarded.emit(card)


func draw_cards(amount: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	# Snapshot drawable cards: never include cards already in hand or exhausted.
	var limit := mini(maxi(amount, 0), draw_pile.size() + discard_pile.size())
	for index in range(limit):
		var card := draw_card()
		if card == null:
			break
		drawn.append(card)
	return drawn


func total_cards() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhaust_pile.size()


func exhaust_card(card: CardInstance) -> void:
	if card == null or not hand.has(card):
		return
	hand.erase(card)
	exhaust_pile.append(card)
	card_exhausted.emit(card)


func discard_hand() -> void:
	var discarded := hand.duplicate()
	discard_pile.append_array(discarded)
	hand.clear()
	# Notify only after the complete move is committed.
	for card in discarded:
		card_discarded.emit(card)


func reshuffle_discard_into_draw() -> void:
	if not draw_pile.is_empty() or discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
