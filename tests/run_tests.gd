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
	test_new_effects_and_artifact()
	test_enemy_intent()
	test_poison()
	test_stepped_turns()
	test_live_previews_and_statistics()
	test_cadence_and_rewrite()
	test_patterns()
	test_rival_doctrines()
	test_journey()
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


func test_new_effects_and_artifact() -> void:
	var mend: CardDefinition = load("res://data/cards/mend.tres")
	var insight: CardDefinition = load("res://data/cards/insight.tres")
	var siphon: CardDefinition = load("res://data/cards/siphon.tres")
	var actor := Combatant.new(30)
	actor.take_damage(3)
	mend.effects[0].execute(actor, actor)
	check(actor.health == 30, "Healing clamps to maximum HP")
	actor.take_damage(99)
	mend.effects[0].execute(actor, actor)
	check(actor.health == 0, "Healing does not revive a defeated actor")
	var draw_session = Session.new(copies(insight, 1), copies(StarterDeck.BLOCK, 5), false)
	draw_session.play_card(draw_session.player_piles.hand[0])
	check(draw_session.player_piles.hand.is_empty(), "Insight cannot draw its own resolving copy")
	check(draw_session.player_piles.total_cards() == 1, "Resolving draw conserves cards")
	check(draw_session.history.has("  You drew 0 cards."), "Log reports actual draw count")
	var cards := copies(StarterDeck.BLOCK, 6)
	cards.append(CardInstance.new(insight))
	var draws = Session.new(cards, copies(StarterDeck.BLOCK, 5), false)
	draws.play_card(draws.player_piles.hand[0])
	check(draws.player_piles.hand.size() == 6, "Insight draws two available cards")
	var drum = Session.new(copies(StarterDeck.STRIKE, 5), copies(StarterDeck.BLOCK, 5), false, true)
	drum.play_card(drum.player_piles.hand[0])
	drum.play_card(drum.player_piles.hand[0])
	check(drum.enemy.health == 17 and drum.war_drum.damage_bonus == 2, "War Drum adds before damage and stacks")
	check(StarterDeck.STRIKE.effects[0].damage == 10, "Artifact never mutates shared damage Resources")
	var fresh = Session.new(copies(StarterDeck.STRIKE, 5), copies(StarterDeck.BLOCK, 5), false, true)
	check(fresh.war_drum.damage_bonus == 0, "Artifact state is independent for each encounter")
	var drain = Session.new(copies(siphon, 1), copies(StarterDeck.BLOCK, 5), false)
	drain.player.take_damage(10)
	drain.enemy.take_damage(35)
	drain.play_card(drain.player_piles.hand[0])
	check(drain.player.health == 23 and drain.outcome == "Victory", "Composed healing still resolves after lethal damage")
	check(drain.history.has("  Rival: 5 HP lost, 0 blocked."), "Log records actual damage")
	for index in range(220):
		drain.log_event(str(index))
	check(drain.history.size() == 200 and drain.history[-1] == "219", "Combat history keeps the most recent 200 entries")


func record_enemy_play(card: CardInstance, by_player: bool, observed: Array[CardInstance]) -> void:
	if not by_player:
		observed.append(card)


func test_enemy_intent() -> void:
	var session = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.BLOCK, 7), false)
	var before: Array[CardInstance] = session.enemy_piles.hand.duplicate()
	var history_size: int = session.history.size()
	var plan: Array[CardInstance] = session.enemy_opening_plan()
	check(plan.size() == 3, "Rival intent respects its three-energy budget")
	check(session.enemy_opening_plan() == plan, "Repeated intent previews are stable")
	check(session.enemy_piles.hand == before and session.history.size() == history_size, "Preview does not mutate hand or history")
	var observed: Array[CardInstance] = []
	session.card_played.connect(record_enemy_play.bind(observed))
	session.end_turn()
	check(observed == plan, "Rival plays the cards shown in its opening plan")
	check(session.enemy_piles.hand.size() == 5 and session.enemy_piles.total_cards() == 7, "Next turn prepares a fresh conserved hand")
	var expensive := CardDefinition.new()
	expensive.energy_cost = 4
	expensive.effects.assign(StarterDeck.STRIKE.effects)
	var cards := copies(StarterDeck.STRIKE, 2)
	cards.append_array(copies(expensive, 4))
	cards.append(CardInstance.new(load("res://data/cards/insight.tres")))
	var draws = Session.new(copies(StarterDeck.BLOCK, 5), cards, false)
	check(draws.enemy_opening_plan().size() == 1, "Preview skips unaffordable cards")
	draws.end_turn()
	check(draws.player.health == 10, "Rival uses newly drawn attacks within remaining energy")
	check(draws.enemy_piles.total_cards() == 7, "Rival draw effects preserve card count")
	var empty = Session.new(copies(StarterDeck.BLOCK, 5), copies(expensive, 1), false)
	check(empty.enemy_opening_plan().is_empty(), "No affordable cards yields a pass intent")
	empty.outcome = "Victory"
	check(empty.enemy_opening_plan().is_empty(), "Finished encounters have no rival intent")


