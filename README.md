# Card-Game

A Godot 4.x / GDScript card roguelike, developed backend first as a learning project.

Open `project.godot` in Godot. Press F6 with a chosen scene, or F5 to run
`scenes/main.tscn`. F5 opens the main menu. Choose Start game, select player and
enemy decks, then Confirm to open the table. Manage decks creates, edits, and
removes local deck recipes; changes save to Godot's `user://decks.json`.
The initial Starter deck is available on first launch. Empty decks cannot be selected.

The table now runs a small combat: you have 30 HP, the rival has 40 HP, and each
side gets 3 energy per turn. Play Strike for 10 damage or Block for 8 block.
Played cards enter discard. End Turn discards your hand, lets the rival draw and
play affordable cards from its selected deck, then draws your next hand.
Block clears at the start of its owner's next turn. Lethal damage ends combat.
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
docs/                 Architecture notes and prototype design
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
git commit -m "Set up backend prototype structure"
git push -u Card-Game master
```

Review staged files before committing. `.godot/` is generated locally and ignored;
Godot `.uid` and asset `.import` sidecars should remain versioned.
