# Game direction

The goal is a distinctive independent card roguelike intended for eventual release.
The current build is the game in development. Player-facing language should describe
the experience rather than label it a prototype. The working title and table theme
do not commit the final setting or visual identity.

The current combat foundation provides readable intent, composable effects,
artifacts, status timing, deck construction, and complete encounters. Strike,
Block, and the other starter cards are useful development content; they are not
the game's defining creative hook.

The first defining combat rule is Cadence & Rewrite. Changing between Attack,
Guard, and Tactic builds Cadence. Spend it to move a rival's prepared card to the
back of its hand. The player reads and reshapes the opposing sequence while
building their own. This connects offense, defense, drawing, and intent control.

This is the current playable direction, open to balancing and revision. Test
whether changing category creates interesting tradeoffs, whether Rewrite has
enough counterplay, and how reserve cards affect the value of moving an attack.
Counterpoint, Crosscut, and Switchback provide an initial deck for those decisions.
Build encounter progression and rewards around what playtesting demonstrates,
rather than expanding the collection before the central rule is satisfying.

Keep gameplay independent of presentation. Shared Resources define content;
individual encounters own mutable state. Improve feedback and accessibility as
the rules develop, and use real play decisions to guide new architecture.

Patterns now reward three-card sequences with defense, finishing damage, or extra
energy. Cadence, Rewrite, and Patterns are the chosen core pillars. The working
creative direction is a travelling duelist who edits an opponent's written future.
Three rival doctrines are now playable: the Duelist prioritizes attacks, the
Warden guards, and the Scribe tactics. Their identities are expressed through
content, prepared order, accent colors, and illustrated seals. The Warden opens
with Iron Seal and Block. Rewriting the Seal trades defense for incoming Strikes.
The Scribe opens with Inkblot and Venom. Rewriting Inkblot reduces Poison and
brings forward a hit that Block can absorb. Later draws still vary. The next milestone
is playtesting the three-duel journey and its card-editing sidegrades. HP now
carries through the route. Between duels the player can recover, draft one of
three cards, or revise a card's category. These changes belong to that journey.
See feature_shortlist.md for the wider candidate pool and implementation priorities.
