extends PanelContainer
## Observes a normal encounter and limits the actions offered by its training board.

signal changed
signal completed
signal exit_requested
signal reading_requested

enum Step { READ, ATTACK, GUARD, REWRITE, PATTERN, END_TURN, COMPLETE }

const COPY = [
	["01 / Read the line", "Read the briefing to get started."],
	["02 / Open with Attack", "Play Strike to start Shelter and charge Cadence."],
	["03 / Change category", "Play Block to earn a second Cadence."],
	["04 / Rewrite Strike", "Move the first Strike. One attack will still get through the energy budget."],
	["05 / Finish Shelter", "Play Insight to draw two cards and shield yourself from the remaining Strike."],
	["06 / Let the rival act", "End the turn and watch the revised line play out."],
	["Lesson complete", "Your Rewrite and Shelter kept you at full health. Continue to Journey or return to the menu."],
]

var active := false
var step: Step = Step.READ
var _opening_strike: CardInstance


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
	%Continue.text = "Read briefing" if step == Step.READ else "Go to journey"
	%Read.visible = step != Step.READ
	%Skip.text = "Main menu"


func observe(session: RefCounted) -> void:
	if not active:
		return
	if step == Step.READ and _opening_strike == null:
		_opening_strike = session.enemy_piles.hand.front()
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
	return active and step in [Step.READ, Step.REWRITE] and card == _opening_strike


func allows_rewrite(card: CardInstance) -> bool:
	return not active or (step == Step.REWRITE and marks_threat(card))


func allows_end_turn() -> bool:
	return not active or step == Step.END_TURN


func pages(session: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var shelter: Resource = session.PATTERNS[0]
	var cadence := "The first card each turn earns 1 Cadence. Switching categories earns 1 more, up to %d. Repeating a category earns none. Unspent Cadence carries into your next turn." % session.CADENCE_CAP
	match step:
		Step.READ, Step.ATTACK:
			if step == Step.READ:
				var plan: PackedStringArray = []
				for card in session.enemy_opening_plan():
					plan.append(card.definition.display_name)
				result.append(leaf("Read the prepared line", "The rival spends up to %d energy in the order shown. Planned cards fit that budget. Reserve cards can move into the plan if the line changes. Find the opening Strike before you act." % session.ENERGY_PER_TURN, 0, "PLANNED  /  " + " → ".join(plan)))
			result.append(leaf("What Cadence buys", cadence + "\n\nSpend %d to Rewrite a rival card, or %d to Brace for %d Block or draw a card. This lesson practices Rewrite. Play Strike when you return to the board." % [session.REWRITE_COST, session.CADENCE_ACTION_COST, session.BRACE_BLOCK], 1))
		Step.GUARD:
			result.append(leaf("Change category", "Strike was an Attack. Play Block next to switch to Guard and earn a second Cadence. Its Pattern badge shows that Guard advances Shelter. Right-click Block or use Inspect on the focused card to see the forecast.", 1, shelter.sequence_text()))
		Step.REWRITE:
			result.append(leaf("Spend Cadence on Rewrite", "Choose the rival’s Strike. Rewrite costs %d Cadence and sends that card to the back of the line. You can Rewrite once per turn." % session.REWRITE_COST, 2))
			result.append(leaf("Read the new plan", "The other Strike will still attack for 10 damage. Your 8 Block leaves 2 HP exposed. Check the forecast after you Rewrite, then use Shelter to cover the difference.", 0))
		Step.PATTERN:
			result.append(leaf("Your first card locks the Pattern", "Opening with Attack locked Shelter. From any starting category, the cycle is Attack → Guard → Tactic → Attack. An off-path card leaves the locked Pattern where it is. You can complete one Pattern per turn.", 3, shelter.sequence_text()))
			result.append(leaf("Finish Shelter", "Look for the Shelter badge on Insight. Only the next playable category shows the locked badge. Play Insight to finish the sequence. " + shelter.payoff_text(), 4, shelter.sequence_text()))
		Step.END_TURN:
			result.append(leaf("Let the revised line resolve", "End your turn. Watch your Block absorb the remaining Strike. Pattern progress resets at the start of your next turn. Unspent Cadence carries forward.", 0))
		Step.COMPLETE:
			result.append(leaf("You changed the outcome", "Rewrite pushed one Strike into reserve. Shelter covered the 2 damage that would have pierced your Block. You finished with %d HP. In other duels, use Riposte to push damage through Block or Surge to afford another play." % session.player.health, 4))
	return result


func leaf(title: String, body: String, plate: int, route: String = "") -> Dictionary:
	return {"section": "LEARN TO DUEL", "title": title, "body": body, "plate": plate, "route": route}


func reading_closed() -> void:
	if step == Step.READ:
		step = Step.ATTACK
		update_prompt()
		changed.emit()


func _on_continue() -> void:
	if step == Step.READ:
		reading_requested.emit()
	elif step == Step.COMPLETE:
		completed.emit()


func _on_read() -> void:
	reading_requested.emit()


func _on_skip() -> void:
	exit_requested.emit()
