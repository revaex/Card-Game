# Editing the interface

Open this copy's `project.godot`, then open a scene from `scenes/ui`:

- `main_menu.tscn`: title, artwork, navigation buttons, and footer.
- `game_ui.tscn`: backdrop, page margins, scrolling, and screen containers.
- `combat_table.tscn`: combat layout, actions, log, hand area, and rival timer.
- `combatant_panel.tscn`: reusable health, block, energy, and Poison display. The board uses two instances.

Change layout, labels, and styles in the Inspector. Shared control styles live in `data/ui/game_theme.tres`. Button connections are saved in the scenes and visible in the Signals panel.

Hands, piles, and rival intent still fill from the combat session at runtime. Setup, deck editing, journey screens, and dialogs still use their existing code-built interfaces. Gameplay rules remain separate from the scenes.

This copy is isolated on `codex/editor-scenes`. The original project and `master` remain at the checkpoint made before this conversion.
