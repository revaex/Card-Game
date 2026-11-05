extends PanelContainer
## Observes a normal encounter and limits the actions offered by its training board.

signal changed
signal completed

enum Step { READ, ATTACK, GUARD, REWRITE, PATTERN, END_TURN, COMPLETE }

const COPY = [
	["01 / Read the line", "The rival has 3 energy. It plans to play Strike for 10 damage, then two Blocks. Reserve cards can move into the plan."],
	["02 / Open with Attack", "Play Strike. Your first card this turn earns 1 Cadence."],
	["03 / Change category", "Play Block next. Switching from Attack to Guard earns a second Cadence."],
	["04 / Rewrite Strike", "Select the rival’s Strike. Spend 2 Cadence to send it to the back, where the rival will run out of energy before reaching it."],
	["05 / Finish Shelter", "Play Insight, a Tactic. Attack → Guard → Tactic completes Shelter and adds 6 Block."],
	["06 / Let the rival act", "End your turn. Watch the rival spend its energy on three Blocks, leaving Strike in reserve."],
	["Lesson complete", "The rival spent its turn defending and you kept all 30 HP. Take that idea into your first journey."],
]

var active := false
var step: Step = Step.READ


func start() -> void:
	active = true
	update_prompt()


func update_prompt() -> void:
	visible = active
	if not active:
		return
	%Heading.text = COPY[step][0]
	%Instruction.text = COPY[step][1]
	%Continue.visible = step == Step.READ or step == Step.COMPLETE
	%Continue.text = "Ready" if step == Step.READ else "Go to journey"
	%Skip.text = "Free duel" if step == Step.COMPLETE else "Skip lesson"


func observe(session: RefCounted) -> void:
	if not active:
		return
	match step:
		Step.ATTACK:
			if session.statistics.player.cards == 1:
				step = Step.GUARD
		Step.GUARD:
			if session.cadence >= session.REWRITE_COST:
				step = Step.REWRITE
		Step.REWRITE:
			if session.rewrote_this_turn:
				step = Step.PATTERN
		Step.PATTERN:
			if session.completed_pattern == "Shelter":
				step = Step.END_TURN
		Step.END_TURN:
			if session.player_turn and session.round_number > 1:
				step = Step.COMPLETE
	update_prompt()


func allows_card(card: CardInstance) -> bool:
	if not active:
		return true
	match step:
		Step.ATTACK: return card.definition.id == &"strike"
		Step.GUARD: return card.definition.id == &"block"
		Step.PATTERN: return card.definition.id == &"insight"
	return false


func marks_threat(card: CardInstance) -> bool:
	return active and step in [Step.READ, Step.REWRITE] and card.definition.id == &"strike"


func allows_rewrite(card: CardInstance) -> bool:
	return not active or (step == Step.REWRITE and marks_threat(card))


func allows_end_turn() -> bool:
	return not active or step == Step.END_TURN


func _on_continue() -> void:
	if step == Step.READ:
		step = Step.ATTACK
		update_prompt()
		changed.emit()
	elif step == Step.COMPLETE:
		completed.emit()


func _on_skip() -> void:
	active = false
	update_prompt()
	changed.emit()