func observe_poison(_previous: int, _current: int, actor: Combatant, observations: Array) -> void:
	observations.append(Vector3i(actor.health, actor.block, actor.poison))


func test_poison() -> void:
	var venom: CardDefinition = load("res://data/cards/venom.tres")
	var actor := Combatant.new(30)
	actor.gain_block(8)
	venom.effects[0].execute(Combatant.new(30), actor)
	check(actor.poison == 3 and actor.health == 30, "Poison application stores stacks without immediate damage")
	actor.apply_poison(2)
	actor.apply_poison(-4)
	check(actor.poison == 5, "Poison stacks add; invalid amounts do nothing")
	var observations: Array = []
	actor.poison_changed.connect(observe_poison.bind(actor, observations))
	actor.health_changed.connect(observe_poison.bind(actor, observations))
	check(actor.tick_poison() == 5 and actor.block == 8, "Poison bypasses block without consuming it")
	check(observations == [Vector3i(25, 8, 4), Vector3i(25, 8, 4)], "Poison observers see final HP and stacks")
	for connection in actor.poison_changed.get_connections():
		actor.poison_changed.disconnect(connection.callable)
	for connection in actor.health_changed.get_connections():
		actor.health_changed.disconnect(connection.callable)
	for index in range(4):
		actor.tick_poison()
	check(actor.health == 15 and actor.poison == 0, "Poison decreases by one until exhausted")
	check(actor.tick_poison() == 0 and actor.health == 15, "Expired Poison does not tick")
	var session = Session.new(copies(venom, 5), copies(StarterDeck.BLOCK, 5), false)
	session.play_card(session.player_piles.hand[0])
	check(session.enemy.poison == 3 and session.enemy.health == 40, "Venom card applies status through normal card resolution")
	session.end_turn()
	check(session.enemy.health == 37 and session.enemy.poison == 2, "Rival Poison ticks at rival turn start")
	check(session.player.health == 30 and session.player.poison == 0, "Poison is isolated to its combatant")
	check(session.history.has("Rival: Poison dealt 3 HP damage; 2 stacks remain."), "Poison result enters combat history")
	var retaliate = Session.new(copies(StarterDeck.BLOCK, 5), copies(venom, 5), false)
	retaliate.end_turn()
	check(retaliate.player.health == 21 and retaliate.player.poison == 8, "Three rival Venoms stack then tick at player turn start")
	retaliate.end_turn()
	check(retaliate.enemy.health == 40, "Player Poison never ticks against rival")
	var victory = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.STRIKE, 5), false)
	victory.enemy.take_damage(38)
	victory.enemy.apply_poison(5)
	check(victory.enemy_opening_plan().is_empty(), "Lethal Poison removes rival card intent before its turn")
	victory.end_turn()
	check(victory.outcome == "Victory" and victory.player.health == 30, "Lethal rival Poison ends combat before rival acts")
	check(victory.enemy.health == 0 and victory.enemy.poison == 4, "Lethal Poison clamps HP and removes one stack")
	var remaining: int = victory.history.size()
	victory.end_turn()
	check(victory.history.size() == remaining, "No further Poison ticks after combat ends")
	victory.enemy.apply_poison(2)
	check(victory.enemy.poison == 4 and victory.enemy.tick_poison() == 0, "Defeated combatants cannot gain or tick Poison")
	var defeat = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.BLOCK, 5), false)
	defeat.player.apply_poison(40)
	defeat.end_turn()
	check(defeat.outcome == "Defeat" and not defeat.player_turn, "Lethal player Poison prevents another player turn")
	check(defeat.player_piles.hand.is_empty(), "Lethal turn-start Poison prevents drawing a new hand")
	check(not defeat.play_card(CardInstance.new(venom)), "No card play after Poison defeat")
	var fresh = Session.new(copies(venom, 1), copies(venom, 1), false)
	check(fresh.player.poison == 0 and fresh.enemy.poison == 0, "New encounters have independent status state")
	check(venom.effects[0].stacks == 3, "Poison gameplay never changes shared effect configuration")


