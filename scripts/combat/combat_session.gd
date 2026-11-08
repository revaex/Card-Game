extends RefCounted
## Owns encounter rules; the UI requests actions and observes completed changes.

signal changed
signal card_played(card: CardInstance, by_player: bool)

const ENERGY_PER_TURN: int = 3
const WarDrum = preload("res://scripts/artifacts/war_drum.gd")
const Relic = preload("res://scripts/artifacts/relic_definition.gd")
var war_drum: RefCounted
var equipped_relic: Relic
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
const MARGIN_BURN_GAIN: int = 2
const CADENCE_ACTION_COST: int = 2
const BRACE_BLOCK: int = 4
enum CadenceAction { BRACE, DRAW }
const PATTERNS = [preload("res://data/patterns/shelter.tres"), preload("res://data/patterns/riposte.tres"), preload("res://data/patterns/surge.tres")]
var pattern_history: Array[int] = []
var active_pattern: Resource
var completed_pattern: String = ""
var _finishing_damage: int = 0
var cadence: int = 0
var last_category: int = -1
var rewrote_this_turn: bool = false
var margin_burn_enabled: bool = false
var margin_burn_used: bool = false
var rival_definition: Resource
var rival_final_phase: bool = false
var rival_phase_pending: bool = false
var anchored_intent: CardInstance


func _init(player_cards: Array[CardInstance], enemy_cards: Array[CardInstance], shuffle: bool = true, use_war_drum: bool = false, rival: Resource = null, starting_health: int = 30, relic: Relic = null) -> void:
	assert(starting_health > 0 and starting_health <= player.max_health)
	player.health = starting_health
	rival_definition = rival
	if rival != null:
		enemy = Combatant.new(rival.health)
	for side in statistics:
		statistics[side] = {"cards": 0, "energy": 0, "damage": 0, "absorbed": 0, "healed": 0, "poison_applied": 0, "rewrites": 0, "patterns": 0, "displaced": 0, "counterwritten": 0}
	equipped_relic = relic
	if use_war_drum or (relic != null and relic.perk == Relic.Perk.WAR_DRUM):
		war_drum = WarDrum.new()
	player_piles = CardPiles.new(player_cards, shuffle)
	enemy_piles = CardPiles.new(enemy_cards, shuffle)
	if rival_definition != null:
		rival_definition.arrange_opening_draw(enemy_piles)
	player_piles.draw_cards(5)
	prepare_rival_hand()
	apply_turn_relic()
	log_event("Turn 1 — You drew %d cards. Energy %d." % [player_piles.hand.size(), energy])
	log_event("Rival prepared %d cards for its next turn." % enemy_piles.hand.size())
	if rival_definition != null:
		log_event("%s doctrine: %s. Rewrite changes the revealed order." % [rival_definition.display_name, rival_definition.doctrine_text()])


func prepare_rival_hand() -> void:
	enemy_piles.draw_cards(5)
	if rival_definition != null:
		if not rival_final_phase and rival_definition.final_phase_health > 0 and (rival_phase_pending or enemy.health <= rival_definition.final_phase_health):
			rival_final_phase = true
			rival_phase_pending = false
			log_event("Final revision: %s. %s." % [rival_definition.final_phase_name, rival_definition.final_phase_rules()])
		rival_definition.arrange_hand(enemy_piles, rival_final_phase)
	anchored_intent = null
	if rival_final_phase and rival_definition.final_phase_anchor and not enemy_piles.hand.is_empty():
		anchored_intent = enemy_piles.hand[0]


func apply_turn_relic() -> void:
	if equipped_relic == null:
		return
	match equipped_relic.perk:
		Relic.Perk.GUARD_SIGIL:
			player.gain_block(3)
			log_event("Guard Sigil: gain 3 Block.")
		Relic.Perk.SCRIBE_QUILL:
			if round_number == 1:
				cadence = 1
				log_event("Scribe’s Quill: start with 1 Cadence.")
		Relic.Perk.GILDED_SEAL:
			if round_number == 1:
				energy += 1
				log_event("Gilded Seal: start with 1 extra energy.")
		Relic.Perk.WARDEN_AEGIS:
			if round_number == 1:
				player.gain_block(6)
				player_piles.draw_cards(1)
				log_event("Warden’s Aegis: begin with 6 Block and an extra opening draw.")


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
	return plan_for_line(enemy_piles.hand)


func plan_for_line(line: Array[CardInstance]) -> Array[CardInstance]:
	var plan: Array[CardInstance] = []
	var remaining := ENERGY_PER_TURN if player_turn else enemy_energy
	for card in line:
		if (player_turn or not _enemy_played.has(card)) and is_affordable(card, remaining):
			plan.append(card)
			remaining -= card.get_energy_cost()
	return plan


func is_affordable(card: CardInstance, available_energy: int) -> bool:
	return card.get_energy_cost() <= available_energy and not card.definition.effects.is_empty()


