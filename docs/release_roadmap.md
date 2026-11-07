# Ink & Intent release roadmap

**Target:** a premium, offline, replayable card roguelike for Windows on Steam. Use a free browser demo to test the hook and reach players. Follow with a landscape Android release once the game works comfortably on a phone. Treat iOS, native Linux, and macOS as separate release decisions. Test Steam Deck via Proton before claiming compatibility.

## What we have and what people would buy

The game already supports complete duels, a three-rival journey, saved deck recipes, card revisions, and three Patterns. Rewrite is playable and animated. There are editor-authored card and board scenes, basic combat sounds, a play area, mouse and controller input, and persistent options. That is enough to test whether the central mechanic is fun. It still needs a teachable first run, meaningful choices between fights, a deeper set of opponents and builds, and packaging that has passed device testing.

The pitch: **read the rival's next move, then rewrite their plan.** The first useful playtest should reveal whether players can explain what moving a card changed and whether they later choose to do it on their own. Keep the almanac identity: dark ink, parchment, brass, and restrained flourishes. Preserve the paper, impact, and Rewrite cues as the core sound palette.

## Milestones

### Next release gate

1. **Prove the three-rival slice is worth replaying.** Test the Windows build with five new players. Record whether they use Rewrite unprompted after the lesson, finish a Journey, and choose to start another. Fix blocked progress, unclear intent, and weak reward decisions first.
2. **Verify Journey recovery in packaged builds.** Local versioned checkpoints now save before chapters, after fights, and after reward choices. Reopening the game during a duel restarts that chapter from its entry state. Checkpointed victories reconcile Marks on restart without paying twice. Test normal quit, forced exit at each boundary, and an upgrade using a prior checkpoint. Exact mid-duel resume and reproducible encounter openings remain separate work.
3. **Make one release candidate reproducible.** Record its engine version, revision, and artifact hashes. Test on clean Windows with mouse and controller, then on Steam Deck via Proton. Validate the same slice through a hosted browser build before scheduling a public demo.

Keep the campaign scope at three rivals until those checks identify what is worth expanding. Prioritize a distinctive final encounter and better between-fight choices before adding more regions or cards.

| Milestone | Work | Exit gate |
|---|---|---|
| 0. Platform foundation | Add touch selection and repeatable Windows/Web exports. Get a browser build running on a test host. Inventory platform assumptions around display, focus, font fallback, audio, and saves. | A complete duel works in a Windows export and a hosted browser export. Mouse and touch can play and cancel a card without ambiguity. |
| 1. Public-demo slice | Give the existing journey a guided first encounter, two follow-up fights with different Rewrite problems, meaningful reward choices, and a decisive ending. Show the planned/reserve distinction in play and teach one Pattern through an actual hand. Add an options/help entry and a clear retry path. | Run at least five first-time sessions. As a working gate, at least four should use Rewrite without prompting after the lesson. Record where they hesitate, whether they understand Patterns, and how long the slice takes. Fix the largest problems before adding volume. |
| 2. Replayable campaign | Prototype seeded encounter variation and route choices. Give rivals distinct intent pressures, including at least one boss with telegraphed phases. Offer card draft, removal, upgrade or revision, and recovery choices. Add resume, run history, and a clear loss/win recap. | Players can finish multiple runs with visibly different plans. Rewards produce real tradeoffs, the opening is repeatable without feeling identical, and a saved run resumes through a restart. |
| 3. Production content and presentation | Expand with a small number of build identities around sequencing, defense/counterplay, and delayed pressure. Start by prototyping two starter decks, a distinct final boss, and roughly 24–36 well-tested cards. Treat those as a scope ceiling to revisit after the slice. Add optional challenge modifiers only after the basic run works. Finish the board, menus, rival art, and accessibility pass. | Each rival changes how you play; cards have a clear role and readable text. No placeholders on the advertised route. The supported input methods can finish a run. |
| 4. Steam release candidate | Freeze content, test installs and updates on clean machines, finalize store assets, use a private beta, and fix blockers. Ship a standalone demo if it is useful for discovery. | No known crashes, save loss, stuck turns, or inaccessible required actions. Verified clean install and upgrade, supported resolutions, controller-only menus, and offline launch. Store page and build pass review. |
| 5. Android release and support | Adapt the board to phone landscape, validate Android lifecycle, build and sign the bundle, test through Play Console, and stagger the rollout after Steam support has settled. | A real phone can finish and resume a run without hover, illegible text, or controls under cutouts and navigation bars. The signed build passes Play checks. |

