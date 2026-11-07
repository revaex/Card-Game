# Card-Game

A card roguelike about reading your opponent's next move and rewriting their plan.
Still finding its final name and setting.

Open `project.godot` in Godot 4 and press **F5**.

## Playing

- Change between Attack, Guard, and Tactic cards to build Cadence.
- Spend 2 Cadence to move a rival's prepared card to the back of their hand.
- Complete three-card Patterns for block, finishing damage, or extra energy.
- Hover cards for damage previews. **Pattern guide** shows the recipes.
- Hover or focus a rival card to preview how Rewrite changes planned cards,
  attack HP loss, and Poison. Draw follow-ups are explicitly unknown.
- Right-click or use **Inspect** on a focused card in either line. On touch,
  tapping a rival card opens inspection with an explicit Rewrite confirmation.

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
**Your decks** is where you build and save decks. Counterpoint includes all three
categories and is a good place to start.

Built with Godot and GDScript.
