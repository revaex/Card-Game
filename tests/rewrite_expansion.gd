extends SceneTree
## Regression coverage for Counterwritten effects, line previews, and sealed intents.

const Session = preload("res://scripts/combat/combat_session.gd")
const Table = preload("res://scenes/ui/combat_table.tscn")
const Library = preload("res://scripts/content/deck_library.gd")
const Scribe = preload("res://data/rivals/scribe.tres")
const Errata = preload("res://data/cards/errata.tres")
const PaperTrail = preload("res://data/cards/paper_trail.tres")
const SecondReading = preload("res://data/cards/second_reading.tres")
const Journey = preload("res://scripts/combat/journey_state.gd")
const Checkpoint = preload("res://scripts/content/journey_checkpoint.gd")
const Result = preload("res://scenes/ui/combat_result.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func copies(definition: CardDefinition, count: int = 10) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for index in range(count):
		result.append(CardInstance.new(definition))
	return result


func duel(definition: CardDefinition) -> RefCounted:
	return Session.new(copies(definition), copies(StarterDeck.BLOCK), false)


func activate(session: RefCounted) -> void:
	session.cadence = 2
	check(session.rewrite_intent(session.enemy_piles.hand[0]), "Rewrite activates the counterwritten condition")


func check_margin_burn() -> void:
	var session := Session.new(copies(StarterDeck.BLOCK), copies(StarterDeck.STRIKE), false)
	var card := session.player_piles.hand[0]
	check(session.preview_margin_burn(card).is_empty() and not session.margin_burn(card), "Regular encounters reject Margin Burn")
	session.margin_burn_enabled = true
	check(not session.margin_burn(session.player_piles.draw_pile[0]), "Margin Burn rejects a card outside the hand")
	activate(session)
	check(not session.preview_margin_burn(card).rewrite_available, "Burning cannot restore a Rewrite already used this turn")
	session.cadence = 2
	var preview := session.preview_margin_burn(card)
	check(preview.cadence == 3 and session.cadence == 2 and session.player_piles.hand.has(card), "Margin Burn preview applies the cap without changing state")
	check(session.margin_burn(card) and session.cadence == 3 and session.player.block == 0, "Margin Burn applies the cap and skips the sacrificed card's effects")
	session.player.gain_block(100)
	session.end_turn()
	check(session.player_turn and not session.margin_burn(session.player_piles.hand[0]), "Margin Burn stays spent after the next turn starts")
	check(session.player_piles.exhaust_pile == [card] and session.player_piles.total_cards() == 10, "The exact sacrificed copy stays out of the draw cycle")
	var sealed := Session.new(copies(StarterDeck.BLOCK), copies(StarterDeck.STRIKE, 2), false)
	sealed.margin_burn_enabled = true
	sealed.anchored_intent = sealed.enemy_piles.hand[0]
	check(not sealed.preview_margin_burn(sealed.player_piles.hand[0]).rewrite_available, "The forecast accounts for a sealed first card and a final card already at the back")


func run() -> void:
	check_margin_burn()
	var session = duel(Errata)
	var card: CardInstance = session.player_piles.hand[0]
	check(session.preview_attack(card).damage == 4, "Dormant bonus is excluded from damage forecasts")
	check(session.describe_card(card).contains("After Rewrite:"), "Dormant bonus explains its condition")
	session.play_card(card)
	check(session.enemy.health == 36, "Dormant Errata deals only its base damage")
	check(session.last_action.description == "Deal 4 damage.", "Resolved action text never claims a dormant bonus fired")
	activate(session)
	card = session.player_piles.hand[0]
	check(session.preview_attack(card).damage == 11, "Active bonus is included in damage forecast")
	check(session.describe_card(card).contains("Counterwritten:"), "Active bonus is identified in live text")
	session.play_card(card)
	check(session.enemy.health == 25 and session.statistics.player.damage == 15, "Bonus hits resolve and contribute actual damage statistics")
	check(session.statistics.player.counterwritten == 1, "Scorecard counts one empowered card rather than individual effects")
	session.end_turn()
	card = session.player_piles.hand[0]
	check(not session.rewrote_this_turn and session.preview_attack(card).damage == 4, "Counterwritten resets on the next player turn")
	check(Errata.effects[1].damage == 7 and duel(Errata).preview_attack(card).damage == 4, "Shared effects and fresh sessions remain unchanged")
	session = duel(PaperTrail)
	session.play_card(session.player_piles.hand[0])
	check(session.player.block == 4, "Paper Trail base block works before Rewrite")
	activate(session)
	session.play_card(session.player_piles.hand[0])
	check(session.player.block == 14, "Paper Trail grants both block effects after Rewrite")
	session = duel(SecondReading)
	session.play_card(session.player_piles.hand[0])
	check(session.player_piles.hand.size() == 5, "Second Reading replaces itself before Rewrite")
	activate(session)
	session.play_card(session.player_piles.hand[0])
	check(session.player_piles.hand.size() == 6, "Second Reading draws two after Rewrite")
	session = Session.new(copies(StarterDeck.BLOCK), copies(Errata), false)
	activate(session)
	session.end_turn()
	check(session.player.health == 18, "Player Rewrite never activates the rival's conditional effects")

	session = Session.new(copies(StarterDeck.BLOCK), Scribe.create_deck(), false, false, Scribe)
	session.cadence = 2
	var line: Array[CardInstance] = session.enemy_piles.hand.duplicate()
	var history: Array[String] = session.history.duplicate()
	var preview: Dictionary = session.preview_rewrite(line[0])
	check(preview.before.poison == 7 and preview.after.poison == 3, "Scribe preview captures Poison tradeoff")
	check(preview.leaving == [line[0]] and preview.entering == [line[2], line[3]], "Rewrite forecast names the exact copies leaving and entering the Scribe's affordable line")
	check(preview.before.hp_loss == 0 and preview.after.hp_loss == 5 and preview.after.draws, "Preview exposes incoming Siphon and uncertainty from draws")
	check(session.enemy_piles.hand == line and session.history == history and session.cadence == 2, "Forecast is read-only")
	session.player.gain_block(3)
	check(session.preview_rewrite(line[0]).after.hp_loss == 2, "Forecast accounts for current player Block")
	session.rewrite_intent(line[0])
	check(session.statistics.player.displaced == 1, "Scorecard counts the Inkblot moved into reserve")
	check(session.enemy_opening_plan() == preview.plan, "Rewritten execution plan matches preview")
	check(session.preview_rewrite(line[1]).is_empty(), "Unavailable Rewrite has no actionable preview")
	session.enemy.take_damage(16)
	session.check_outcome()
	check(not session.rival_final_phase and session.anchored_intent == null, "Crossing the threshold leaves the current revealed line unchanged")
	session.player.gain_block(100)
	session.end_turn()
	check(session.rival_final_phase and session.anchored_intent == session.enemy_piles.hand[0], "Next prepared line enters and seals the final phase")
	check(session.enemy_piles.hand[0].get_category() == CardDefinition.Category.ATTACK, "Final revision leads with attacks")
	session.cadence = 3
	var sealed: CardInstance = session.anchored_intent
	var previous_cadence: int = session.cadence
	check(not session.rewrite_intent(sealed) and session.cadence == previous_cadence, "Sealed card rejects Rewrite without spending Cadence")
	check(session.rewrite_intent(session.enemy_piles.hand[1]), "Other final-phase cards can still be rewritten")
	check(session.anchored_intent == sealed and session.enemy_piles.hand[0] == sealed, "Rewrite preserves the seal on the original card")
	session.enemy.heal(10)
	session.player.gain_block(100)
	session.end_turn()
	check(session.rival_final_phase, "Healing above the threshold cannot undo the final phase")
	var fresh = Session.new(copies(StarterDeck.BLOCK), Scribe.create_deck(), false, false, Scribe)
	check(not fresh.rival_final_phase and fresh.anchored_intent == null and Scribe.doctrine == 2, "Phase state never leaks into the shared rival Resource")
	var library := Library.new()
	check(library.instantiate_deck(library.counterwritten_recipe()).size() == 10, "Counterwritten preset creates ten known cards")
	var journey := Journey.new(library.instantiate_deck(library.counterwritten_recipe()), false)
	journey.checkpoint_id = "counterwritten-test"
	journey.roster[0].category_override = CardDefinition.Category.GUARD
	var checkpoint := Checkpoint.new()
	checkpoint.path = "res://.godot/counterwritten-%d.checkpoint" % Time.get_ticks_usec()
	check(checkpoint.save_run(journey, "Counterwritten"), "New content can be checkpointed")
	var restored: Dictionary = checkpoint.load_run()
	check(not restored.is_empty() and restored.journey.roster[0].definition == Errata and restored.journey.roster[0].category_override == CardDefinition.Category.GUARD, "New card IDs and per-copy revisions survive checkpoint reload")
	DirAccess.remove_absolute(checkpoint.path)
	var legacy_summary: Dictionary = session.combat_summary()
	legacy_summary.outcome = "Victory"
	legacy_summary.statistics.player.erase("displaced")
	legacy_summary.statistics.player.erase("counterwritten")
	var result := Result.instantiate()
	root.add_child(result)
	result.setup(legacy_summary, func(): pass, func(): pass, func(): pass)
	check(result.get_node("%CraftSummary").text.contains("0 intents displaced"), "Older summaries remain displayable with missing new counters")
	result.queue_free()

	var view := Table.instantiate()
	root.add_child(view)
	view.combat_audio.set_enabled(false)
	var no_cards: Array[CardInstance] = []
	view.setup(no_cards, no_cards, false, null, fresh)
	view.set_motion_enabled(false)
	fresh.cadence = 2
	view.refresh()
	await process_frame
	check(view.get_node("%RivalPhase").visible, "Scribe threshold is telegraphed from the opening")
	card = fresh.enemy_piles.hand[0]
	view.show_rewrite_hint(card)
	check(view.get_node("%ThreatPreview").text.contains("Poison added 7 → 3"), "Hover or focus presents concrete Rewrite consequences")
	check(view.rewrite_row.get_child(0).get_node("%Index").text.contains("→ RESERVE"), "Rewrite preview labels displaced cards without relying on color")
	view.clear_rewrite_hint(card)
	check(view.get_node("%ThreatPreview").text.begins_with("VISIBLE LINE"), "Leaving the card restores the current line forecast")
	check(not view.rewrite_row.get_child(0).get_node("%Index").text.contains("→"), "Leaving the preview restores actual line labels")
	var touch := InputEventMouseButton.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.button_index = MOUSE_BUTTON_LEFT
	var tile: Button = view.rewrite_row.get_child(0)
	touch.position = tile.size * 0.5
	view.handle_intent_pointer(touch, card, tile)
	check(view.has_node("IntentInspection") and fresh.cadence == 2, "Touch opens inspection without spending Cadence")
	var inspection: Window = view.get_node("IntentInspection")
	check(inspection.find_child("ConfirmRewrite", true, false) != null, "Touch inspection offers explicit confirmation")
	var details: String = inspection.get_node("%Body").get_parsed_text()
	check(details.contains("Moves to reserve: Inkblot") and details.contains("Enters the affordable line: Insight, Siphon"), "Touch inspection explicitly names the affordable-line changes")
	inspection.close_requested.emit()
	await process_frame
	check(fresh.cadence == 2 and not fresh.rewrote_this_turn, "Cancelling inspection preserves combat state")
	view.inspect_intent_card(card, view.rewrite_row.get_child(0))
	inspection = view.get_node("IntentInspection")
	inspection.find_child("ConfirmRewrite", true, false).pressed.emit()
	check(fresh.rewrote_this_turn and fresh.cadence == 0, "Confirm commits exactly one Rewrite")
	await process_frame
	fresh.enemy.take_damage(16)
	fresh.check_outcome()
	fresh.player.gain_block(100)
	fresh.end_turn()
	fresh.cadence = 2
	view.refresh()
	var sealed_tile: Button = view.rewrite_row.get_child(0)
	view.focus_rival_line()
	var focused_intent := root.gui_get_focus_owner()
	check(focused_intent != null and focused_intent != sealed_tile and fresh.can_rewrite(focused_intent.get_meta("card")), "Rival shortcut skips the sealed card when Rewrite has a valid target")
	sealed_tile.grab_focus()
	check(sealed_tile.get_node("%Index").text.contains("SEALED"), "Focus preserves the sealed label")
	view.inspect_intent_card(fresh.anchored_intent, sealed_tile)
	inspection = view.get_node("IntentInspection")
	check(inspection.find_child("ConfirmRewrite", true, false) == null, "Sealed inspection cannot offer an invalid confirmation")
	inspection.close_requested.emit()
	await process_frame
	fresh.cadence = 0
	view.refresh_intent()
	view.focus_rival_line()
	check(root.gui_get_focus_owner() == view.rewrite_row.get_child(0), "Rival shortcut still focuses an inspectable card when Rewrite is unavailable")
	view.queue_free()
	await process_frame
	print("Rewrite expansion checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
