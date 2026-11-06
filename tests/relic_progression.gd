extends SceneTree

const Collection = preload("res://scripts/content/relic_collection.gd")
const Session = preload("res://scripts/combat/combat_session.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func win(table: Control) -> void:
	table.session.enemy.apply_poison(999)
	table.end_turn()


func run() -> void:
	var ui := preload("res://scenes/ui/game_ui.tscn").instantiate()
	ui.journey_checkpoint.path = "res://.godot/relic_progression-journey-%d.checkpoint" % Time.get_ticks_usec()
	var path := "res://.godot/relic-test-%d.cfg" % Time.get_ticks_usec()
	ui.relics.save_path = path
	root.add_child(ui)
	ui.combat_sound = false
	ui.library.decks.assign([{"name": "Starter", "cards": {"strike": 5, "block": 5}}])
	var guard = Collection.CATALOG[1]
	var aegis = Collection.CATALOG[2]
	var quill = Collection.CATALOG[3]
	var seal = Collection.CATALOG[4]
	check(ui.relics.equipped().id == "war_drum" and not ui.relics.buy(guard), "A fresh profile starts with the Drum and cannot spend marks it lacks")
	check(not ui.relics.equip("guard_sigil"), "Locked relics cannot be equipped")
	ui.select_rival(2)
	ui.show_table()
	var table: Control = ui.body.get_node("CombatTable")
	win(table)
	check(ui.relics.marks == 20 and ui.relics.meets_milestone(quill) and not ui.relics.meets_milestone(seal), "A Scribe victory grants marks and opens the Quill milestone")
	ui.review_result()
	table.end_turn()
	check(ui.relics.marks == 20, "Reopening results does not repeat the payout")
	ui.show_relics()
	var page: Node = ui.body.get_node("RelicCollection")
	page.get_node("%Relics/guard_sigil").get_node("%Action").pressed.emit()
	check(ui.relics.marks == 0 and ui.relics.owned.has("guard_sigil"), "Unlock purchases with exactly enough marks succeed")
	page = ui.body.get_node("RelicCollection")
	page.get_node("%Relics/guard_sigil").get_node("%Action").pressed.emit()
	check(ui.relics.equipped().id == "guard_sigil", "The collection equips the purchased relic")
	ui.show_journey_setup()
	ui.begin_journey()
	for stage in range(3):
		ui.show_journey_encounter()
		table = ui.body.get_node("CombatTable")
		check(table.session.player.block == 3 and table.session.war_drum == null, "Each Journey duel uses the equipped Sigil")
		win(table)
		if stage < 2:
			ui.skip_journey_reward()
	check(ui.relics.marks == 95 and ui.relics.journey_won, "Three wins and the Journey bonus pay out once")
	var stored := Collection.new()
	stored.save_path = path
	stored.load_profile()
	check(stored.marks == 95 and stored.equipped().id == guard.id and stored.meets_milestone(seal), "Marks, ownership, equipment, and milestones survive reload")
	check(stored.buy(seal) and stored.marks == 20, "The Journey relic can be bought after the milestone")
	check(stored.meets_milestone(aegis), "The Warden win opens the Aegis milestone")
	var legacy_config := ConfigFile.new()
	var legacy_path := path + ".legacy"
	legacy_config.set_value("relics", "coins", 100)
	legacy_config.save(legacy_path)
	var legacy := Collection.new()
	legacy.save_path = legacy_path
	legacy.load_profile()
	check(legacy.marks == 100 and not legacy.buy(aegis), "Legacy balances carry forward and still require the Warden victory")
	var cards := StarterDeck.create()
	var gilded := Session.new(cards, cards, false, false, null, 30, seal)
	var scribe := Session.new(cards, cards, false, false, null, 30, quill)
	var warden := Session.new(cards, cards, false, false, null, 30, aegis)
	check(warden.player.block == 6 and warden.player_piles.hand.size() == 6, "Aegis grants six Block and an extra opening draw")
	warden.player.gain_block(100)
	warden.end_turn()
	check(warden.player_turn and warden.player.block == 0 and warden.player_piles.hand.size() == 5, "Aegis applies only at the start of the duel")
	check(gilded.energy == 4 and scribe.cadence == 1, "Relic effects apply to the opening turn")
	gilded.player.gain_block(100)
	gilded.end_turn()
	check(gilded.player_turn and gilded.energy == 3, "The Seal bonus is restricted to the opening turn")
	ui.free()
	await process_frame
	print("Relic progression: ", "PASSED" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
