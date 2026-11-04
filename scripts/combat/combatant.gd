class_name Combatant
extends RefCounted

signal health_changed(previous: int, current: int)
signal block_changed(previous: int, current: int)
signal poison_changed(previous: int, current: int)

var max_health: int
var health: int
var block: int = 0
var poison: int = 0


func _init(starting_health: int) -> void:
	assert(starting_health > 0, "Starting health must be positive.")
	max_health = starting_health
	health = max_health


func gain_block(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var previous_block = block
	block += amount
	block_changed.emit(previous_block, block)


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var previous_block := block
	var previous_health := health
	var absorbed := mini(block, amount)
	block -= absorbed
	health = maxi(health - (amount - absorbed), 0)

	# Finish both state changes before notifying observers.
	if block != previous_block:
		block_changed.emit(previous_block, block)
	if health != previous_health:
		health_changed.emit(previous_health, health)


func clear_block() -> void:
	if block <= 0:
		return
	var previous_block = block
	block = 0
	block_changed.emit(previous_block, block)


func is_dead() -> bool:
	return health <= 0


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var previous := health
	health = mini(max_health, health + amount)
	if health != previous:
		health_changed.emit(previous, health)


func apply_poison(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var previous := poison
	poison += amount
	poison_changed.emit(previous, poison)


func tick_poison() -> int:
	if poison <= 0 or is_dead():
		return 0
	var previous_health := health
	var previous_poison := poison
	# Poison bypasses block. Finish state changes before notifying observers.
	health = maxi(0, health - poison)
	poison -= 1
	poison_changed.emit(previous_poison, poison)
	health_changed.emit(previous_health, health)
	return previous_health - health
