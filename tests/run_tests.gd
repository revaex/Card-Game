extends SceneTree
## Run with --headless --path . --script res://tests/run_tests.gd

var failures: int = 0
var checks: int = 0
const Session = preload("res://scripts/combat/combat_session.gd")


func _initialize() -> void:
	test_cards_and_piles()
	test_combatant()
	test_four_remaining()
	test_effects_and_combat()
	print("Backend checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func test_cards_and_piles() -> void:
	var deck := StarterDeck.create()
	var second_deck := StarterDeck.create()
	check(deck.size() == 10, "Starter deck size")
	check(deck[0] != second_deck[0], "Decks use independent instances")
	deck[0].cost_modifier = -5
	check(deck[0].get_energy_cost() == 0, "Cost clamps to zero")
	check(deck[1].get_energy_cost() == 1, "Modifiers are independent")
	check(deck[0].definition.energy_cost == 1, "Definition remains unchanged")
	var piles := CardPiles.new(deck, false)
	var events: Array[CardInstance] = []
	# Capture only the array to avoid a RefCounted self-reference cycle.
	piles.card_drawn.connect(func(card: CardInstance) -> void: events.append(card))
	var exhausted := piles.draw_card()
	piles.exhaust_card(exhausted)
	piles.discard_card(exhausted)
	check(piles.exhaust_pile.size() == 1 and piles.discard_pile.is_empty(), "Invalid discard changes nothing")
	piles.reshuffle_discard_into_draw()
	check(piles.draw_pile.size() == 9, "Reshuffle preserves nonempty draw pile")
	for index in range(9):
		piles.draw_card()
	piles.discard_hand()
	check(piles.hand.is_empty() and piles.discard_pile.size() == 9, "Whole hand moves to discard")
	for index in range(9):
		piles.draw_card()
	check(piles.draw_card() == null, "Empty piles return null")
	check(events.size() == 19, "Failed draw emits no signal")
	check(piles.hand.size() == 9 and piles.exhaust_pile == [exhausted], "Recycling excludes exhausted card")
	check(deck.size() == 10, "Pile movement preserves original array")
	for card in deck:
		var occurrences := piles.hand.count(card) + piles.draw_pile.count(card)
		occurrences += piles.discard_pile.count(card) + piles.exhaust_pile.count(card)
		check(occurrences == 1, "Each instance exists in exactly one pile")
	var discarded_events: Array[CardInstance] = []
	var exhausted_events: Array[CardInstance] = []
	piles.card_discarded.connect(func(card: CardInstance) -> void: discarded_events.append(card))
	piles.card_exhausted.connect(func(card: CardInstance) -> void: exhausted_events.append(card))
	var discarded_card: CardInstance = piles.hand[0]
	piles.discard_card(discarded_card)
	piles.discard_card(discarded_card)
	check(discarded_events == [discarded_card], "Individual discard emits once; invalid repeat emits nothing")
	var exhausted_card: CardInstance = piles.hand[0]
	piles.exhaust_card(exhausted_card)
	check(exhausted_events == [exhausted_card], "Exhaust notifies observers")
	piles.discard_hand()
	check(discarded_events.size() == 8 and piles.hand.is_empty(), "Bulk discard notifies for each moved card")


func test_combatant() -> void:
	var actor := Combatant.new(30)
	var observations: Array = []
	# Bound argument identifies the sender without capturing it in a lambda.
	actor.health_changed.connect(record_change.bind(actor, observations))
	actor.block_changed.connect(record_change.bind(actor, observations))
	actor.gain_block(5)
	observations.clear()
	actor.take_damage(5)
	check(actor.health == 30 and actor.block == 0, "Exact block absorption")
	check(observations.size() == 1, "Exact absorption emits only block change")
	actor.gain_block(5)
	observations.clear()
	actor.take_damage(8)
	check(observations == [Vector2i(27, 0), Vector2i(27, 0)], "Observers see both final values")
	actor.take_damage(100)
	check(actor.is_dead() and actor.health == 0, "Lethal damage clamps health")
	observations.clear()
	actor.take_damage(1)
	actor.take_damage(-1)
	actor.gain_block(5)
	actor.clear_block()
	check(observations.is_empty(), "Dead or unchanged operations emit no change signals")
	# Disconnect bound references explicitly at the end of this test.
	for connection in actor.health_changed.get_connections():
		actor.health_changed.disconnect(connection.callable)
	for connection in actor.block_changed.get_connections():
		actor.block_changed.disconnect(connection.callable)


func record_change(_previous: int, _current: int, actor: Combatant, observations: Array) -> void:
	observations.append(Vector2i(actor.health, actor.block))


func test_four_remaining() -> void:
	var deck := StarterDeck.create()
	var piles := CardPiles.new(deck, false)
	for index in range(6):
		piles.exhaust_card(piles.draw_card())
	for cycle in range(4):
		piles.discard_hand()
		var drawn := piles.draw_cards(5)
		check(drawn.size() == 4, "Batch draw reports only four actual draws")
		check(piles.hand.size() == 4, "Six exhausted: draw five must return only four cards")
		check(piles.exhaust_pile.size() == 6, "Six exhausted cards remain exhausted")
		for card in deck:
			check(piles.hand.count(card) + piles.draw_pile.count(card) + piles.discard_pile.count(card) + piles.exhaust_pile.count(card) == 1, "Draw-five preserves unique membership")


func copies(definition: CardDefinition, amount: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index in range(amount):
		cards.append(CardInstance.new(definition))
	return cards


func test_effects_and_combat() -> void:
	var source := Combatant.new(30)
	var target := Combatant.new(40)
	for effect in StarterDeck.STRIKE.effects:
		effect.execute(source, target)
	for effect in StarterDeck.BLOCK.effects:
		effect.execute(source, target)
	check(source.block == 8 and target.health == 30, "Editor-authored Strike and Block execute")
	var combined := CardDefinition.new()
	combined.effects.assign([StarterDeck.STRIKE.effects[0], StarterDeck.BLOCK.effects[0]])
	for effect in combined.effects:
		effect.execute(source, target)
	check(source.block == 16 and target.health == 20, "Effects compose without card-ID conditionals")
	var session = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.STRIKE, 5), false)
	var first: CardInstance = session.player_piles.hand[0]
	check(session.play_card(first), "Play from hand succeeds")
	check(session.energy == 2 and session.player.block == 8, "Play spends energy and applies effect")
	check(not session.play_card(first) and session.energy == 2, "Repeated play cannot spend or execute again")
	check(session.player_piles.discard_pile.has(first), "Played card moves into discard")
	for index in range(2):
		session.play_card(session.player_piles.hand[0])
	check(not session.play_card(session.player_piles.hand[0]), "Insufficient energy rejects play")
	check(session.player.block == 24, "Three blocks stack")
	session.end_turn()
	check(session.player.health == 24, "Enemy spends 3 energy; block absorbs 24 of 30 damage")
	check(session.player.block == 0 and session.energy == 3 and session.round_number == 2, "New turn resets block and energy")
	check(session.player_piles.hand.size() == 5, "New hand recycles played and unplayed cards")
	check(session.player_piles.total_cards() == 5 and session.enemy_piles.total_cards() == 5, "Turns preserve both rosters")
	var victory = Session.new(copies(StarterDeck.STRIKE, 4), copies(StarterDeck.BLOCK, 4), false)
	victory.enemy.take_damage(30)
	victory.play_card(victory.player_piles.hand[0])
	check(victory.outcome == "Victory", "Lethal card ends encounter")
	var remaining := int(victory.player_piles.hand.size())
	victory.end_turn()
	check(victory.round_number == 1 and victory.player_piles.hand.size() == remaining, "No turns after victory")
	check(not victory.play_card(victory.player_piles.hand[0]), "No plays after victory")
	var defeat = Session.new(copies(StarterDeck.BLOCK, 4), copies(StarterDeck.STRIKE, 5), false)
	defeat.end_turn()
	check(defeat.outcome == "Defeat" and defeat.player.health == 0, "Enemy lethal damage ends encounter")
	check(not defeat.player_turn, "Defeat does not start another player turn")