func test_stepped_turns() -> void:
	var session = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.STRIKE, 5), false)
	check(not session.advance_rival_turn(), "Cannot step rival actions during player turn")
	check(session.begin_rival_turn(), "Player can start a stepped rival turn")
	check(session.player.health == 30 and not session.player_turn, "Beginning rival turn does not play any cards")
	check(not session.begin_rival_turn(), "Repeated end turn cannot restart rival turn")
	check(not session.play_card(CardInstance.new(StarterDeck.BLOCK)), "Player actions are rejected between rival steps")
	check(session.advance_rival_turn() and session.player.health == 20 and session.enemy_energy == 2, "One step resolves exactly one card")
	check(session.enemy_opening_plan().size() == 2, "Mid-turn preview uses remaining rival energy")
	session.advance_rival_turn()
	check(session.player.health == 10 and not session.player_turn, "Second step remains a rival turn")
	session.advance_rival_turn()
	check(session.outcome == "Defeat", "Stepped lethal card ends combat immediately")
	check(not session.advance_rival_turn(), "No stepped actions after combat ends")
	var blocks = Session.new(copies(StarterDeck.BLOCK, 5), copies(StarterDeck.BLOCK, 5), false)
	blocks.begin_rival_turn()
	for index in range(3):
		blocks.advance_rival_turn()
	check(not blocks.player_turn and blocks.enemy.block == 24, "All rival cards remain visible before turn transition")
	check(not blocks.advance_rival_turn() and blocks.player_turn and blocks.round_number == 2, "Final step restores player turn and prepares hands")
	check(blocks.player_piles.hand.size() == 5 and blocks.enemy_piles.hand.size() == 5, "Stepped turns prepare both hands")


func test_live_previews_and_statistics() -> void:
	var session = Session.new(copies(StarterDeck.STRIKE, 5), copies(StarterDeck.BLOCK, 5), false, true)
	session.enemy.gain_block(4)
	var card: CardInstance = session.player_piles.hand[0]
	var preview: Dictionary = session.preview_attack(card)
	check(session.describe_card(card) == "Deal 11 damage.", "Card text includes War Drum's pending Strike trigger")
	check(preview.damage == 11 and preview.hp_loss == 7 and preview.blocked == 4, "Attack forecast separates HP damage and absorption")
	var history_before: int = session.history.size()
	for index in range(3):
		session.preview_attack(card)
		session.describe_card(card)
	check(session.war_drum.damage_bonus == 0 and session.enemy.health == 40 and session.enemy.block == 4, "Preview leaves runtime state untouched")
	check(session.history.size() == history_before and session.statistics.player.cards == 0, "Preview does not add logs or statistics")
	session.play_card(card)
	check(session.enemy.health == preview.remaining_hp and session.enemy.block == preview.remaining_block, "Resolved attack matches forecast")
	check(session.statistics.player.cards == 1 and session.statistics.player.energy == 1, "Play tracks cards and energy")
	check(session.statistics.player.damage == 7 and session.statistics.enemy.absorbed == 4, "Statistics count HP loss and real blocked damage separately")
	check(session.last_action.description == "Deal 11 damage.", "Last action retains the resolved bonus rather than predicting another trigger")
	check(session.describe_card(session.player_piles.hand[0]) == "Deal 12 damage.", "Remaining Strike text refreshes after artifact stacks")
	var siphon: CardDefinition = load("res://data/cards/siphon.tres")
	var combined := CardDefinition.new()
	combined.effects.assign([StarterDeck.STRIKE.effects[0], siphon.effects[0]])
	var multi = Session.new(copies(combined, 1), copies(StarterDeck.BLOCK, 1), false)
	multi.enemy.take_damage(28)
	multi.enemy.gain_block(2)
	var multi_card: CardInstance = multi.player_piles.hand[0]
	var forecast: Dictionary = multi.preview_attack(multi_card)
	check(forecast.lethal and forecast.hp_loss == 12 and forecast.blocked == 2, "Multi-hit forecast consumes block once and caps HP loss")
	multi.play_card(multi_card)
	check(multi.enemy.health == forecast.remaining_hp and multi.outcome == "Victory", "Multi-effect lethal preview matches combat")
	var heal = Session.new(copies(siphon, 1), copies(StarterDeck.BLOCK, 5), false)
	heal.player.take_damage(1)
	heal.play_card(heal.player_piles.hand[0])
	check(heal.statistics.player.healed == 1, "Statistics count actual healing rather than configured maximum")
	var venom: CardDefinition = load("res://data/cards/venom.tres")
	var poison = Session.new(copies(venom, 1), copies(StarterDeck.BLOCK, 5), false)
	poison.play_card(poison.player_piles.hand[0])
	poison.end_turn()
	check(poison.statistics.player.poison_applied == 3 and poison.statistics.player.damage == 3, "Poison application and tick damage enter statistics")
	var summary: Dictionary = session.combat_summary()
	summary.statistics.player.cards = 999
	check(session.statistics.player.cards == 1, "Summary is an independent snapshot")
	var fresh = Session.new(copies(StarterDeck.STRIKE, 1), copies(StarterDeck.BLOCK, 1), false, true)
	check(fresh.statistics.player.cards == 0 and fresh.war_drum.damage_bonus == 0 and fresh.last_action.is_empty(), "New encounter resets all action and summary state")
	check(StarterDeck.STRIKE.effects[0].damage == 10, "Live descriptions never rewrite shared card Resources")