func preview_bonus(card: CardInstance, by_player: bool = true) -> int:
	if not by_player:
		return 0
	var bonus: int = war_drum.preview_bonus(card) if war_drum != null else 0
	var pattern := preview_pattern(card)
	return bonus + (int(pattern.finishing_damage) if pattern != null else 0)


func pattern_for_card(card: CardInstance) -> Resource:
	if not completed_pattern.is_empty() or not player_turn or not outcome.is_empty() or card == null:
		return null
	var category := card.get_category()
	if active_pattern != null:
		return active_pattern if category == active_pattern.category_at(pattern_history.size()) else null
	for pattern in PATTERNS:
		if pattern.first == category:
			return pattern
	return null


func preview_pattern(card: CardInstance) -> Resource:
	return pattern_for_card(card) if pattern_history.size() == 2 else null


func pattern_rules() -> String:
	var rules: PackedStringArray = ["The first card locks your Pattern. Follow the cycle Attack → Guard → Tactic → Attack from that starting point. Other cards and Cadence actions leave your progress as it is. Complete one Pattern per turn."]
	for pattern in PATTERNS:
		rules.append("%s: %s — %s" % [pattern.display_name, pattern.sequence_text(), pattern.payoff_text()])
	return "\n".join(rules)


func describe_card(card: CardInstance, by_player: bool = true) -> String:
	return describe_effects(card, preview_bonus(card, by_player), by_player and rewrote_this_turn)


func describe_effects(card: CardInstance, bonus: int, rewritten: bool = false, include_inactive: bool = true) -> String:
	var lines: PackedStringArray = []
	for effect in card.definition.effects:
		if effect != null:
			if effect.after_rewrite and not rewritten and not include_inactive:
				continue
			var description := effect.describe(bonus)
			if effect.after_rewrite:
				description = ("Counterwritten: " if rewritten else "After Rewrite: ") + description
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
		if effect != null and effect.after_rewrite and not (by_player and rewrote_this_turn):
			continue
		if effect is DamageEffect and hp > 0:
			var hit: int = effect.effective_damage(bonus)
			var blocked := mini(shield, hit)
			damage += hit
			absorbed += blocked
			shield -= blocked
			hp = maxi(0, hp - (hit - blocked))
	return {"damage": damage, "blocked": absorbed, "hp_loss": target.health - hp, "remaining_hp": hp, "remaining_block": shield, "lethal": hp == 0, "bonus": bonus}


func combat_summary() -> Dictionary:
	return {"outcome": outcome, "rounds": round_number, "player_health": player.health, "enemy_health": enemy.health, "rival_name": rival_definition.display_name if rival_definition != null else "Rival", "statistics": statistics.duplicate(true)}


func cadence_gain(card: CardInstance) -> int:
	return 1 if card.get_category() != last_category and cadence < CADENCE_CAP else 0


func can_spend_cadence(action: CadenceAction) -> bool:
	if _resolving or not player_turn or not outcome.is_empty() or cadence < CADENCE_ACTION_COST:
		return false
	match action:
		CadenceAction.BRACE: return true
		CadenceAction.DRAW: return not player_piles.draw_pile.is_empty() or not player_piles.discard_pile.is_empty()
	return false


func spend_cadence(action: CadenceAction) -> bool:
	if not can_spend_cadence(action):
		return false
	_resolving = true
	cadence -= CADENCE_ACTION_COST
	if action == CadenceAction.BRACE:
		player.gain_block(BRACE_BLOCK)
		log_event("Cadence: Brace granted %d Block." % BRACE_BLOCK)
	else:
		player_piles.draw_cards(1)
		log_event("Cadence: drew 1 card.")
	_resolving = false
	changed.emit()
	return true


func can_margin_burn(card: CardInstance) -> bool:
	return margin_burn_enabled and not margin_burn_used and not _resolving and player_turn and outcome.is_empty() and card != null and player_piles.hand.has(card)


func preview_margin_burn(card: CardInstance) -> Dictionary:
	if not can_margin_burn(card):
		return {}
	var resulting_cadence := mini(CADENCE_CAP, cadence + MARGIN_BURN_GAIN)
	var rewrite_available := enemy_piles.hand.any(func(intent: CardInstance): return can_rewrite_with_cadence(intent, resulting_cadence))
	return {"cadence": resulting_cadence, "rewrite_available": rewrite_available}


func margin_burn(card: CardInstance) -> bool:
	if not can_margin_burn(card):
		return false
	_resolving = true
	margin_burn_used = true
	var gained := mini(MARGIN_BURN_GAIN, CADENCE_CAP - cadence)
	cadence += gained
	log_event("Margin Burn: exhausted %s and gained %d Cadence (%d/%d)." % [card.definition.display_name, gained, cadence, CADENCE_CAP])
	player_piles.exhaust_card(card)
	_resolving = false
	changed.emit()
	return true


func can_rewrite(card: CardInstance) -> bool:
	return can_rewrite_with_cadence(card, cadence)


func can_rewrite_with_cadence(card: CardInstance, available_cadence: int) -> bool:
	return not _resolving and player_turn and outcome.is_empty() and available_cadence >= REWRITE_COST and not rewrote_this_turn and enemy.poison < enemy.health and card != null and card != anchored_intent and enemy_piles.hand.has(card) and enemy_piles.hand[-1] != card


