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

## Short rival puzzles and mobile replay

A player reported that the third rival repeatedly built a large Block buffer
while Poison chipped away in the background. Breaking through felt like a
puzzle. The exact card and Block total are unverified. Capture a prepared line
and deck from a repeat encounter before tuning it. Preserve the need to find a
damage window and watch for turns spent repeating the same ineffective play.

Playtest the standalone Scribe duel with a fixed opening and a supplied deck
from [Batch 7](development_queue.md#batch-7--scribe-practice-and-sustain-comparison).
Make the current forecast identify the defensive card and show which move takes
its place when rewritten. Give the deck two plausible answers: displace the
defensive move before it resolves, or assemble a Riposte burst to punch through.
Try the opening, a midfight line, and Final Revision before adding new cards.
For comparison, test the Duelist as an attack-sequencing puzzle and the Warden
as a sealed-line puzzle where moving a neighboring card matters.

Aim for 2–4 minutes from first decision to results on a repeat clear. Treat
five minutes as a playtest signal. Record retries, time spent watching playback,
whether players can explain their winning decision, and whether two different
approaches succeed. Offer a one-tap rematch and retain the three-rival Journey
for longer sessions. Keep the tactical forecast visible at fast playback speed.

Guarantee a first-win choice of themed sidegrades. The Scribe's pool could
include a Block card that gets stronger after Rewrite and a Guard that buys
time against Poison. Give repeat clears a visible route to a chosen unlock via
Marks or a rival feat. Test this before adding optional earned random drops.
Show unlock requirements in the card catalogue and keep reward claims tied to
the completed encounter so a restart cannot award the same prize twice.

Start recurring play with a weekly fixed-deck puzzle. Keep a practice archive,
allow retries, and award one completion prize per challenge. Try daily puzzles
only if there is enough variety to sustain them. Skip streak penalties and
paid retries. If a shop earns its place, use earned Marks for gameplay rewards
and consider direct-price cosmetics or a clearly described expansion for real
money. Keep power unlocks available through play and purchases deterministic.

## Deck building, Exhaust, and relic experiments

The [Batch 5 prototype](development_queue.md#batch-5--deck-workshop-and-margin-burn-playtest)
adds catalogue click and Confirm, a removal tray, provisional Journey entry
rules, and explicit card movement in Rewrite inspection. Margin Burn is
available in opt-in standalone playtests. Measure the value of an early
Rewrite and the effect of thinning before choosing a progression role for it.
The [workshop follow-up](development_queue.md#batch-8--workshop-puzzle-and-combat-usability)
adds catalogue filters, recipe duplication and renaming, and a direct edit
path from duel setup.

- Use a card catalogue beside the selected deck. Click or Confirm to add a
  copy, allow drag to add, and remove from the deck side. Show the count,
  category mix, and equipped relic. Keep locked cards inspectable with the
  exact unlock requirement.
- Playtest 10–14 cards and at most two copies of each non-starter card.
  Starter cards can fill remaining slots. Keep legacy decks editable and
  flag invalid recipes at Journey entry. Use shared validation. Start with
  the current draw size and test consistency versus flexibility before
  trying a relic that rewards cycling a larger deck.
- Start with two playable deck styles and try six earnable cards across
  three styles. Unlock each card definition once through rival feats or
  deterministic Marks purchases. Deck rules govern the number of copies.
- Prototype **Margin Burn** once per duel at zero energy. Exhaust one card
  in hand to gain two Cadence. Preview the sacrifice, resulting Cadence,
  and whether Rewrite is still available. Test across all three rivals.
  Try **Reprise** separately as a card that sets another card aside and
  returns it next turn at zero cost.
- Equip one relic per deck. Test **Red Thread** for five Block on the
  first Rewrite that changes the affordable line, **Pattern Seal** for a
  one-energy discount after the first completed Pattern, and **Ash
  Bookmark** for a one-energy discount on the first card next turn after
  Exhausting a card. Treat these values as playtest candidates.
- Make the Rewrite preview show which cards leave and enter the affordable
  line and the resulting change in projected damage and Poison.

## Deck building and Exhaust

- **Deck workshop.** Prototype an inspectable card grid beside a deck tray.
  Click or use Confirm to add a copy, with drag optional and removal on the
  deck side. Keep locked cards visible with their unlock requirement. Show
  count, category mix and the deck's relic. Test 10–14 cards and a two-copy
  cap on non-starters as provisional values. Keep old recipes editable and
  validate at encounter entry. Compare lean and broad decks before adding a
  size-dependent rule. Keep unrestricted decks available for sandbox testing.
- **Unlocks and relics.** Use rival feats and earned Marks for selected
  sidegrades. Unlock card definitions once and apply deck copy rules separately.
  Trial one relic per deck with distinct payoffs for rewriting the affordable
  line, completing a Pattern, or sacrificing a card. Keep unlock ownership in
  the profile and combat triggers in session state.
- **Margin Burn.** Prototype a once-per-duel action at zero energy. Exhaust a
  card in hand for 2 Cadence, subject to the existing cap. Preview the gain and
  whether Rewrite is still available. Test whether the player values the
  immediate answer enough to lose a future draw, and whether thinning dominates.
  Reprise, which sets a card aside for a free play next turn, is a separate candidate.

## Current Pattern rules

The [workshop content batch](development_queue.md#batch-12--workshop-card-and-deck-playtest)
adds optional cards and presets for testing these payoffs. Tune them
against the existing three-rival route before selecting unlocks or rewards.

- Attack → Guard → Tactic: **Shelter**, gain 6 block before the last card.
- Guard → Tactic → Attack: **Riposte**, the last card gains +6 damage per hit.
- Tactic → Attack → Guard: **Surge**, gain 1 energy before the last card.

The first card locks a Pattern. The next two matching cards follow the
Attack → Guard → Tactic cycle from that starting category. One Pattern can
complete per turn. Other cards and Cadence spends leave the sequence in place
until the next turn.
The three recipes are editable Resources under `data/patterns/`. Their numbers are
initial balance values to test against actual play decisions.

## Journey playthrough follow-ups

The owner's full Journey raised these candidates. The implemented feedback
fixes and their checks are tracked in the [development queue](development_queue.md#batch-6--journey-playthrough-feedback).

| Candidate | Current evidence and next check |
| --- | --- |
| Teach two playstyles | The revised opening makes Rewrite and Shelter each prevent damage. A follow-up Scribe lesson could let the player choose between disrupting Inkblot and using Riposte to punch through its Block. Test whether players can explain both routes and identify cards that support each. |
| Deck size | 10–14 is a provisional playtest range. With five draws per turn, ten cards make two ordinary hands, while larger decks spread key cards across more turns. Compare 10, 12, and 14 with matched card mixes and log early Pattern completion and win rate. Decide where to show or enforce the rule after testing. Entry validation currently applies to the saved starting recipe. Drafts and removals can change the in-run count. |
| Sustain and rival order | The owner found the Duelist challenging with Counterpoint and felt it belonged later. Counterpoint has one Mend, the Strike/Block Starter has none, and the first two wins offer a separate 8-HP recovery choice. The current draft pools have no dedicated healing card. Compare HP after each chapter with Counterpoint, then try a softer Duelist opener or a later Duelist slot. Test a healing card as a draft or preset variant separately so its effect is measurable. |
| Pattern continuation | After Surge, the next Tactic completes the overlapping Attack → Guard → Tactic sequence. Prototype one half-strength follow-through per turn starting with 3 Block for Shelter. Check how it changes sequencing and Surge's advantage. Half an energy needs a separate rule before extending it to every Pattern. |
| More Cadence spends | Try 3 Cadence for 1 energy, 2 for a 5-damage hit, or a small heal such as 3 HP in separate trials. Measure whether they crowd out Rewrite or reward stalling to farm healing. Define how damage interacts with Block before testing it. |
| Reserve carryover | Reserve currently means outside the current affordable line. Remaining cards are discarded, then the next hand draws and the rival's doctrine orders it. Prototype a visible carried prefix in its final revised order, then fill the rest of the hand normally. Decide how draws and sealed phase openings interact with the prefix. Compare how often players can use the extra information and whether Rewrite becomes too strong across consecutive turns. |
| Strict queue | Try stopping at the first unaffordable card. With 3 energy, a 1 → 1 → 2 → 1 line should end with 1 energy unspent. Test the version where free cards behind the blocker also wait. Compare with the current skip rule, where the final 1-cost card resolves. Keep this experiment separate from reserve carryover at first. |

Strict queue, reserve carryover, and the Cadence energy trade are available
as independent [practice experiments](development_queue.md#batch-13--rival-queue-practice-rules).
Damage and healing Cadence spends and Pattern continuation remain candidates.