func test_cadence_and_rewrite() -> void:
	var player_cards := copies(StarterDeck.STRIKE, 3)
	player_cards.append_array(copies(StarterDeck.BLOCK, 2))
	var enemy_cards := copies(StarterDeck.BLOCK, 3)
	enemy_cards.append_array(copies(StarterDeck.STRIKE, 2))
	var session = Session.new(player_cards, enemy_cards, false)
	var first_enemy: CardInstance = session.enemy_piles.hand[0]
	check(not session.rewrite_intent(first_enemy), "Rewrite requires enough Cadence")
	var first_attack: CardInstance = session.player_piles.hand[2]
	check(session.cadence_gain(first_attack) == 1 and session.cadence == 0, "First-card Cadence preview is read-only")
	session.play_card(first_attack)
	check(session.cadence == 1, "First card of the turn earns one Cadence")
	session.play_card(session.player_piles.hand[2])
	check(session.cadence == 1, "Repeating Attack does not earn Cadence")
	session.play_card(session.player_piles.hand[0])
	check(session.cadence == 2, "Changing Attack to Guard earns Cadence")
	var roster: Array[CardInstance] = session.enemy_piles.hand.duplicate()
	var energy_before: int = session.energy
	check(not session.rewrite_intent(session.enemy_piles.hand[-1]) and session.cadence == 2, "No-op rewrite of last card spends nothing")
	check(not session.rewrite_intent(CardInstance.new(StarterDeck.STRIKE)), "Foreign card cannot be rewritten")
	check(session.rewrite_intent(first_enemy), "Valid Rewrite succeeds at zero energy")
	check(session.cadence == 0 and session.energy == energy_before and session.rewrote_this_turn, "Rewrite spends only Cadence and locks the turn's rewrite")
	check(session.enemy_piles.hand[-1] == first_enemy, "Rewrite moves chosen copy to the back")
	for card in roster:
		check(session.enemy_piles.hand.count(card) == 1, "Rewrite preserves every enemy card exactly once")
	var changed_plan: Array[CardInstance] = session.enemy_opening_plan()
	check(not changed_plan.has(first_enemy) and changed_plan.size() == 3, "Rewrite changes the affordable opening sequence")
	session.cadence = 3
	check(not session.rewrite_intent(session.enemy_piles.hand[0]), "Only one rewrite is allowed per turn even with more Cadence")
	session.begin_rival_turn()
	check(not session.rewrite_intent(session.enemy_piles.hand[0]), "Cannot rewrite during rival execution")
	while not session.player_turn and session.outcome.is_empty():
		session.advance_rival_turn()
	check(session.player.health == 28, "Rival follows rewritten plan: one Strike instead of two, against eight block")
	check(not session.rewrote_this_turn and session.cadence == 3 and session.last_category == -1, "New turn resets rewrite/category while retaining Cadence")
	check(session.statistics.player.rewrites == 1, "Rewrite enters encounter statistics")
	session.cadence = 2
	check(session.can_rewrite(session.enemy_piles.hand[0]), "Rewrite becomes available again next turn")
	session.enemy.apply_poison(99)
	check(not session.can_rewrite(session.enemy_piles.hand[0]), "Lethal Poison blocks pointless rewrites")
	session.end_turn()
	check(not session.rewrite_intent(session.enemy_piles.hand[0]), "No rewrites after combat ends")
	var combo_cards := copies(StarterDeck.STRIKE, 2)
	combo_cards.append_array(copies(StarterDeck.BLOCK, 2))
	combo_cards.append(CardInstance.new(load("res://data/cards/mend.tres")))
	for card in combo_cards:
		card.cost_modifier = -1
	var cap = Session.new(combo_cards, copies(StarterDeck.BLOCK, 5), false)
	while not cap.player_piles.hand.is_empty():
		cap.play_card(cap.player_piles.hand[0])
	check(cap.cadence == 3, "Cadence never exceeds its cap")
	var fresh = Session.new(player_cards, enemy_cards, false)
	check(fresh.cadence == 0 and not fresh.rewrote_this_turn and fresh.last_category == -1, "New encounters reset Cadence state")
	var crosscut: CardDefinition = load("res://data/cards/crosscut.tres")
	var switchback: CardDefinition = load("res://data/cards/switchback.tres")
	check(crosscut.category == CardDefinition.Category.ATTACK and switchback.category == CardDefinition.Category.GUARD, "Combination cards declare their cadence categories")
	var combos := copies(StarterDeck.BLOCK, 5)
	combos.append(CardInstance.new(crosscut))
	combos.append(CardInstance.new(switchback))
	var combo = Session.new(combos, copies(StarterDeck.BLOCK, 5), false)
	combo.play_card(combo.player_piles.hand[0])
	combo.play_card(combo.player_piles.hand[0])
	check(combo.cadence == 2 and combo.player.block == 4 and combo.enemy.health == 33, "Combination cards execute effects and build Cadence")
	check(combo.player_piles.total_cards() == 7, "Combination draw cards conserve the deck")
	var spends = Session.new(StarterDeck.create(), copies(StarterDeck.BLOCK, 5), false)
	spends.cadence = 2
	check(spends.spend_cadence(Session.CadenceAction.BRACE) and spends.player.block == 4 and spends.cadence == 0 and spends.energy == 3, "Brace buys Block with Cadence alone")
	check(not spends.spend_cadence(Session.CadenceAction.DRAW), "Drawing requires enough Cadence")
	spends.cadence = 2
	check(spends.spend_cadence(Session.CadenceAction.DRAW) and spends.player_piles.hand.size() == 6 and spends.cadence == 0, "Cadence Draw moves one card into hand")
	var empty_draw = Session.new(copies(StarterDeck.STRIKE, 1), copies(StarterDeck.BLOCK, 5), false)
	empty_draw.cadence = 2
	check(not empty_draw.spend_cadence(Session.CadenceAction.DRAW) and empty_draw.cadence == 2, "An empty draw does not spend Cadence")
	empty_draw.begin_rival_turn()
	check(not empty_draw.spend_cadence(Session.CadenceAction.BRACE), "Cadence actions cannot be used during rival playback")


