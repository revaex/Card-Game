# Editing the interface

Open this copy's `project.godot`, then open a scene from `scenes/ui`:

- `main_menu.tscn`: title, artwork, navigation buttons, and footer.
- `game_ui.tscn`: backdrop, page margins, scrolling, and screen containers.
- `combat_table.tscn`: combat layout, actions, log, hand area, and rival timer.
- `intent_card.tscn`: compact rival cards. The `IntentBand` in `combat_table.tscn` holds the prepared line and its Rewrite effects.
- `table_toolbar.tscn`: combat toolbar with Sound, Motion, and Fast turns toggles.
- `combat_audio.tscn`: combat sound players and cue levels. The WAV assets live in `data/audio`.
- `combatant_panel.tscn`: reusable health, block, energy, and Poison display. The board uses two instances.
- `combat_result.tscn`: encounter outcome, summary, and navigation buttons. It uses two instances of `result_statistics.tscn` for the player and rival totals.
- `card.tscn`: shared card face for the combat hand, deck editor, and read-only viewers.
- `card_stage.tscn`: the board's card drop target and latest-play display.
- `options_menu.tscn`: audio, animation, and rival playback settings.
- `deck_editor.tscn` and `deck_card.tscn`: collection layout and per-card copy controls.
- `card_browser.tscn`: scrollable deck and pile viewer with grouped copies.

Change layout, labels, and styles in the Inspector. Shared control styles live in `data/ui/game_theme.tres`. Fixed button connections, such as the main menu actions, are visible in the Signals panel. Result actions are connected when the overlay opens because duels and journeys use different destinations.

For new UI, put screens, reusable components, and fixed child nodes in `.tscn` files so their layout and properties can be edited in Godot. Use scripts for behavior and to instantiate reusable scenes when the number of items depends on game state, such as the cards in a hand.

Hands, piles, and rival intent fill from the combat session at runtime. The deck editor fills its grid from the card catalog. Setup, journey screens, and some dialogs still use code-built layouts. Gameplay rules remain separate from the scenes.

Local `master` uses the editor-authored layouts. The original scripted layouts are preserved on `backup/scripted-layout`.