func preview_rewrite(card: CardInstance) -> Dictionary:
	# Copies only the order. No effects, signals, RNG, or pile movement in previews.
	if not can_rewrite(card):
		return {}
	var line: Array[CardInstance] = enemy_piles.hand.duplicate()
	line.erase(card)
	line.append(card)
	var before := enemy_opening_plan()
	var after := plan_for_line(line)
	var leaving := before.filter(func(intent: CardInstance): return not after.has(intent))
	var entering := after.filter(func(intent: CardInstance): return not before.has(intent))
	return {
		"before": line_threat(before),
		"after": line_threat(after),
		"plan": after,
		"displaced": leaving.has(card),
		"leaving": leaving,
		"entering": entering,
	}


func line_threat(plan: Array[CardInstance]) -> Dictionary:
	# Visible direct effects only; unknown follow-up draws are explicitly flagged.
	var hp := player.health
	var shield := player.block
	var poison := 0
	var uncertain := false
	for card in plan:
		for effect in card.definition.effects:
			if effect == null or effect.after_rewrite or hp <= 0:
				continue
			if effect is DamageEffect:
				var hit: int = effect.effective_damage()
				var blocked := mini(shield, hit)
				shield -= blocked
				hp = maxi(0, hp - hit + blocked)
			elif effect is ApplyPoisonEffect:
				poison += effect.stacks
			elif effect is DrawEffect:
				uncertain = true
	return {"hp_loss": player.health - hp, "poison": poison, "draws": uncertain}


func rewrite_intent(card: CardInstance) -> bool:
	if not can_rewrite(card):
		return false
	_resolving = true
	var previous_plan := enemy_opening_plan()
	enemy_piles.hand.erase(card)
	enemy_piles.hand.append(card)
	var revised_plan := enemy_opening_plan()
	for planned in previous_plan:
		if not revised_plan.has(planned):
			statistics.player.displaced += 1
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
	var pattern := preview_pattern(card)
	var candidate := pattern_for_card(card)
	if candidate != null:
		active_pattern = candidate
		pattern_history.append(card.get_category())
	if pattern != null:
		completed_pattern = pattern.display_name
		_finishing_damage = pattern.finishing_damage
		player.gain_block(pattern.block_gain)
		energy += pattern.energy_gain
		statistics.player.patterns += 1
		log_event("Pattern %s: %s" % [pattern.display_name, pattern.payoff_text()])
	var gained := cadence_gain(card)
	cadence += gained
	last_category = card.get_category()
	if gained > 0:
		log_event("Cadence +1 (%d/%d): changed to %s." % [cadence, CADENCE_CAP, CardDefinition.Category.keys()[last_category].capitalize()])
	resolve_card(card, player, enemy, player_piles, true)
	_finishing_damage = 0
	_resolving = false
	changed.emit()
	return true


func resolve_card(card: CardInstance, source: Combatant, target: Combatant, piles: CardPiles, by_player: bool) -> void:
	var actor := "You" if by_player else "Rival"
	var recipient := "Rival" if by_player else "You"
	var source_stats: Dictionary = statistics["player" if by_player else "enemy"]
	var target_stats: Dictionary = statistics["enemy" if by_player else "player"]
	source_stats.cards += 1
	if by_player and rewrote_this_turn and card.definition.effects.any(func(effect: CardEffect): return effect != null and effect.after_rewrite):
		source_stats.counterwritten += 1
	source_stats.energy += card.get_energy_cost()
	log_event("%s played %s (%d energy)." % [actor, card.definition.display_name, card.get_energy_cost()])
	var bonus := _finishing_damage if by_player else 0
	if by_player and war_drum != null:
		if war_drum.before_card(card):
			log_event("War Drum: your attack bonus is now +%d." % war_drum.damage_bonus)
		bonus += war_drum.damage_bonus
	var context := EffectContext.new(piles, bonus)
	last_action = {"card": card.definition.display_name, "by_player": by_player, "description": describe_effects(card, bonus, by_player and rewrote_this_turn, false)}
	# Hold the resolving card outside the draw cycle until its effects finish.
	piles.hand.erase(card)
	for effect in card.definition.effects:
		if effect != null:
			if effect.after_rewrite and not (by_player and rewrote_this_turn):
				continue
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
	if outcome.is_empty() and not rival_final_phase and rival_definition != null and rival_definition.final_phase_health > 0 and enemy.health <= rival_definition.final_phase_health:
		rival_phase_pending = true
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
			apply_turn_relic()
			last_category = -1
			rewrote_this_turn = false
			pattern_history.clear()
			active_pattern = null
			completed_pattern = ""
			player_piles.draw_cards(5)
			prepare_rival_hand()
			player_turn = true
			log_event("Turn %d — You drew %d cards. Energy 3." % [round_number, player_piles.hand.size()])
			log_event("Rival prepared %d cards for its next turn." % enemy_piles.hand.size())
	_resolving = false
	changed.emit()
	return false
