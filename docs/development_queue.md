# Ink & Intent development queue

Use the [project brief](project_brief.md) for collaboration and architecture,
the [release roadmap](release_roadmap.md) for milestones, and the
[feature shortlist](feature_shortlist.md) for experiments. Keep this queue
limited to the current batch and confirmed follow-up work.

## Batch 1 — verify the three-rival slice

| Ticket | State | Completion check |
| --- | --- | --- |
| B1-01 Controller inspection and focus | Automated checks passed | Rewrite expansion passed all 51 checks and UI smoke passed on Godot 4.7.2. Physical controller checks remain. |
| B1-02 Packaged Journey recovery | Startup checks passed; menu checks deferred | Verified the Windows release's victory reconciliation, duplicate payout prevention, and restart after forcibly stopping an older build. Chapter and reward menu checks require an interactive Windows session. |
| B1-03 Release-blocker fixes and handoff | Automated checks passed | All eight existing headless suites passed. No game blocker reproduced. See the remaining manual checks below. |

### Batch 1 evidence

- Windows release exported with Godot 4.7.2 from `87bd537` to
  `builds/batch1-windows/`. A headless startup exited successfully.
  SHA-256 executable `3F147B3FF1546850A82651B62598D047C705FDBA9EE988D3D861681F3F709A4C`,
  PCK `0DAB1FAB6E0A1E666A80B932D2DAB9DE4937B834DEEF30DC00350C1E769E786B`.
- A source-side QA script seeded a pending victory checkpoint under an
  isolated APPDATA. With the profile moved aside, the packaged build
  restored the missing 20 Marks on first startup. A second clean startup
  preserved 20 Marks.
- In a separate isolated profile, the older local Windows package consumed
  the same seeded victory and wrote 20 Marks. After forcibly stopping that
  process, the new package launched and preserved the 20 Marks. This verifies
  that the new build reads the older build's Marks receipt. The checkpoint
  itself was seeded using current source. Older package PCK SHA-256
  `DC70B63B02A7907B54FC9FF0438B99150469D6697A4D05A2E899E1986097757C`.
- Final headless run passed backend (312), board feedback (23), editor scenes
  (60), guided duel, Journey checkpoint, relic progression, Rewrite expansion
  (51), and UI smoke. Logs are under `.godot/batch1-final-*.log`.
- Remaining Windows menu checks require a manual tester or working Windows
  UI control. The computer-use runtime failed initialization twice with
  `failed to write kernel assets` (OS error 3). In the packaged game, start a
  Journey, quit and force-exit at chapter entry, pending reward, and after
  reward selection, then verify Continue Journey returns to the saved
  boundary. Repeat the upgrade with a checkpoint created through the older
  package's menus. Verify shoulder navigation and inspection with a physical
  controller.

## Batch 2 — controller navigation and Journey recovery audit

- **Controller navigation verified.** The result popup keeps focus on its three
  actions. UI smoke covers stick movement in all four directions, Confirm on
  Choose your next step, and Confirm on Review. UI smoke, guided duel, and all
  51 Rewrite checks passed. Physical controller testing remains open.
- **Journey recovery verified in-process.** The read-only audit passed the
  Journey checkpoint and relic progression suites. Start a Journey, take
  damage in chapter one, and recreate the UI to resume at chapter entry with
  30 HP. Win and reopen Continue Journey to resume the pending reward with
  20 Marks, then revise a card and reopen to verify the next chapter keeps the
  revision. Make the profile unwritable for the next victory, then reopen
  with a writable profile to verify recovery brings the balance to 40 Marks.
  Packaged menu and forced-exit checks remain listed under Batch 1.

## Batch 3 — post-duel controller flow and Rewrite onboarding

- Journey results now open a confirmation before ending the run. Cancel
  receives initial focus, either horizontal direction switches actions, and
  controller Back closes the dialog and restores focus to the result action.
  UI smoke exercises cancel and confirm on successive victories.
- Review focuses Encounter results on the finished table so Confirm can
  reopen the popup. Entering rewards focuses the first draft card. UI smoke
  confirms a draft and checks that it advances the Journey exactly once.
  The victory popup still confines stick navigation to its actions.
- The read-only onboarding audit found that tapping the highlighted rival
  Strike after playing Strike and Block could stall the guided duel.
  `table_screen.gd` now sends that tap to the lesson's validated Rewrite
  action. The guided-duel suite exercises the touch activation path and
  verifies that Strike drops out of the affordable line. Regular combat
  retains touch inspection and confirmation.
- The audit also found a discoverability issue in the first Journey fight.
  Reach two Cadence with a controller and check the board's shortcut hints.
  The opposite shoulder focuses the rival line and shows a Rewrite preview,
  but the binding was listed only in Options. Batch 4 addresses this.
