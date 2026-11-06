extends Node
## Board foley. The scene owns its players and levels, so leaving the board stops its cues.

const PAPER_PLAY = preload("res://data/audio/paper_play.wav")
const DEAL = preload("res://data/audio/deal.wav")
const IMPACT = preload("res://data/audio/impact.wav")
const GUARD = preload("res://data/audio/guard.wav")

var enabled: bool = true


func set_enabled(active: bool) -> void:
	enabled = active
	if not active:
		for player in get_children():
			player.stop()


func paper(dealing: bool = false) -> void:
	if enabled:
		$Paper.stream = DEAL if dealing else PAPER_PLAY
		$Paper.play()


func impact(blocked: bool) -> void:
	if enabled:
		$Impact.stream = GUARD if blocked else IMPACT
		$Impact.play()


func rewrite_lift() -> void:
	if enabled:
		$RewriteLift.play()


func rewrite_seal() -> void:
	if enabled:
		$RewriteSeal.play()


func pattern() -> void:
	if enabled:
		$Pattern.play()


func focus_card() -> void:
	if enabled:
		$Focus.play()
