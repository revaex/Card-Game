# Identity and feature shortlist

Working creative direction: a travelling duelist who edits an opponent's written
future. Prepared hands are lines of intent; players build their own Patterns while
rewriting the opposing line. Ink, parchment, visible revisions, and distinctive
duelist silhouettes can give the rules a coherent visual language.

The core promise is: **read their next move, change its place, compose your answer.**

| Feature | Why it belongs | Decision |
| --- | --- | --- |
| Cadence & Rewrite | Card-category changes buy control over the rival's sequence. | Implemented core. |
| Three-card Patterns | Order chooses between defense, a stronger finisher, and another play. | Implemented core. |
| Rival doctrines | Each rival has a readable way of composing its prepared line. | Implemented: Duelist, Warden, Scribe. |
| Anchored intentions | Clearly marked moves resist rewriting, creating control puzzles. | Implemented in the Scribe's Final Revision: first prepared card is sealed; other cards remain editable. |
| Counterwritten cards | Cards gain effects when the player rewrites or targets enter reserve. | Implemented after-Rewrite effects: Errata, Paper Trail, Second Reading; a ten-card preset and chapter-two draft. |
| Borrowed intentions | A displaced rival move becomes a temporary player card. | Try one rare card after core balance. |
| Card editing | Between encounters, change a card's category instead of taking recovery. | Implemented: per-copy category revisions in a journey. |
| Pattern sidegrades | A run changes one Pattern payoff, altering how a familiar deck is sequenced. | Try after a short run exists. |
| Line terrain | A visible position changes the rival card played there. | Later experiment; adds another spatial rule. |
| Duel contracts | Optional goals such as never repeating a category earn special edits. | After progression and baseline rewards. |
| The Redactor boss | A boss visibly revises its line in response to the player's control. | Boss candidate; reactions must be telegraphed. |
| Rival memory | A returning character visibly prepares against earlier choices. | Narrative milestone, not opaque adaptive difficulty. |
| Branching manuscript | Routes alter the next rivals, rule modifiers, and available edits. | Progression presentation candidate. |
| Duel scorecards | Results highlight Patterns, rewrites, and damage prevented by control. | Counts Patterns, rewrites, planned-to-reserve displacements, and Counterwritten plays. Displacements deliberately do not claim damage prevented. |
| Daily written duels | A fixed deck and prepared line create a comparable tactical challenge. | Post-core replayability. |

## Chosen path

Keep Cadence, Rewrite, and Patterns as the identity pillars. The three rivals and
short journey with category-editing sidegrades are now playable. Test health
carryover, recovery versus revision, and whether the same edited card opens a
different sequence. Add one new rule at a time and measure whether it creates a
decision that the current system cannot already express.

First check that Rewrite isn't always best spent on the first attack, that each
Pattern has useful situations, and that players understand the rival line without
opening a rulebook. The shortlist is a pool of candidates, not a promise to build
every feature.

## Current Pattern rules

- Attack → Guard → Tactic: **Shelter**, gain 6 block before the last card.
- Guard → Tactic → Attack: **Riposte**, the last card gains +6 damage per hit.
- Tactic → Attack → Guard: **Surge**, gain 1 energy before the last card.

The first card locks a Pattern. The next two matching cards follow the
Attack → Guard → Tactic cycle from that starting category. One Pattern can
complete per turn. Other cards and Cadence spends leave the sequence in place
until the next turn.
The three recipes are editable Resources under `data/patterns/`. Their numbers are
initial balance values to test against actual play decisions.
