extends RefCounted
## Owns one journey. Saved deck recipes and definitions stay untouched.

enum Phase { READY, DUEL, REWARD, COMPLETE, DEFEAT }
const Session = preload("res://scripts/combat/combat_session.gd")
const Rivals = preload("res://scripts/content/rival_catalog.gd")
const RECOVERY: int = 8
const DRAFTS = [
	[preload("res://data/cards/redline.tres"), preload("res://data/cards/iron_seal.tres"), preload("res://data/cards/marginalia.tres")],
	[preload("res://data/cards/errata.tres"), preload("res://data/cards/paper_trail.tres"), preload("res://data/cards/second_reading.tres")],
]
var roster: Array[CardInstance] = []
var phase: Phase = Phase.READY
var stage: int = 0
var health: int = 30
var max_health: int = 30
var summaries: Array[Dictionary] = []
var edits: Array[String] = []
var active_session: RefCounted
var use_war_drum: bool
var equipped_relic: Resource
var checkpoint_id := ""


func _init(cards: Array[CardInstance], artifact_enabled: bool = true, relic: Resource = null) -> void:
	assert(not cards.is_empty())
	for card in cards:
		roster.append(card.copy_for_combat())
	use_war_drum = artifact_enabled
	equipped_relic = relic


func current_rival() -> Resource:
	return Rivals.ALL[stage]


func start_encounter() -> RefCounted:
	if phase != Phase.READY:
		return null
	var cards: Array[CardInstance] = []
	for card in roster:
		cards.append(card.copy_for_combat())
	var rival := current_rival()
	active_session = Session.new(cards, rival.create_deck(), true, use_war_drum, rival, health, equipped_relic)
	phase = Phase.DUEL
	return active_session


func finish_encounter(session: RefCounted) -> bool:
	if phase != Phase.DUEL or session != active_session or session.outcome.is_empty():
		return false
	health = session.player.health
	summaries.append(session.combat_summary())
	active_session = null
	if session.outcome == "Defeat":
		phase = Phase.DEFEAT
	elif stage == Rivals.ALL.size() - 1:
		phase = Phase.COMPLETE
	else:
		phase = Phase.REWARD
	return true


func take_recovery() -> bool:
	if phase != Phase.REWARD or health >= max_health:
		return false
	health = mini(max_health, health + RECOVERY)
	_advance_after_reward()
	return true


func draft_offers() -> Array[CardDefinition]:
	var offers: Array[CardDefinition] = []
	if phase == Phase.REWARD and stage < DRAFTS.size():
		offers.assign(DRAFTS[stage])
	return offers


func draft_card(definition: CardDefinition) -> bool:
	if not draft_offers().has(definition):
		return false
	roster.append(CardInstance.new(definition))
	edits.append("Drafted %s" % definition.display_name)
	_advance_after_reward()
	return true


func reclassify(index: int, category: int) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= roster.size() or category < 0 or category > 2:
		return false
	var card := roster[index]
	if card.get_category() == category:
		return false
	var names := CardDefinition.Category.keys()
	edits.append("%s: %s → %s" % [card.definition.display_name, names[card.get_category()].capitalize(), names[category].capitalize()])
	card.category_override = category
	_advance_after_reward()
	return true


func remove_card(index: int) -> bool:
	if phase != Phase.REWARD or roster.size() <= 1 or index < 0 or index >= roster.size():
		return false
	var card: CardInstance = roster.pop_at(index)
	edits.append("Removed %s" % card.definition.display_name)
	_advance_after_reward()
	return true


func skip_reward() -> bool:
	if phase != Phase.REWARD:
		return false
	_advance_after_reward()
	return true


func _advance_after_reward() -> void:
	assert(phase == Phase.REWARD)
	stage += 1
	phase = Phase.READY


func totals() -> Dictionary:
	var result := {"cards": 0, "damage": 0, "rewrites": 0, "patterns": 0, "wins": 0}
	for summary in summaries:
		if summary.outcome == "Victory":
			result.wins += 1
		for key in ["cards", "damage", "rewrites", "patterns"]:
			result[key] += int(summary.statistics.player[key])
	return result
