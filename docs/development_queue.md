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
  but the binding is listed in Options. See `table_screen.gd` and
  `options_menu.gd`. This remains a follow-up.
- All eight headless Godot 4.7.2 suites passed. Logs are under
  `.godot/batch3-final-*.log`.
- Hardware checks still open: run the post-duel sequence with a physical
  controller, and tap through guided Rewrite on a touch device.

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
