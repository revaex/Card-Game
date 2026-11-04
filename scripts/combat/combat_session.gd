extends RefCounted
## Owns encounter rules; the UI requests actions and observes completed changes.

signal changed
signal card_played(card: CardInstance, by_player: bool)

const ENERGY_PER_TURN: int = 3
const WarDrum = preload("res://scripts/artifacts/war_drum.gd")
var war_drum: RefCounted
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
var enemy_energy: int = ENERGY_PER_TURN
var _enemy_played: Array[CardInstance] = []
var statistics: Dictionary = {"player": {}, "enemy": {}}
var last_action: Dictionary = {}
const CADENCE_CAP: int = 3
const REWRITE_COST: int = 2
var cadence: int = 0
var last_category: int = -1
var rewrote_this_turn: bool = false


func _init(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], shuffle: bool = true, use_war_drum: bool = false) -> void:
	for side in statistics:
		statistics[side] = {"cards": 0, "energy": 0, "damage": 0, "absorbed": 0, "healed": 0, "poison_applied": 0, "rewrites": 0}
	if use_war_drum:
		war_drum = WarDrum.new()
	player_piles = CardPiles.new(player_cards, shuffle)
	enemy_piles = CardPiles.new(enemy_cards, shuffle)
	player_piles.draw_cards(5)
	enemy_piles.draw_cards(5)
	log_event("Turn 1 — You drew %d cards. Energy 3." % player_piles.hand.size())
	log_event("Rival prepared %d cards for its next turn." % enemy_piles.hand.size())


func log_event(text: String) -> void:
	history.append(text)
	if history.size() > 200:
		history.pop_front()


func can_play(card: CardInstance) -> bool:
	return not _resolving and outcome.is_empty() and player_turn and card != null and player_piles.hand.has(card) and energy >= card.get_energy_cost() and not card.definition.effects.is_empty()


func enemy_opening_plan() -> Array[CardInstance]:
	# Read-only preview using the same affordability rule as execution.
	# Draw effects may add follow-up plays; those cards are not predicted here.
	var plan: Array[CardInstance] = []
	if not outcome.is_empty() or (player_turn and enemy.poison >= enemy.health):
		return plan
	var remaining := ENERGY_PER_TURN if player_turn else enemy_energy
	for card in enemy_piles.hand:
		if (player_turn or not _enemy_played.has(card)) and is_affordable(card, remaining):
			plan.append(card)
			remaining -= card.get_energy_cost()
	return plan


func is_affordable(card: CardInstance, available_energy: int) -> bool:
	return card.get_energy_cost() <= available_energy and not card.definition.effects.is_empty()


func preview_bonus(card: CardInstance, by_player: bool = true) -> int:
	return war_drum.preview_bonus(card) if by_player and war_drum != null else 0


func describe_card(card: CardInstance, by_player: bool = true) -> String:
	return describe_effects(card, preview_bonus(card, by_player))


func describe_effects(card: CardInstance, bonus: int) -> String:
	var lines: PackedStringArray = []
	for effect in card.definition.effects:
		if effect != null:
			var description := effect.describe(bonus)
			if not description.is_empty():
				lines.append(description)
	return " ".join(lines) if not lines.is_empty() else card.definition.description


func preview_attack(card: CardInstance, by_player: bool = true) -> Dictionary:
	# Read-only direct-damage forecast. Does not execute effects or consume randomness.
	var target := enemy if by_player else player
	var hp := target.health
	var shield := target.block
	var damage := 0
	var absorbed := 0
	var bonus := preview_bonus(card, by_player)
	for effect in card.definition.effects:
		if effect is DamageEffect and hp > 0:
			var hit: int = effect.effective_damage(bonus)
			var blocked := mini(shield, hit)
			damage += hit
			absorbed += blocked
			shield -= blocked
			hp = maxi(0, hp - (hit - blocked))
	return {"damage": damage, "blocked": absorbed, "hp_loss": target.health - hp, "remaining_hp": hp, "remaining_block": shield, "lethal": hp == 0, "bonus": bonus}


func combat_summary() -> Dictionary:
	return {"outcome": outcome, "rounds": round_number, "player_health": player.health, "enemy_health": enemy.health, "statistics": statistics.duplicate(true)}


func cadence_gain(card: CardInstance) -> int:
	return 1 if card.definition.category != last_category and cadence < CADENCE_CAP else 0


func can_rewrite(card: CardInstance) -> bool:
	return not _resolving and player_turn and outcome.is_empty() and cadence >= REWRITE_COST and not rewrote_this_turn and enemy.poison < enemy.health and card != null and enemy_piles.hand.has(card) and enemy_piles.hand[-1] != card


func rewrite_intent(card: CardInstance) -> bool:
	if not can_rewrite(card):
		return false
	_resolving = true
	enemy_piles.hand.erase(card)
	enemy_piles.hand.append(card)
	cadence -= REWRITE_COST
	rewrote_this_turn = true
	statistics.player.rewrites += 1
	log_event("Rewrite: moved rival's %s to the back of its prepared hand. Cadence %d/%d." % [card.definition.display_name, cadence, CADENCE_CAP])
	_resolving = false
	changed.emit()
	return true


