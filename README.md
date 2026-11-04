# Card-Game

An independent card roguelike in active development with Godot 4.x and GDScript.
The aim is a distinctive indie release built around readable tactics and expressive
deckbuilding. Cadence & Rewrite is the current defining combat rule; the working
title, setting, and balance will develop through playtesting.

## Cadence & Rewrite

Attack, Guard, and Tactic are the three card categories. The first card each turn,
or a change from the previous category, earns 1 Cadence (maximum 3). Repeating a
category earns none. Cadence carries between turns and resets each encounter.

Spend 2 Cadence once per turn by clicking a card in the rival's prepared line to
move it to the back of that hand. This can push an attack beyond the rival's
energy budget or change the order of its effects. Bright cards are currently
planned; dim cards are reserves. Drawing may bring additional cards into play.
The line updates immediately and execution follows its new order. Rewrite costs
no energy, cannot move the last card, and is unavailable during the rival's turn.

Crosscut (Attack) deals 7 damage and draws a card. Switchback (Guard) gains 4 block
and draws a card. Both cost 1 energy and help build changing sequences. Use
**Manage decks → Add Counterpoint** to add a ready-made ten-card deck without
changing existing decks. New installations include Counterpoint automatically.

## Playing

Open `project.godot` in Godot. Press F6 with a chosen scene, or F5 to run
`scenes/main.tscn`. F5 opens the main menu. Choose Start game, select player and
enemy decks, then Confirm to open the table. Manage decks creates, edits, and
removes local deck recipes; changes save to Godot's `user://decks.json`.
The initial Starter deck is available on first launch. Empty decks cannot be selected.
Both sides automatically select the first non-empty deck. Choices are remembered
while the game is open, including when leaving and returning to the table.

The table now runs a small combat: you have 30 HP, the rival has 40 HP, and each
side gets 3 energy per turn. Play Strike for 10 damage or Block for 8 block.
Played cards enter discard. End Turn discards your hand, lets the rival play
affordable cards from its prepared hand, then prepares both sides' next hands.
Block clears at the start of its owner's next turn. Lethal damage ends combat.
The table includes HP bars and a scrolling log for both sides' actions and results.
The window starts maximized with its normal title bar and window controls.
Restore it to use the smaller 1100×700 window size. Block appears as a thin blue
bar over each HP bar, using maximum HP as its full-width scale. Exact block also
appears on the bar; amounts above that scale remain fully effective. The blue
bar disappears at zero. Poison indicators and log entries are green.
Rival intent shows its affordable prepared cards in play order;
draw effects can add follow-up plays during its turn.

Manage decks also offers Mend (heal 6), Insight (draw 2), and Siphon (deal 5,
heal 3), each costing 1 energy. Add these to existing recipes to try the effects.
Venom costs 1 energy and applies 3 Poison. Poison stacks add together. At the
affected side's turn start, Poison deals HP damage through block, then loses one
stack. Turn-start lethal damage ends combat before any cards can be played.
Poison counts appear by each combatant; hover for rules. Applications and ticks
also appear in the combat log. Poison resets for a new encounter.
Rival actions resolve one card every 0.65 seconds, updating bars and the log after
each card. Player actions stay disabled until your turn; leaving cancels playback.
Hand cards use portrait frames, energy badges, effect colors, and drawn emblems.
Card text updates with artifact bonuses, including the next Strike's War Drum
trigger. Hover or focus a playable card to forecast direct HP damage, absorbed
damage, and lethal hits. Combat results show both sides' encounter statistics,
with Rematch, Choose decks, and Review options. Fast turns in the table toolbar
reduces the rival card interval to 0.2 seconds; the choice lasts for the app session.
New installations include an Effects demo recipe. The optional War Drum on the
setup screen gives +1 attack damage each time you play Strike, before resolving
that Strike. It stacks for the encounter, boosts subsequent attacks, and resets
when you leave the table.
Click piles to inspect their contents. Enable Pile testing tools for free drawing,
redrawing, and exhausting; these are debugging controls rather than combat rules.
Draws stop at the available number of cards, excluding hand and exhaust.
UI nodes are constructed by scripts under `scripts/ui/`; they appear when running.

## Project layout

```text
assets/               Artwork and audio when needed
data/cards/           Editor-authored card definitions (.tres)
data/artifacts/       Editor-authored artifact definitions (.tres)
scenes/main.tscn      Minimal entry scene
scripts/main.gd       Startup only
scripts/debug/        Previous manual backend demo (available for learning)
scripts/ui/           Menu, deck editor/selection, table, and visual helpers
scripts/content/      Starter deck construction
scripts/cards/        Card definitions and runtime instances
scripts/effects/      Reusable editor-authored damage and block Resources
scripts/combat/       Combatants and the combat session/turn rules
scripts/decks/        Hand and card pile movement
scripts/artifacts/    Future artifact behavior
tests/                Automated backend checks
docs/                 Architecture, design direction, and early design exercises
```

Folders are starting points, not a fixed class architecture. Empty folders use
`.gitkeep` so Git preserves them. Card instances, piles, and combatants are
implemented. See `docs/architecture.md` for ownership and signal decisions.

Run automated checks from the project folder (substitute your Godot executable):

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
```

The runner prints totals and exits with status 1 if any check fails.
Use the same command with `--script res://tests/ui_smoke.gd` to check navigation,
deck persistence, selection, removal, opening hands, and pile actions. Its save
fixture lives in ignored `.godot/`, separate from your real saved decks.

Godot should scan external changes when you return focus to its editor.
Ensure the open project is `C:/Git Repos/card-game/project.godot`.

## Local Git workflow

The existing remote is named `Card-Game` and points to
https://github.com/revaex/Card-Game. The current branch is `master`.
Make small commits at meaningful checkpoints and push regularly.

Before work, with a clean working tree:

```powershell
git status
git pull --ff-only Card-Game master
```

At a checkpoint:

```powershell
git diff
git add README.md docs scenes scripts assets data tests .gitignore project.godot
git diff --cached
git commit -m "Improve combat flow"
git push -u Card-Game master
```

Review staged files before committing. `.godot/` is generated locally and ignored;
Godot `.uid` and asset `.import` sidecars should remain versioned.
