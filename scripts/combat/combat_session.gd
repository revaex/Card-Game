extends RefCounted
## Owns encounter rules; the UI requests actions and observes completed changes.

signal changed
signal card_played(card: CardInstance, by_player: bool)

const ENERGY_PER_TURN: int = 3
var player := Combatant.new(30)
var enemy := Combatant.new(40)
var player_piles: CardPiles
var enemy_piles: CardPiles
var energy: int = ENERGY_PER_TURN
var round_number: int = 1
var player_turn: bool = true
var outcome: String = ""
var history: Array[String] = []
var _resolving: bool = false


func _init(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], shuffle: bool = true) -> void:
	player_piles = CardPiles.new(player_cards, shuffle)
	enemy_piles = CardPiles.new(enemy_cards, shuffle)
	player_piles.draw_cards(5)
	log_event("Your turn. Play cards, then end turn.")


func log_event(text: String) -> void:
	history.append(text)
	if history.size() > 30:
		history.pop_front()


func can_play(card: CardInstance) -> bool:
	return not _resolving and outcome.is_empty() and player_turn and card != null and player_piles.hand.has(card) and energy >= card.get_energy_cost() and not card.definition.effects.is_empty()


func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	_resolving = true
	energy -= card.get_energy_cost()
	resolve_card(card, player, enemy, player_piles, true)
	_resolving = false
	changed.emit()
	return true


func resolve_card(card: CardInstance, source: Combatant, target: Combatant, piles: CardPiles, by_player: bool) -> void:
	# Remove from hand before effects; the same copy cannot be played twice.
	piles.discard_card(card)
	for effect in card.definition.effects:
		if effect != null:
			effect.execute(source, target)
	log_event("%s played %s." % ["You" if by_player else "Rival", card.definition.display_name])
	if enemy.is_dead():
		outcome = "Victory"
	elif player.is_dead():
		outcome = "Defeat"
	card_played.emit(card, by_player)


func end_turn() -> void:
	if _resolving or not player_turn or not outcome.is_empty():
		return
	_resolving = true
	player_turn = false
	player_piles.discard_hand()
	enemy.clear_block()
	enemy_piles.draw_cards(5)
	var enemy_energy := ENERGY_PER_TURN
	# Deterministic simple policy: play affordable cards in hand order.
	for card in enemy_piles.hand.duplicate():
		if not outcome.is_empty():
			break
		if card.get_energy_cost() <= enemy_energy and not card.definition.effects.is_empty():
			enemy_energy -= card.get_energy_cost()
			resolve_card(card, enemy, player, enemy_piles, false)
	enemy_piles.discard_hand()
	if outcome.is_empty():
		round_number += 1
		player.clear_block()
		energy = ENERGY_PER_TURN
		player_piles.draw_cards(5)
		player_turn = true
		log_event("Turn %d. Energy restored." % round_number)
	_resolving = false
	changed.emit()
