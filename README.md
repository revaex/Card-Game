# Card-Game

A card roguelike about reading your opponent's next move and rewriting their plan.
Still finding its final name and setting.

Open `project.godot` in Godot 4 and press **F5**.

To resume development, start with the [development queue](docs/development_queue.md),
then see the [feature shortlist](docs/feature_shortlist.md),
[release roadmap](docs/release_roadmap.md), and [project brief](docs/project_brief.md).

## Playing

- Change between Attack, Guard, and Tactic cards to build Cadence.
- Spend 2 Cadence to move a rival's prepared card to the back of their hand.
- Complete three-card Patterns for block, finishing damage, or extra energy.
- Hover cards for damage previews. **Pattern guide** shows the recipes.
- Hover or focus a rival card to preview how Rewrite changes planned cards,
  attack HP loss, and Poison. Draw follow-ups are explicitly unknown.
- The rival skips unaffordable cards and can still play free cards at zero
  energy. After its turn, it discards unplayed reserves and sorts its new hand
  by doctrine. The board shows the next-hand order and the current line's
  projected energy spend.
- Right-click or use **Inspect** on a focused card in either line. On touch,
  tapping a rival card opens inspection with an explicit Rewrite confirmation.
- On the default controller layout, **Y** ends the turn and the right stick
  scrolls the combat log. **View / Select** opens the Pattern reward overview.

**Begin a journey** takes you through the Duelist, Warden, and Scribe. HP carries
between fights. After a win, recover 8 HP, draft a card, remove one, or change
one card's category. These edits don't change your saved decks. Journeys save
between fights; reopening during a duel restarts that chapter.

The Scribe queues **Final Revision** at 16 HP: its next prepared line leads with
attacks and seals the first card against Rewrite. The remaining line is editable.
Healing cannot cancel a queued phase change.

**Counterwritten** cards gain extra effects after you Rewrite that turn. Try
Errata (damage), Paper Trail (Block), and Second Reading (draw). They're available
in the deck builder and the draft before the Scribe. Add the ten-card
**Counterwritten** preset from **Your decks → Add a preset…**.

You can also challenge a single rival or play a custom deck-versus-deck duel.
Choose **Practice fixed-opening puzzle** on any rival card for a supplied
deck, a timed result, and a rematch. Attempts and best times are tracked
per rival during the current app session.
The optional **Practice rules** above the rival cards let you test strict
queues, carry unplayed reserves forward, or trade 3 Cadence for 1 energy.
Scout opening previews the selected rules and the standard opening separately.
In **Your decks**, click a card, use Confirm, or drag it into the deck tray.
Use **−** in the tray to remove a copy. Journeys start with 10–14 cards and at most two
copies of each card, with Strike and Block exempt from the copy limit.
Counterpoint includes all three categories and is a good place to start.
The deck library can filter by name or Journey readiness. Try the Poison
Pressure, Riposte Guard, or Surge Cycle presets to explore different styles.
The workshop playtest also includes Twin Riposte for multi-hit finishers,
Rewrite Engine for Counterwritten cards, and Recovery Line for sustain.

Enable **Playtest Margin Burn** in standalone duel setup to try exhausting one
card for up to 2 Cadence once per duel. Playtest wins award no progression.

Built with Godot and GDScript.
