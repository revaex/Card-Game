# Current architecture and review

`main.gd` starts `ui/game_ui.gd`. That controller owns menu navigation and deck
editing. `ui/table_screen.gd` owns combat presentation; neither implements
combat rules. Shared colors and control helpers live in `ui/ui_style.gd`.
`content/deck_library.gd` saves deck recipes as names and card-ID counts; it creates
fresh instances for each side. UI saves are separate from the read-only `.tres` content.
`debug/backend_demo.gd` retains the previous console exercises for learning.
`content/starter_deck.gd` creates the starter deck's ten fresh card instances.
The automated runner in `tests/run_tests.gd` verifies backend behavior separately
from the demo; it returns a nonzero process status on a failed check.

CardDefinition is shared editor-authored configuration. CardInstance holds mutable
per-copy state. CardPiles owns combat locations, copying the input array but
preserving its card references. The original deck array is a roster, not a fifth
location. Each instance should appear in exactly one pile. Public arrays remain
accessible for now; change membership through the pile methods. Read-only
snapshots can be introduced if accidental external mutation becomes a problem.

Combatant owns health and block. Its methods finish state changes before emitting
change signals and suppress notifications for unchanged values. Backend classes
do not print normal gameplay messages; observers handle presentation.

CombatSession owns both combatants, both sets of piles, energy, turn order, and
the outcome. It validates plays, removes played cards from hand before executing
their effects, and rejects further actions after lethal damage. Its changed and
card_played signals are scoped to that encounter. The simple rival policy plays
affordable cards in hand order, with the same 3-energy budget as the player.

CardEffect Resources contain reusable configuration and an execute(source, target)
interface, with an optional EffectContext for actor piles and attack bonuses.
DamageEffect affects the target; GainBlockEffect and HealEffect affect the source.
DrawEffect uses the actor's piles from that context. The resolving card stays out
of all drawable piles until effects finish, then enters discard.
Definitions compose effects in the Inspector. Current Resources implement the
existing descriptions: 10 damage and 8 block. No runtime state is stored in them.

CardPiles.draw_cards snapshots the drawable count and stops at that limit or a
failed draw. The UI reports the actual returned count and total across all piles.
Regression checks exhaust six of ten cards and repeatedly request five, verifying
only four return and each original instance remains in exactly one pile. The
reported extra-instance issue was not reproduced against the previous draw loop;
both backend and UI coverage now explicitly protect this case.

## Signals and autoloads

A global event autoload is a valid tool, not a forbidden pattern. It is useful for
application-wide events crossing scene lifetimes, such as a run ending or a scene
transition request. Introduce it when there is an actual publisher and listener
requiring that scope.

Keep health/block signals on their Combatant and card movement signals on their
CardPiles. The object identifies the sender, so two combats or tests cannot hear
each other's events accidentally. A future combat coordinator can own encounter
events such as card_played and turn_started; relics can subscribe to that specific
encounter rather than every combat in the application. CombatSession now provides
the first such encounter-scoped signal, card_played.

Putting all events on an autoload would require sender/encounter arguments,
filtering, and explicit lifecycle management. It also hides dependencies. Avoid
publishing each event both locally and globally by default. Signals report changes;
direct method calls request actions whose validation and ordering matter.

## Review findings and next work

- Extracted demo orchestration and starter content from main.
- Removed console output from model classes and added local discard/exhaust signals.
- Preserved the corrected damage calculation and added regression checks for
  exact block absorption, lethal damage, no-op notifications, and observer timing.
- Added a non-null definition assertion to catch invalid CardInstance construction.
- Kept simple shared Combatant behavior; separate player/enemy subclasses are not
  justified yet. War Drum and the first status effect, Poison, are implemented.
- Card Resources use 10 damage and 8 block, matching current descriptions rather
  than the original brief's 6 and 5. Combat uses a 30 HP player and 40 HP rival.

War Drum is an optional player artifact with one runtime object per encounter.
Each Strike increases the attack bonus by one before damage resolves. The bonus
applies to all subsequent damage effects and resets for a new encounter. Shared
card Resources remain unchanged. Setup displays these rules and allows disabling it.

Mend, Insight, and Siphon exercise healing, drawing, and composed damage/healing.
The rival can play newly drawn cards within its energy budget; each copy is used
at most once per rival turn to bound zero-cost draw cycles. Combat history retains
200 entries and reports actual results. The UI renders that history in a scrolling
log and reads combatant health into bars. No global event bus is involved.

