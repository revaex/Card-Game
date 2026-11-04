# Current architecture and review

`main.gd` starts `ui/game_ui.gd`. That controller owns menu navigation and deck
editing. `ui/table_screen.gd` owns combat presentation; neither implements
combat rules. Shared colors and control helpers live in `ui/ui_style.gd`.
`content/deck_library.gd` saves deck recipes as names and card-ID counts; it creates
fresh instances for each side. UI saves are separate from the read-only `.tres` content.
`debug/backend_demo.gd` retains the previous console exercises for learning.
`content/starter_deck.gd` creates the prototype's ten fresh card instances.
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
interface. DamageEffect affects the target; GainBlockEffect affects the source.
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
  justified yet. Artifacts and status effects remain future work.
- Card Resources use 10 damage and 8 block, matching current descriptions rather
  than the original brief's 6 and 5. Combat uses a 30 HP player and 40 HP rival.

Next: discuss enemy intent presentation and artifact timing before adding relic
behavior. War Drum's bonus timing, scope, and reset rules still need a decision.
