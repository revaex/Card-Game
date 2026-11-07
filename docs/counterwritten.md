# Counterwritten and Final Revision

Implemented as a focused expansion of the existing three-rival slice. There are
15 card definitions, including the three new cards below. Balance values are
starting points for playtesting, not a completed balance pass.

## Cards

| Card | Category | Cost | Base effect | Extra effect after Rewrite |
|---|---|---|---|---|
| Errata | Attack | 1 | Deal 4 damage | Deal another 7 damage |
| Paper Trail | Guard | 1 | Gain 4 Block | Gain another 6 Block |
| Second Reading | Tactic | 1 | Draw up to 1 card | Draw up to 1 more card |

Each extra effect is an ordinary effect Resource with `after_rewrite = true`.
The combat session decides whether to include it in execution and forecasts.
Shared definitions contain no per-turn state. The condition remains active after
the player's Rewrite until the next player turn; it never empowers enemy cards.
Errata has two damage effects, so existing per-hit damage bonuses apply to both.

This creates a sequencing choice: play a modest base card to earn Cadence now,
or hold it until after Rewrite for the stronger effect. A Counterwritten card can
still advance or finish a Pattern according to its current category.

The deck builder exposes a ten-card Counterwritten preset with two copies each
of Errata, Paper Trail, Second Reading, Redline, and Switchback. The draft after
the Warden offers one of the three new cards. Recovery, removal, and revision
remain alternative rewards.

## Scribe phase timing

1. Reducing the Scribe to 16 HP queues Final Revision during outcome checking.
2. Its already-revealed line stays intact and executes normally.
3. The next hand preparation activates the phase and orders attacks first.
4. That prepared hand's first card is sealed against Rewrite. Other cards remain
   valid targets, including cards already in reserve except the final card.

Healing cannot cancel the queued or active phase. Each subsequent prepared line
gets its own sealed first card. The seal belongs to the card instance, not a
mutable global slot. The rival Resource controls threshold, doctrine, and seal;
the session owns the pending phase, active phase, and anchored card reference.
The controller's rival shortcut focuses the first legal Rewrite target, or the
first inspectable card if Rewrite is unavailable.

## What forecasts and results mean

Rewrite previews copy the revealed hand order and apply the normal affordability
rule. They do not execute effects, consume randomness, emit events, or move cards.
Attack HP loss accounts for current player Block. Added Poison is shown separately
from attack damage; drawn follow-ups are unknown. The preview is not a prediction
of the entire future turn or of damage from existing Poison.

An intent displacement is counted when a card leaves the affordable plan for
reserve at the instant of Rewrite. It can return through later changes or draws,
so this statistic is not labelled damage prevented. Counterwritten plays count
cards with active conditional effects, once per card rather than once per effect.

## Verification and remaining playtests

- `tests/rewrite_expansion.gd`: 51 checks covering active/dormant effects,
  previews, phase timing, seals, input confirmation, old summaries, and new-card
  checkpoint reloads.
- Existing backend (312), board feedback (23), and editor-scene (60) checks pass,
  alongside UI flow, guided duel, Journey checkpoint, and relic progression suites.
- `tests/render_rewrite_expansion.gd`: rendered and inspected opening, preview,
  inspection, activated cards, final phase, and results at 1100×700, plus the
  final phase at 1280×800. Screenshots are generated under `.godot/`.
- Still needs human balance tests: does holding an Errata create an interesting
  choice, do players notice the queued phase, and is the sealed Siphon adequately
  countered by Block or by rewriting the remaining line?
- Physical touch/controller and packaged Windows/Web testing remain release gates.

No checkpoint version change is required: new card IDs use the existing catalog
lookup, and result views default missing optional counters to zero. Mid-duel app
restarts still restart the chapter, including its phase state.