The standalone window starts maximized, retaining native window decorations and
the taskbar. Its restored size is 1100×700. Pages can scroll on shorter displays.
Embedded Godot game windows retain the editor's positioning. Each health bar has
a thin blue block bar across its top edge, scaled to maximum HP and hidden at
zero. Display overflow saturates at full width; actual block is never clamped.
Exact block totals are also printed on each bar. Values remain owned by the
Combatant. Poison status indicators and Poison log entries use bright green.

Rival hands are prepared before the player's turn. enemy_opening_plan reads the
prepared hand without mutation and applies the same affordability rule used in
execution. The UI shows that opening sequence and energy costs. It explicitly
marks draw effects as potentially adding follow-up plays. After the rival turn,
its remaining hand is discarded and the next hand is prepared. Previewing never
draws, reshuffles, executes effects, or consumes energy.

Poison is the first status mechanic. Combatant owns its mutable stack count,
application method, and atomic tick operation. ApplyPoisonEffect is shared Resource
configuration; Venom composes it like other card effects. Applications add stacks;
the affected side takes that many HP damage through block at its turn start, then
loses one stack. CombatSession handles turn timing, log entries, and outcome checks.
Lethal Poison prevents card execution, energy restoration, and new-hand draws.
Status counts and rules appear by each combatant. Lethal rival Poison replaces
the card intent with a warning. There is no generic status framework yet.

Rival turns now expose begin_rival_turn and advance_rival_turn. Beginning processes
turn-start effects; each advance resolves one card or transitions to the next
player turn. The existing end_turn helper runs these steps synchronously for
backend simulations. Card eligibility, energy spending, and outcome checks remain
in CombatSession. changed emits after each completed step. The table owns a child
Timer with a 0.65-second interval; leaving the table frees that timer and cancels
presentation. Player and sandbox actions are rejected during the rival turn.

Setup selects the first non-empty deck for each unselected or invalid side.
Selections persist in the UI controller during the app session. No saved deck
format change or disk preference is needed for this default behavior.

hand_card.gd renders portrait cards with an energy badge, framed emblem, effect
color, description, and action controls. It reads definitions and invokes callbacks;
it owns no gameplay state. The artwork uses local drawing primitives. The compact
table toolbar keeps the exit button visible above the larger hand.

Effects now describe their own configured values. DamageEffect uses the same
effective_damage method for execution and live descriptions. CombatSession adds
read-only artifact-aware card descriptions and direct-attack forecasts, accounting
for sequential hits, block absorption, HP clamping, and the pending Strike trigger.
Forecasts do not execute effects, alter piles, emit logs, or consume randomness.

CombatSession records actual cards played, energy spent, HP damage, damage blocked,
healing, and Poison applications for each side. Poison tick damage is credited to
the opposing side. combat_summary returns a deep snapshot. The table reports a
finished encounter once, stops its timer, and the navigation controller opens a
result panel. Rematch builds fresh runtime objects from the same selected recipes;
Review keeps the finished table and log. No reward or saved-deck changes occur.

Fast turns is a presentation setting retained by the navigation controller. It
changes only the table Timer interval. Latest-card feedback and short bar pulses
also live in presentation, while statistics and outcome rules stay in the backend.

Cadence & Rewrite is the first defining combat system. CardDefinition declares
Attack, Guard, or Tactic as content metadata. A first card or category change adds
one Cadence, capped at three. Runtime Cadence carries across turns; last_category
and the once-per-turn rewrite flag reset when a new player turn begins. These
values are encounter-local and reset for a rematch. Forecasting never grants it.

rewrite_intent validates phase, outcome, resource cost, target membership, and
whether the move changes order. It moves that specific instance to the back of
enemy_piles.hand, spends two Cadence, records a statistic, and emits changed after
the mutation. The plan and rival execution both read the same hand order. No
cards are created, discarded, or removed from combat by rewriting. The whole
prepared hand is visible in a compact horizontal row with planned/reserve styling.

Crosscut and Switchback compose existing draw/damage/block Resources with explicit
categories. Counterpoint is an opt-in deck recipe for existing saves; its creation
does not rewrite other recipes or require a save format migration.

Next: playtest Cadence gain, Rewrite cost, and rival reserve composition before
designing encounter progression and rewards. See game_direction.md.
