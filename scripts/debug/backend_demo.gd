extends RefCounted
## Manual learning exercises and console presentation; not the game controller.


# Create deck
var deck: Array[CardInstance] = []
var card_piles: CardPiles

# Create combatants
var player: Combatant
var enemy: Combatant

func run() -> void:
	run_card_pile_exercise()
	run_combatant_exercise()


func run_combatant_exercise() -> void:
	player = Combatant.new(30)
	player.health_changed.connect(_on_player_health_changed)
	player.block_changed.connect(_on_player_block_changed)
	enemy = Combatant.new(40)
	enemy.health_changed.connect(_on_enemy_health_changed)
	enemy.block_changed.connect(_on_enemy_block_changed)

	print_combatant_details("Player", player)
	player.gain_block(5)
	print_combatant_details("Player", player)
	player.take_damage(3)
	print_combatant_details("Player", player)
	player.take_damage(6)
	print_combatant_details("Player", player)

	enemy.take_damage(5)
	print_combatant_details("Enemy", enemy)
	enemy.gain_block(5)
	print_combatant_details("Enemy", enemy)
	enemy.take_damage(100)
	print_combatant_details("Enemy", enemy)

	player.gain_block(4)
	print_combatant_details("Player", player)
	player.clear_block()
	print_combatant_details("Player", player)
	player.take_damage(100)
	print_combatant_details("Player", player)


func print_combatant_details(label: String, combatant: Combatant) -> void:
	print("%s | HP: %d/%d | Block: %d | Dead: %s" % [
		label,
		combatant.health,
		combatant.max_health,
		combatant.block,
		str(combatant.is_dead()),
	])


func run_card_pile_exercise() -> void:
	deck = StarterDeck.create()

	# Create card piles
	card_piles = CardPiles.new(deck)
	card_piles.card_drawn.connect(_on_card_drawn)
	card_piles.card_discarded.connect(_on_card_discarded)
	card_piles.card_exhausted.connect(_on_card_exhausted)

	var test_card = card_piles.draw_card()
	card_piles.exhaust_card(test_card)
	for _i in range(9):
		card_piles.draw_card()
	card_piles.discard_hand()
	for _i in range(9):
		card_piles.draw_card()
	card_piles.draw_card()
	print_card_piles()


func print_card_details() -> void:
	print("\nDeck:")
	for card in deck:
		print("Card: %s | Energy Cost: %d (Cost modifier %d)" % [
			card.definition.display_name,
			card.get_energy_cost(),
			card.cost_modifier
		])
	print("Total cards in deck %s" % deck.size())


func print_card_piles() -> void:
	print("\n--- Card piles ---")
	print_pile("Hand", card_piles.hand)
	print_pile("Draw", card_piles.draw_pile)
	print_pile("Discard", card_piles.discard_pile)
	print_pile("Exhaust", card_piles.exhaust_pile)


func print_pile(label: String, cards: Array[CardInstance]) -> void:
	print("%s (%d):" % [label, cards.size()])

	if cards.is_empty():
		print("  Empty")
		return

	for card in cards:
		print("  %s | Instance: %d | Cost: %d" % [
			card.definition.display_name,
			card.get_instance_id(),
			card.get_energy_cost(),
		])


func _on_card_drawn(card: CardInstance) -> void:
	print("Drew: %s" % card.definition.display_name)
	assert(card_piles.hand.has(card))


func _on_card_discarded(card: CardInstance) -> void:
	print("Discarded: %s" % card.definition.display_name)


func _on_card_exhausted(card: CardInstance) -> void:
	print("Exhausted: %s" % card.definition.display_name)

func _on_player_health_changed(previous: int, current: int) -> void:
	print("Player health changed, previous: ", previous, ", current: ", current)
	if player.is_dead():
		print("Player has died")

func _on_player_block_changed(previous: int, current: int) -> void:
	print("Player block changed, previous: ", previous, ", current: ", current)


func _on_enemy_health_changed(previous: int, current: int) -> void:
	print("Enemy health changed, previous: ", previous, ", current: ", current)
	if enemy.is_dead():
		print("Enemy has died")

func _on_enemy_block_changed(previous: int, current: int) -> void:
	print("Enemy block changed, previous: ", previous, ", current: ", current)