Plan in small increments. Implement one new rival or reward loop at a time with Resources for content and separate session state for rules. Have the project owner implement at least one card set, one rival, and one reward decision while we pair on the interfaces and review. Avoid a campaign generator, Steam integration, or a large unlock tree until playtesting identifies what they add. Make the first public demo a complete short story with replay value rather than a list of unfinished systems.

## How to polish the game

### Latest implemented slice — 7 November 2026

- Counterwritten effects are configured per effect Resource with `after_rewrite`.
  Errata, Paper Trail, and Second Reading each have a base effect and an extra
  effect after the player's Rewrite. The condition resets with the next player
  turn and never activates on the rival from a player's Rewrite.
- The Scribe queues Final Revision when reduced to 16 HP. Its next prepared line
  prioritizes attacks and seals the first card. The current line stays unchanged;
  healing cannot cancel the queued phase. Threshold and phase configuration live
  on the rival Resource; phase and seal state live in the combat session.
- Rival hover/focus previews show the affordable before/after line, attack HP loss
  after current Block, and added Poison. Unknown draw follow-ups are labelled.
  Touch gets inspect/confirm; right-click and the Inspect binding read either hand.
- Activated cards receive a brief highlight and persistent Counterwritten caption.
  Compact layout keeps the new hand readable at 1100×700. Reduced motion retains
  all state labels. Results count displaced intents and Counterwritten plays;
  displacement means planned-to-reserve at Rewrite time, not damage prevented.
- Regression coverage: `tests/rewrite_expansion.gd`. Render QA:
  `tests/render_rewrite_expansion.gd` (run with a display, writes to `.godot/`).
  Existing release gates still require human playtests and packaged device testing.