func pattern_cards(free: bool = false) -> Array[CardInstance]:
	var cards := copies(StarterDeck.STRIKE, 2)
	cards.append_array(copies(StarterDeck.BLOCK, 2))
	cards.append_array(copies(load("res://data/cards/mend.tres"), 2))
	if free:
		for card in cards:
			card.cost_modifier = -1
	return cards


func play_category(session: RefCounted, category: int) -> bool:
	for card in session.player_piles.hand:
		if card.definition.category == category:
			return session.play_card(card)
	return false


func test_patterns() -> void:
	var shelter = Session.new(pattern_cards(true), copies(StarterDeck.BLOCK, 5), false)
	play_category(shelter, CardDefinition.Category.ATTACK)
	play_category(shelter, CardDefinition.Category.GUARD)
	check(shelter.completed_pattern.is_empty(), "Two cards cannot complete a Pattern")
	check(shelter.rewrite_intent(shelter.enemy_piles.hand[0]), "Rewrite can happen between Pattern cards")
	play_category(shelter, CardDefinition.Category.TACTIC)
	check(shelter.completed_pattern == "Shelter" and shelter.player.block == 14, "Attack Guard Tactic adds six block, including after Rewrite")
	check(shelter.statistics.player.patterns == 1, "Completed Pattern enters statistics")
	shelter.player_piles.draw_card()
	play_category(shelter, CardDefinition.Category.GUARD)
	play_category(shelter, CardDefinition.Category.TACTIC)
	play_category(shelter, CardDefinition.Category.ATTACK)
	check(shelter.enemy.health == 20 and shelter.statistics.player.patterns == 1, "Only one Pattern can trigger each turn even with free cards")
	shelter.end_turn()
	check(shelter.completed_pattern.is_empty() and shelter.pattern_history.is_empty(), "New player turn clears Pattern progress")
	var riposte = Session.new(pattern_cards(), copies(StarterDeck.BLOCK, 5), false, true)
	play_category(riposte, CardDefinition.Category.GUARD)
	play_category(riposte, CardDefinition.Category.TACTIC)
	riposte.enemy.gain_block(5)
	var finisher: CardInstance = null
	for card in riposte.player_piles.hand:
		if card.definition.category == CardDefinition.Category.ATTACK:
			finisher = card
			break
	var preview: Dictionary = riposte.preview_attack(finisher)
	check(preview.damage == 17 and preview.hp_loss == 12 and preview.blocked == 5, "Riposte forecast combines six Pattern damage and one War Drum damage")
	check(riposte.describe_card(finisher) == "Deal 17 damage.", "Finishing card text includes Pattern bonus")
	check(riposte.completed_pattern.is_empty() and riposte.war_drum.damage_bonus == 0 and riposte.statistics.player.patterns == 0, "Pattern previews do not trigger rewards or stats")
	riposte.play_card(finisher)
	check(riposte.completed_pattern == "Riposte" and riposte.enemy.health == preview.remaining_hp, "Riposte resolution matches forecast")
	check(riposte.last_action.description == "Deal 17 damage.", "Last-action text retains finishing-card bonus")
	riposte.player_piles.draw_card()
	for card in riposte.player_piles.hand:
		if card.definition.category == CardDefinition.Category.ATTACK:
			check(riposte.describe_card(card) == "Deal 12 damage.", "Finishing bonus does not leak to later cards")
	var surge = Session.new(pattern_cards(), copies(StarterDeck.BLOCK, 5), false)
	play_category(surge, CardDefinition.Category.TACTIC)
	play_category(surge, CardDefinition.Category.ATTACK)
	play_category(surge, CardDefinition.Category.GUARD)
	check(surge.completed_pattern == "Surge" and surge.energy == 1, "Tactic Attack Guard refunds one energy")
	surge.player_piles.draw_card()
	check(play_category(surge, CardDefinition.Category.ATTACK) and surge.energy == 0, "Surge enables a fourth one-energy card")
	var reset = Session.new(pattern_cards(), copies(StarterDeck.BLOCK, 5), false)
	play_category(reset, CardDefinition.Category.ATTACK)
	play_category(reset, CardDefinition.Category.GUARD)
	reset.end_turn()
	play_category(reset, CardDefinition.Category.TACTIC)
	check(reset.completed_pattern.is_empty() and reset.pattern_history.size() == 1, "Sequences do not cross turn boundaries")
	var sliding = Session.new(pattern_cards(true), copies(StarterDeck.BLOCK, 5), false)
	play_category(sliding, CardDefinition.Category.GUARD)
	play_category(sliding, CardDefinition.Category.GUARD)
	play_category(sliding, CardDefinition.Category.TACTIC)
	play_category(sliding, CardDefinition.Category.ATTACK)
	check(sliding.completed_pattern == "Riposte", "An off-path repeat leaves the locked Pattern in progress")
	var locked = Session.new(pattern_cards(true), copies(StarterDeck.BLOCK, 5), false)
	locked.player_piles.draw_cards(1)
	for category in [CardDefinition.Category.ATTACK, CardDefinition.Category.TACTIC, CardDefinition.Category.ATTACK, CardDefinition.Category.GUARD]:
		play_category(locked, category)
	check(locked.active_pattern.display_name == "Shelter" and locked.completed_pattern.is_empty() and locked.pattern_history.size() == 2, "An off-path sequence cannot replace the first-card lock")
	locked.spend_cadence(Session.CadenceAction.BRACE)
	play_category(locked, CardDefinition.Category.TACTIC)
	check(locked.completed_pattern == "Shelter", "Spending Cadence leaves the locked Pattern intact")
	var fresh = Session.new(pattern_cards(), copies(StarterDeck.BLOCK, 5), false)
	check(fresh.pattern_history.is_empty() and fresh.completed_pattern.is_empty(), "Pattern state is encounter-local")
	check(Session.PATTERNS[1].finishing_damage == 6 and StarterDeck.STRIKE.effects[0].damage == 10, "Patterns never alter shared definitions")