- All eight headless Godot 4.7.2 suites passed. Logs are under
  `.godot/batch3-final-*.log`.
- Hardware checks still open: run the post-duel sequence with a physical
  controller, and tap through guided Rewrite on a touch device.

## Batch 4 — rival-line shortcut and victory popup input

- The prepared rival line displays **Focus line** with the active keyboard
  and controller bindings. UI smoke covers both shoulder layouts, rebound
  inputs, and disabled combat shortcuts. At two Cadence, focusing the line
  shows the Rewrite forecast and leaves Cadence available.
- In the pre-fix smoke test, View/Select opened the table's Pattern Guide
  while victory results were active. The table now suspends shortcut input
  until results close. UI smoke verifies that View/Select leaves focus on
  the popup and that Review, reopening results, and Journey reward entry
  still work.
- All eight headless Godot 4.7.2 suites passed. Logs are under
  `.godot/batch4-final-*.log`. Rendered captures at 1100 × 700 show the
  hint alongside both the Rewrite-ready status and the live preview.
- The local Windows build in `builds/batch4-windows/` passed headless startup.
  In an isolated profile, start a Journey with the Starter deck, enter
  chapter one, and play Block and Strike. PageDown focused the rival Strike
  and previewed Rewrite with Cadence still at two. Winning through the menus
  recorded 20 Marks. A headless restart preserved the pending reward
  checkpoint and the 20-Mark receipt byte for byte. PCK SHA-256
  `D8F5F8886A4A680EC1D268BF2DEB9BD66D209288E5680EC5ECBBE45C88FD0144`.
- A mouse tooltip for End Turn was visible over the first packaged victory
  capture. To check whether it persists, leave the pointer over End Turn
  after clicking it, then use the keyboard to win on the next turn. The
  tooltip should clear when results open. Duration is unverified.
- The full packaged Continue Journey menu matrix and older-build menu
  upgrade remain open, along with the physical controller and touch checks.

## Batch 5 — deck workshop and Margin Burn playtest

| Ticket | State | Completion check |
| --- | --- | --- |
| B5-01 Workshop and Journey entry | Implemented | Click or Confirm to add. Remove from the tray or catalogue and see both counts update. Reload an old 15-card recipe with three Inkblots, reject it at Journey entry, then repair it with one removal. Custom duels accept the old recipe. |
| B5-02 Margin Burn | Opt-in prototype | In each standalone rival duel, preview a sacrifice and cancel, then exhaust the selected copy at zero energy for up to 2 Cadence. The action stays spent across turns. Check availability after an earlier Rewrite and against a sealed line. Playtests are excluded from progression. |
| B5-03 Rewrite inspection | Implemented | Inspect the Scribe's opening Inkblot with 2 Cadence. Read which card moves to reserve and which cards enter alongside the existing HP loss and Poison deltas. |

