# First backend design exercise

Target: player with 30 HP and 3 energy per turn; enemy with 40 HP;
a deck of five Strikes (cost 1, damage 6) and five Blocks (cost 1, block 5);
draw five cards per turn. Start with debug output rather than UI.

Before implementation, decide together:

1. What belongs in a shared CardDefinition Resource versus a CardInstance?
2. Who owns the hand, draw pile, discard pile, and exhaust pile?
3. Should combat actors start as RefCounted objects or Nodes, and why?
4. Which object validates energy and targets before executing card effects?
5. Which direct signals should communicate completed state changes?

War Drum needs clarification: "Whenever the player plays a Strike, gain +1
damage." The brief's example applies the bonus to that same Strike. Decide
whether it stacks, what it affects, and when it resets before implementing it.

Suggested first exercise: sketch CardDefinition and CardInstance, then implement
only their fields. Add one Strike Resource and inspect it in Godot. Build the
smallest working damage path next; introduce abstractions as gameplay needs them.