func test_rival_doctrines() -> void:
	var catalog = load("res://scripts/content/rival_catalog.gd")
	for rival in catalog.ALL:
		var cards: Array[CardInstance] = rival.create_deck()
		var another: Array[CardInstance] = rival.create_deck()
		check(cards.size() == 10 and cards[0] != another[0], "Rival decks contain ten independent runtime copies")
		var session = Session.new(StarterDeck.create(), cards, false, false, rival)
		check(session.enemy.health == rival.health and session.enemy.max_health == rival.health, "Rival Resource configures encounter health")
		check(session.enemy_piles.hand.size() == 5 and session.enemy_piles.total_cards() == 10, "Rival preparation conserves its roster")
		var priority: Array[int] = []
		priority.assign([0, 1, 2] if rival.doctrine == 0 else ([1, 0, 2] if rival.doctrine == 1 else [2, 0, 1]))
		var previous_rank := -1
		for card in session.enemy_piles.hand:
			var rank := priority.find(card.definition.category)
			check(rank >= previous_rank, "Prepared hand follows the visible doctrine")
			previous_rank = rank
		var first: CardInstance = session.enemy_piles.hand[0]
		session.cadence = 2
		session.rewrite_intent(first)
		var rewritten: Array[CardInstance] = session.enemy_piles.hand.duplicate()
		check(rewritten[-1] == first, "Doctrine does not immediately undo Rewrite")
		var expected: Array[CardInstance] = session.enemy_opening_plan()
		var observed: Array[CardInstance] = []
		session.card_played.connect(record_enemy_play.bind(observed))
		session.player.gain_block(100)
		session.begin_rival_turn()
		check(session.enemy_piles.hand == rewritten, "Beginning rival turn preserves the revealed rewritten line")
		while not session.player_turn and session.outcome.is_empty():
			session.advance_rival_turn()
		check(observed.slice(0, expected.size()) == expected, "Rival executes the rewritten opening before any drawn follow-ups")
		check(session.enemy_piles.total_cards() == 10, "Rival turns retain all original card instances")
		if session.player_turn:
			previous_rank = -1
			for card in session.enemy_piles.hand:
				var rank := priority.find(card.definition.category)
				check(rank >= previous_rank, "Next prepared hand reapplies doctrine")
				previous_rank = rank
		check(rival.create_deck()[0].definition == cards[0].definition, "Rivals share definitions without sharing runtime cards")
	for example in [
		[1, [&"iron_seal", &"block"], [&"block", &"strike", &"strike"]],
		[2, [&"inkblot", &"venom"], [&"venom", &"insight", &"siphon"]],
	]:
		var rival: Resource = catalog.ALL[example[0]]
		var session = Session.new(StarterDeck.create(), rival.create_deck(), true, false, rival)
		check(session.enemy_opening_plan().map(func(card): return card.definition.id) == example[1], "Authored opening matches the briefing after a shuffled draw")
		session.cadence = 2
		session.rewrite_intent(session.enemy_piles.hand[0])
		check(session.enemy_opening_plan().map(func(card): return card.definition.id) == example[2], "Rewrite exposes the advertised risk or opportunity")