All eight Godot 4.7.2 headless suites passed, including 62 Rewrite expansion
checks and the workshop and three-rival playtest paths in UI smoke. Logs are
under `.godot/batch5-final-*.log`. Godot rendered the workshop, playtest
dialog, and Rewrite inspection at 1100 × 700. Hardware controller and touch
checks remain open. In a manual playtest against each
rival, record which card was sacrificed, whether the extra Cadence changed
the chosen Rewrite, and whether burning at the cap was worthwhile for
thinning. Use those results before selecting the first card unlocks or
relics from the [shortlist](feature_shortlist.md#deck-building-exhaust-and-relic-experiments).

## Next local playtest batch

1. Capture a repeat Scribe encounter with the owner's deck if available.
   A controlled source probe on the Batch 5 working tree (base `41acdeb`,
   Godot 4.7.2) used four Strikes, two Blocks, two Insights and two Mends
   without a relic. The draw order was Block, Insight, Strike, Block, Mend,
   Insight, Mend, Strike, Strike, Strike. Inkblot and Venom resolved for
   4 Block and 7 Poison. Rewriting Inkblot brought in Insight and Siphon, leaving 0 rival
   Block and 3 Poison applied. Both scripted openings won on turn two.
   The Riposte route triggered Final Revision and got through 4 Block with
   two Strikes. The Rewrite route faced 25 HP and used three Strikes.
   Logs are in `.godot/batch5-scribe-probe.log`. The reported repeated Block
   buildup and human clear times remain unverified.
2. Play the fixed-opening Scribe puzzle from **Challenge a rival**. Try both
   Rewrite and Riposte. Compare repeat clear times against the 2–4 minute
   target using the result timer, and record how the player found the opening.
3. Try the same duel on a landscape Android device. Verify readable forecast,
   tap inspection, explicit actions, Back, and interruption at a turn boundary
   and pending rewards. Record the device and build. Physical hardware is required.

See [short rival puzzles](feature_shortlist.md#short-rival-puzzles-and-mobile-replay)
for reward and challenge candidates, [deck building and Exhaust](feature_shortlist.md#deck-building-and-exhaust)
for separate prototypes, and [title and demo handoff](release_roadmap.md#title-and-demo-handoff)
for work gated on the final name. The Batch 1–4 manual checks remain open.

## Batch 6 — Journey playthrough feedback

| Ticket | Acceptance check |
| --- | --- |
| B6-01 Useful tutorial payoff | Rewrite reduces the forecast from 12 to 2 HP loss after Block. Insight draws two cards and finishes Shelter. Playback absorbs the remaining Strike and the player finishes at full health. Exit to the main menu or continue to Journey setup. |
| B6-02 Workshop feedback | Drop a catalogue card in the tray and add exactly one copy. Click and Confirm use the same feedback. An invalid Journey recipe shows its size range and selected count in red. |
| B6-03 Combat and menu input | L3 opens Inspect and A executes a legal Rewrite after closing it. Y ends the turn regardless of the optional focus shortcuts. Right-stick vertical input scrolls the log. Options can return to the main menu. |
| B6-04 Readable progression and help | Focus is visible on a gold button. The Journey reward action is gold. The first Pattern Guide page shows all three rewards and Back closes it. |

All eight Godot 4.7.2 headless suites passed. UI smoke also passed after
the catalogue was made independently scrollable, including a drag from
the bottom of the catalogue into the tray. A 1100 × 700 rendered check
confirmed focus contrast, the red Journey size message, and the Pattern
overview. Injected right-stick input scrolled the rendered log in both
directions. Physical controller and touch testing remain open.
Logs are under `.godot/batch6-final-*.log` and `.godot/batch6-render.log`.

The owner reported that Inspect could repeatedly intercept Rewrite for the
rest of a run. Rival cards now handle inspection from the current touch or
right-click event, or the Inspect binding. Their normal Confirm path goes
directly through Rewrite's legality check and ignores earlier touch state.
Regression checks cover closing touch and L3 inspection before pressing A.

For the next owner playtest, record Counterpoint's chapter-one HP and whether
the first Mend arrives when it can help. Compare one opening difficulty or
healing change at a time. Other gameplay experiments are in the
[playthrough shortlist](feature_shortlist.md#journey-playthrough-follow-ups).

## Batch 7 — Scribe practice and sustain comparison

- **Scribe puzzle.** The Scribe's rival card offers a standalone practice
  duel with the supplied deck from the Batch 5 probe. Both openings win in
  the scripted check. Rematch restores the fixed opening, results show
  elapsed practice time, and victories award no progression. Human timing
  and difficulty are still open.
- **Counterpoint · Sustain.** Add the preset from the deck library to compare
  Counterpoint with a second Mend in place of Venom. Log chapter-entry HP,
  healing actually used, and damage or tempo lost from the swap. Keep rival
  order fixed for this comparison.
- All eight Godot 4.7.2 headless suites passed. UI smoke covers both puzzle
  wins, rematch, elapsed time, and the sustain recipe. Rival selection and
  puzzle results were checked at 1100 × 700.

## Batch 8 — workshop, puzzle, and combat usability

1. Search the catalogue by card name.
2. Filter the catalogue by category.
3. Show only cards with copies in the current deck.
4. Duplicate a recipe without sharing its card counts.
5. Rename a deck and persist the name on reload.
6. Edit the selected recipe from duel setup and return there with Done.
7. Restart the Scribe puzzle directly from the table.
8. Show the fastest Scribe clear in the current app session.
9. Show the locked Pattern's payoff beside its next step.
10. Explain why Rewrite is unavailable on an attempted click or Confirm.

## Batch 9 — practice and deck selection

1. Fixed-opening Duelist practice.
2. Fixed-opening Warden practice.
3. Poison Pressure preset with Poison and sustain.
4. Riposte Guard preset with defensive setup and finishing hits.
5. Surge Cycle preset with free attacks and draw.
6. Deck library search by recipe name.
7. Deck library filter for Journey-ready recipes.
8. Swap selected decks in a custom duel.
9. Show category totals in the saved-deck browser.
10. Count practice attempts per rival for the current session.

Practice uses the supplied ten-card deck and awards no progression. Session
bests are tracked per rival. Test the new rivals for human clear times and
whether the opening problem reads clearly. Compare the new presets without
changing the Journey route or the default decks.

## Batch 10 — deck analysis and practice scouting

1. Search catalogue card effects as well as names.
2. Filter catalogue cards by energy cost.
3. Clear all catalogue filters with one action.
4. Sort saved recipes by name without changing their stored order.
5. Show the selected recipe's energy curve in the deck tray.
6. Count healing cards in the recipe.
7. Count cards that deal direct damage or apply Poison.
8. Scout a rival's opening line and advice from rival selection.
9. Count practice wins per rival in the current session.
10. Track the fewest turns in a practice win per rival in the current session.

Margin Burn follow-up: controller Up reaches the sacrifice dropdown from
either action. Down returns to Cancel. Confirm on the dropdown opens the
card list without spending the action.

## Batch 11 — rival line readability

- Show the next-hand doctrine and add rival line rules to the Pattern Guide.
- Forecast visible energy spent and unused, player Block used, rival Block
  gained, and potential rival healing.
- Show Rewrite's energy and rival Block changes and the revised affordable
  order in inspection.
- Show the affordable opening and doctrine in rival scouting.
- Count Block, draw, and Counterwritten cards in the deck tray.

### Queue experiments in practice

1. Playtest strict stopping independently. Check 1 → 1 → 2 → 1 with
   3 energy and include a free card after the unaffordable card. Compare
   forecast against playback.
2. Playtest visible carryover independently. After three Strikes resolve,
   two unplayed Blocks should remain in order at the front of the next
   hand. Doctrine orders new draws only. Final Revision seals the first
   slot, even when occupied by a carried card.
3. Compare the combined rules after each is understandable alone. Track
   energy denied by Rewrite, stalled lines, and whether players can explain
   their next-turn plan.

## Batch 13 — rival queue practice rules

Use **Challenge a rival → Practice rules** to test strict stopping, carry
reserves, or 3 Cadence for 1 energy. Each option is independent. The energy
purchase is limited to once per player turn. Journey and normal challenges
keep their existing rules. The practice scout compares the selected rules
with the standard opening. Practice rematches retain the rules and track
records per combination. Results show unused rival energy on completed
rival turns, strict queue stops, and cards carried. Lab tools are hidden
in timed practice.

Draw effects append to the rival line. Carryover retains the order of the
unplayed cards and fills open slots to five. Draw overflow may leave more
than five carried cards. Copies already played in the same turn cannot
play again if redrawn and do not carry as unplayed reserves.

Next playtest: compare standard, strict only, carry only, and both against
the same rival. Record whether the player can explain the first blocker
and the carried prefix before End turn. Test Cadence energy separately to
see whether players give up meaningful Rewrite opportunities.

Example fixture: with 3 energy, the strict 1 → 1 → 2 → 0 → 1 line
plays the first two cards and leaves 1 energy. With carryover enabled,
the 2 → 0 → 1 prefix remains visible in that order next turn.
The combined rules were rendered at 1100 × 700 with the forecast, controls,
and complete hand visible.

## Batch 12 — workshop card and deck playtest

Twelve opt-in workshop cards use existing effect Resources. The default
decks, rival decks, and Journey reward pools keep their current recipes.

| Category | Cards and playtest hooks |
| --- | --- |
| Attack | Parry Cut mixes damage and Block. Double Notch hits twice for Riposte. Venom Edge mixes damage and Poison. Reclaiming Cut heals after Rewrite. |
| Guard | Field Dressing mixes Block and healing. Loose Leaf offers free Block and conditional draw. Folio Wall trades two energy for Block and a draw. Bitter Guard applies Poison after Rewrite. |
| Tactic | Breathing Room draws and heals. Tainted Index cycles while applying Poison. Restoration spends two energy on healing and Block. Revision Note deals light damage and draws after Rewrite. |

Eight presets are available under **Deck library → Add a preset**.
Measured Guard, Twin Riposte, Toxic Ledger, Rewrite Engine, Recovery Line,
Zero Margin, Shelter Archive, and Poison and Steel each use a legal
ten-card Journey recipe with all three categories.

Playtest the values before putting these cards into progression. Compare
Double Notch's Riposte burst, Loose Leaf's free play and conditional draw,
and how often the healing decks trade useful pressure for recovery.

## Run a batch

Work in priority order on a local feature branch. For each ticket, reproduce,
make the smallest fix, run targeted checks, and record the result here before
moving on. Run the full suite once at the end. Keep the batch ready for review
and leave the push to the owner. Record any external dependency against the
affected ticket and continue independent work.

Use one agent by default. Delegate at most one independent task when explicitly
requested. Give parallel writers separate worktrees from the same base commit
and distinct file ownership. Review both diffs and rerun combined checks after
any authorized local integration.

For new playtest findings, record the build, input method, reproduction steps,
expected behavior, and actual behavior. Prioritize blocked progress and save
loss. Keep new gameplay experiments in the shortlist until selected. Mark work
the owner wants to implement as owner-led.