func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	_resolving = true
	energy -= card.get_energy_cost()
	var gained := cadence_gain(card)
	cadence += gained
	last_category = card.definition.category
	if gained > 0:
		log_event("Cadence +1 (%d/%d): changed to %s." % [cadence, CADENCE_CAP, CardDefinition.Category.keys()[last_category].capitalize()])
	resolve_card(card, player, enemy, player_piles, true)
	_resolving = false
	changed.emit()
	return true


func resolve_card(card: CardInstance, source: Combatant, target: Combatant, piles: CardPiles, by_player: bool) -> void:
	var actor := "You" if by_player else "Rival"
	var recipient := "Rival" if by_player else "You"
	var source_stats: Dictionary = statistics["player" if by_player else "enemy"]
	var target_stats: Dictionary = statistics["enemy" if by_player else "player"]
	source_stats.cards += 1
	source_stats.energy += card.get_energy_cost()
	log_event("%s played %s (%d energy)." % [actor, card.definition.display_name, card.get_energy_cost()])
	var bonus := 0
	if by_player and war_drum != null:
		if war_drum.before_card(card):
			log_event("War Drum: your attack bonus is now +%d." % war_drum.damage_bonus)
		bonus = war_drum.damage_bonus
	var context := EffectContext.new(piles, bonus)
	last_action = {"card": card.definition.display_name, "by_player": by_player, "description": describe_effects(card, bonus)}
	# Hold the resolving card outside the draw cycle until its effects finish.
	piles.hand.erase(card)
	for effect in card.definition.effects:
		if effect != null:
			var hp_before := target.health
			var block_before := target.block
			var own_hp := source.health
			var own_block := source.block
			var hand_before := piles.hand.size()
			var poison_before := target.poison
			effect.execute(source, target, context)
			if effect is DamageEffect:
				source_stats.damage += hp_before - target.health
				target_stats.absorbed += block_before - target.block
				log_event("  %s: %d HP lost, %d blocked." % [recipient, hp_before - target.health, block_before - target.block])
			if effect is GainBlockEffect:
				log_event("  %s gained %d block." % [actor, source.block - own_block])
			if effect is HealEffect:
				source_stats.healed += source.health - own_hp
				log_event("  %s healed %d HP." % [actor, source.health - own_hp])
			if effect is DrawEffect:
				var drawn := piles.hand.size() - hand_before
				log_event("  %s drew %d %s." % [actor, drawn, "card" if drawn == 1 else "cards"])
			if effect is ApplyPoisonEffect:
				source_stats.poison_applied += target.poison - poison_before
				log_event("  %s gained %d Poison (%d total)." % [recipient, target.poison - poison_before, target.poison])
			if source.is_dead():
				break
	piles.discard_pile.append(card)
	piles.card_discarded.emit(card)
	check_outcome()
	card_played.emit(card, by_player)


func check_outcome() -> void:
	if not outcome.is_empty():
		return
	if enemy.is_dead():
		outcome = "Victory"
	elif player.is_dead():
		outcome = "Defeat"
	if not outcome.is_empty():
		log_event(outcome + "! Combat ended.")


func start_turn(actor: Combatant, by_player: bool) -> void:
	var actor_name := "You" if by_player else "Rival"
	if actor.block > 0:
		log_event("%s: %d remaining block expired." % [actor_name, actor.block])
	actor.clear_block()
	if actor.poison > 0 and not actor.is_dead():
		var damage := actor.tick_poison()
		statistics["enemy" if by_player else "player"].damage += damage
		log_event("%s: Poison dealt %d HP damage; %d stacks remain." % [actor_name, damage, actor.poison])
	check_outcome()


func end_turn() -> void:
	# Synchronous convenience for backend simulations; presentation can step instead.
	if not begin_rival_turn():
		return
	while not player_turn and outcome.is_empty():
		advance_rival_turn()


func begin_rival_turn() -> bool:
	if _resolving or not player_turn or not outcome.is_empty():
		return false
	_resolving = true
	player_turn = false
	enemy_energy = ENERGY_PER_TURN
	_enemy_played.clear()
	log_event("You ended turn. Rival's turn — energy 3.")
	player_piles.discard_hand()
	start_turn(enemy, false)
	if outcome.is_empty():
		log_event("Rival uses its prepared hand of %d cards." % enemy_piles.hand.size())
	_resolving = false
	changed.emit()
	return true


func advance_rival_turn() -> bool:
	# One atomic card resolution per call. Timers belong to the presentation layer.
	if _resolving or player_turn or not outcome.is_empty():
		return false
	_resolving = true
	var next: CardInstance = null
	for card in enemy_piles.hand:
		if not _enemy_played.has(card) and is_affordable(card, enemy_energy):
			next = card
			break
	if next != null:
		_enemy_played.append(next)
		enemy_energy -= next.get_energy_cost()
		resolve_card(next, enemy, player, enemy_piles, false)
		if not outcome.is_empty():
			enemy_piles.discard_hand()
		_resolving = false
		changed.emit()
		return true
	enemy_piles.discard_hand()
	if outcome.is_empty():
		round_number += 1
		start_turn(player, true)
		if outcome.is_empty():
			energy = ENERGY_PER_TURN
			last_category = -1
			rewrote_this_turn = false
			player_piles.draw_cards(5)
			enemy_piles.draw_cards(5)
			player_turn = true
			log_event("Turn %d — You drew %d cards. Energy 3." % [round_number, player_piles.hand.size()])
			log_event("Rival prepared %d cards for its next turn." % enemy_piles.hand.size())
	_resolving = false
	changed.emit()
	return false