func test_journey() -> void:
	var Journey = load("res://scripts/combat/journey_state.gd")
	var original := pattern_cards()
	var journey = Journey.new(original, true)
	check(journey.roster[0] != original[0] and journey.roster[0].definition == original[0].definition, "Journey copies runtime cards while sharing definitions")
	check(not journey.reclassify(0, 1) and not journey.skip_reward(), "Rewards are unavailable before a win")
	var duel: RefCounted = journey.start_encounter()
	check(duel.player.health == 30 and duel.enemy.max_health == 36, "Journey begins against Duelist at full health")
	check(journey.start_encounter() == null and not journey.finish_encounter(duel), "Cannot start another encounter or record unfinished combat")
	duel.player.take_damage(15)
	duel.enemy.take_damage(999)
	duel.check_outcome()
	duel.statistics.player.cards = 2
	check(journey.finish_encounter(duel) and journey.health == 15 and journey.phase == Journey.Phase.REWARD, "Victory records remaining HP and opens one reward")
	check(not journey.finish_encounter(duel) and journey.summaries.size() == 1, "A result cannot be recorded twice")
	check(not journey.reclassify(-1, 1) and not journey.reclassify(0, 9) and not journey.reclassify(0, 0), "Invalid or unchanged category edits do not consume reward")
	check(journey.reclassify(0, 1) and journey.stage == 1, "A valid edit advances to the second rival")
	check(original[0].get_category() == 0 and original[0].definition.category == 0, "Journey edit leaves source cards and Resources unchanged")
	check(not journey.take_recovery() and not journey.reclassify(1, 1), "Cannot claim two rewards for one win")
	var next: RefCounted = journey.start_encounter()
	check(next.player.health == 15 and next.enemy.max_health == 46, "Second encounter carries health into Warden duel")
	next.player_piles.draw_cards(6)
	var revised: CardInstance = null
	for card in next.player_piles.hand:
		if card.category_override == 1:
			revised = card
			break
	check(revised != null and revised != journey.roster[0], "Edited card appears as an independent encounter copy")
	next.play_card(revised)
	check(next.last_category == 1 and next.pattern_history[0] == 1, "Cadence and Patterns use the revised category")
	play_category(next, CardDefinition.Category.TACTIC)
	play_category(next, CardDefinition.Category.ATTACK)
	check(next.completed_pattern == "Riposte", "Revised card can start a different Pattern")
	check(next.war_drum.damage_bonus >= 1, "Edited category preserves card effects and artifact identity")
	next.enemy.take_damage(999)
	next.check_outcome()
	var wounded_health: int = next.player.health
	journey.finish_encounter(next)
	var recovered_health := mini(30, wounded_health + 8)
	check(journey.take_recovery() and journey.health == recovered_health and journey.stage == 2, "Recovery heals eight HP and advances once")
	var finale: RefCounted = journey.start_encounter()
	check(finale.enemy.max_health == 32 and finale.war_drum.damage_bonus == 0 and finale.player.poison == 0 and finale.cadence == 0, "Scribe encounter resets combat-local states")
	check(finale.player.health == recovered_health, "Recovered HP is carried into final encounter")
	finale.enemy.take_damage(999)
	finale.check_outcome()
	journey.finish_encounter(finale)
	check(journey.phase == Journey.Phase.COMPLETE and journey.totals().wins == 3, "Three victories finish the journey")
	check(journey.start_encounter() == null and not journey.skip_reward(), "Completed journey cannot start another duel or claim another reward")
	check(journey.summaries[0].statistics.player.cards == 2, "Journey stores independent encounter summaries")
	var failed = Journey.new(StarterDeck.create(), false)
	var loss: RefCounted = failed.start_encounter()
	loss.player.take_damage(999)
	loss.check_outcome()
	failed.finish_encounter(loss)
	check(failed.phase == Journey.Phase.DEFEAT and failed.health == 0, "Defeat ends the journey")
	check(failed.start_encounter() == null and not failed.take_recovery(), "Defeated journey cannot restart at zero health")
	var full = Journey.new(StarterDeck.create(), false)
	var win: RefCounted = full.start_encounter()
	win.enemy.take_damage(999)
	win.check_outcome()
	full.finish_encounter(win)
	check(not full.take_recovery() and full.phase == Journey.Phase.REWARD, "Full-health recovery does not consume a reward")
	check(not full.draft_card(StarterDeck.STRIKE) and full.phase == Journey.Phase.REWARD, "Cards outside the offered draft cannot consume the reward")
	check(not full.remove_card(-1) and full.phase == Journey.Phase.REWARD, "An invalid cut does not consume the reward")
	check(full.skip_reward() and full.stage == 1, "Player may skip the reward")
	var one_card: Array[CardInstance] = [CardInstance.new(StarterDeck.STRIKE)]
	var lean = Journey.new(one_card, false)
	var lean_win: RefCounted = lean.start_encounter()
	lean_win.enemy.take_damage(999)
	lean_win.check_outcome()
	lean.finish_encounter(lean_win)
	check(not lean.remove_card(0) and lean.phase == Journey.Phase.REWARD, "A cut cannot leave the deck empty")