- **Combat hierarchy:** Keep intent, Cadence, the next Pattern step, and the hand readable at a glance. On smaller screens give the log its own collapsible view and pin energy, intent, and the play target. Add plain-language descriptions alongside category colors. Provide a larger UI/text option before committing to phone support.
- **Animation language:** Use short hand and card transitions, clear cues on hit, block, and status changes, and give Rewrite and a completed Pattern the strongest accents. Design those cues to stay legible when several effects resolve at once. Keep a reduced-motion path with equivalent text and state updates. Animation must never determine when the combat action resolves.
- **Sound:** Keep existing cues. Normalize their relative levels, avoid overlapping sharp cues, and tune on headphones, small speakers, and a phone. Add a subtle music or ambience layer only if it strengthens the setting. Track the provenance and license for any new audio, font, art, or tool-generated asset.
- **Input and accessibility:** Test pointer, keyboard, controller, and touch as different flows. Add an explicit inspect/confirm path for information normally shown on hover. Check text contrast, color-independent states, focus order, safe areas, browser canvas focus, and pause/resume. Keep typography bundled so browser and mobile builds match desktop. The current build uses DejaVu Sans and Serif with their license in the project. [DejaVu upstream and license](https://github.com/dejavu-fonts/dejavu-fonts)
- **Saves:** Version the save format. Keep settings, deck recipes, and run state separate. Save at deterministic boundaries, make writes recoverable, and test upgrades with old saves. First ship reliable local saves. Evaluate Steam Cloud after local save recovery works. Browser saves belong to the browser origin and can be unavailable or cleared, so test that case and explain it in the demo. [Godot Web export and persistence](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

## Shipping paths

### Windows and Steam

1. Produce a standalone Windows x64 release from the matching Godot editor and templates. Test it without the editor installed. Track engine version, Git revision, build number, and artifact hash for every candidate. Keep the executable and PCK together unless the build deliberately embeds the PCK.
2. Settle the public title and asset rights before commissioning capsule art. Set up Steamworks identity, tax, and payout details, then pay the per-product **US$100 Steam Direct fee**. Budget for the **30-day** first-release waiting period and a public **Coming Soon page for at least two weeks**, plus review time. [Steam Direct onboarding](https://partner.steamgames.com/steamdirect) · [Steam release checklist](https://partner.steamgames.com/doc/store/releasing)
3. Make the store page sell the mechanic. Lead the trailer with an actual Rewrite that changes an outcome. Capture real board screenshots, prepare the current capsule formats, write clear tags and a feature description, and show the demo in player communities where it is relevant. Compare current comparable games and playtest feedback before choosing a premium price and regional pricing. Do not assume any wishlist count guarantees sales.
4. Upload the exported game via SteamPipe, configure the Windows depot and launch executable, and test on a private branch through Steam. Run a demo or Playtest when the onboarding can stand alone. If using Next Fest, work backward from the event and demo review deadlines. [SteamPipe](https://partner.steamgames.com/doc/sdk/uploading) · [Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)
5. Submit page and build for review. At release, keep the last known good build available, smoke test live install, then triage crash, save, and progression reports first. Achievements, Steam Cloud, and Deck verification can follow the core launch checklist if the schedule is tight.

### Browser demo

Use the same GDScript and Compatibility renderer, with a single-threaded Web preset to simplify hosting. Export to `index.html`, serve the generated files together over HTTPS with proper WebAssembly MIME handling, and version releases so old cached files cannot mix with a new build. Add a visible start action for audio and a clear Steam wishlist link once the store page exists. Host a test build before promising a mobile browser release. Smoke test current Chrome/Edge and Firefox, plus Safari if advertised, and test at least one actual phone. Check load time, sound after first input, tab background/resume, and settings persistence with storage blocked. Keep the demo route short. [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) · [Godot Web preset options](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html)

### Android and Google Play

Start with a debuggable APK installed on devices. Test landscape layout, cutouts, backgrounding, OS back, audio interruptions, and process death. When ready for Play, choose the permanent application ID, set version codes, and export a signed release **Android App Bundle** using the appropriate Godot, Android SDK, Java, and Gradle setup. Keep upload keys and credentials outside the repo, backed up separately. Verify Play App Signing and run the app on an ARM64 device and a 16 KB page-size environment. At the time of this plan, ordinary new phone submissions must target **Android 16 / API 36 or higher**. Recheck the policy before submission. [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) · [Play target API policy](https://support.google.com/googleplay/android-developer/answer/11926878) · [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes)

Set up the Play Console account and verification, including the **US$25 one-time fee**, then prepare the listing, content rating, Data safety answers, and privacy policy based on the shipped build. Test internally, then use closed testing. Personal accounts created after 13 November 2023 normally need **12 testers continuously opted in for 14 days** before applying for production access. Plan for review, test paid-app pricing and availability with the account, and monitor the production release before expanding rollout. [Play Console onboarding](https://support.google.com/googleplay/android-developer/answer/6112435) · [Closed testing rules](https://support.google.com/googleplay/android-developer/answer/14151465) · [App content review](https://support.google.com/googleplay/android-developer/answer/9859455)

## Working release checklist

- Run backend and UI smoke checks on every candidate. Add targeted coverage for seeded reproducibility, save migration, platform input, and all completion paths as each lands.
- Keep a manual matrix for Windows with mouse/keyboard and controller, a small desktop window, Steam Deck/Proton, browser with mouse and touch, and low- and mid-range Android phones. Record version, input mode, resolution, and pass/fail. Include fresh install, old save, power loss/background, defeat/victory/retry, muted audio, and reduced motion.
- Maintain a short bug list sorted by save loss/crash, blocked progress, readability/input, and polish. Before release write minimum specs based on measurements, list tested devices, record asset licenses and credits, and prepare rollback instructions and a support contact.
- Use feature-sized commits and verified builds. Build artifacts stay outside Git. Store submissions and production rollouts are separate from building or testing locally.

## Start here

The first implementation adds tap-to-select and tap-the-table confirmation, keeps desktop click/drag/controller play, hides desktop-only display controls from browser/mobile builds, and checks in Windows and Web export presets. The presets package the current game for internal testing. A curated public demo still needs its own route and ending.

Install export templates matching the project's editor version in **Editor → Manage Export Templates**. From the repo root, create the output folders and run the following using the Godot console executable or a `godot` command on PATH. [Godot export workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)

```powershell
New-Item -ItemType Directory -Force builds/windows, builds/web
New-Item -ItemType File -Force builds/.gdignore
godot --headless --path . --export-release "Windows" builds/windows/InkAndIntent.exe
godot --headless --path . --export-release "Web Demo" builds/web/index.html
```

Run `builds/windows/InkAndIntent.exe` with its PCK beside it. For a local browser check, serve the whole Web folder with `python -m http.server 8080 --bind 127.0.0.1 --directory builds/web` and open `http://127.0.0.1:8080`. Opening the HTML directly from disk is not the same as serving it.

The guided opening duel is available from **Learn to duel**. It uses the normal combat session to teach reading intent, changing categories to build Cadence, using Rewrite to push Strike out of the affordable line, and finishing Shelter. The next gate is to watch first-time players try it, then use that feedback to design the second and third fights of the public-demo route.
