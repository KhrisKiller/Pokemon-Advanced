# CLAUDE.md — working on MONSERA

MONSERA is an **original** 2D top-down RPG made in **Godot 4.7.2 / GDScript**. It combines farming
and life simulation, creature bonding (kith), grid-based tactical warfare and exploration.
Start with `GDD.md`. The architecture is in `TECHNICAL_DESIGN.md` and real status is in `SYSTEMS.md` / `ROADMAP.md`.

## Absolute rules

1. **Original IP.** Never use Pokémon (or any franchise's) code, names, sprites, maps, music, characters,
   terminology or assets. No pokeemerald, Porymap, Poryscript or devkitARM. `docs/history/Design.pdf` is
   a superseded ROM-hack plan, kept only as a record of the design ideas.
2. **Build small, build in order.** Follow `ROADMAP.md`. Don't start a phase until the previous one's exit
   criterion is met. Don't mass-produce content (kith, maps, items) before its system is validated.
3. **Data-driven.** Content (kith, techniques, items, crops, NPCs, quests, factions, configs) is `.tres`
   data in `data/`. Adding content must not require gameplay code changes.
4. **Docs are truth, not fiction.** Mark a feature done only after it has been tested. Update
   `SYSTEMS.md` status, `ROADMAP.md` checkboxes and `TECHNICAL_DESIGN.md` in the same change as the code.
5. **Workflow per feature:** design → architecture (in `TECHNICAL_DESIGN.md`) → implement → test → document
   → commit (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`).
6. **Ambiguity:** make the smallest reasonable assumption, record it (decision log in
   `TECHNICAL_DESIGN.md` §14 or the relevant doc), continue. Flag decisions that change the game's identity.

## Commands

```bash
tools/install_godot.sh                            # installs pinned Godot 4.7.2 to ~/.local/bin/godot (idempotent)
godot --headless --path . --import                # (re)import assets, build class cache — run after adding files
godot --headless --path . res://tests/test_runner.tscn   # run all tests (exit code 0 = pass)
godot --headless --path . res://tests/test_runner.tscn -- --filter=clock   # run test files whose path contains "clock"
tests/persistence/run_restart_test.sh             # save in one process, load in another (persistence across restarts)
godot --headless --path . res://tests/test_runner.tscn -- --dir=res://spikes/tactical/tests   # spike tests only
godot --path . res://spikes/tactical/tactical_spike.tscn                   # play the isolated tactical spike
godot --path .                                    # run the game (needs a display)
godot --headless --path . --script res://tools/generate_placeholder_art.gd  # regenerate placeholder PNGs (then --import)
godot --headless --path . res://tools/build_maps.tscn                       # rebuild tileset + all blockout maps from tools/maps/*.txt
xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/capture_screenshots.tscn -- --out=/tmp/shots
                                                  # play a scripted session and save screenshots (visual check)
```

Tools that load game scripts run **as scenes**, not with `--script`: in `--script` mode autoloads
(`EventBus`, `Clock`) don't exist, so scripts that reference them fail to compile.
The test runner fails a test on any engine/script error logged while it runs (via a `Logger`), not
only on failed assertions, so a green run means no runtime errors either.

After creating new `.gd` files with a `class_name`, run the import command before running tests, so
the global class cache is up to date. Commit the generated `*.uid` and `*.import` files; never
commit `.godot/`.

## Code map

| Path | What |
| --- | --- |
| `game/core/event_bus.gd` | Global signals (autoload `EventBus`) |
| `game/core/time/` | `TimeConfig`, `GameTime` (pure model), `Clock` (autoload) |
| `game/core/interaction/` | `Interactable`, `InteractionProbe` |
| `game/main/` | Entry scene; spawns map + player; owns the day-transition flow |
| `game/characters/player/` | `Player` controller + camera |
| `game/characters/npc/` | `NpcData` resource, `Npc` interactable (placeholder NPCs) |
| `data/npcs/` | One `NpcData` per NPC |
| `game/world/` | `WorldMap`, `MapInfo`/`MapCatalog`, `MapTransition`, `DayNightTint`, maps, props, tileset |
| `game/core/save/` | `SaveService` (autoload), `SaveFormat`, `SaveMigrations` |
| `game/core/content_db.gd` | `ContentDB` autoload: read-only items/crops by id; `validate()` |
| `game/main/game_session.gd` | `GameSession` (owned by Main): `PlayerState`, `FarmState`, `KithRoster`, injected into `session_aware` nodes |
| `game/items/` | `ItemData`, `ItemCatalog`, `Inventory` (the one inventory model) |
| `game/characters/player/player_state.gd` | `PlayerState`: bag, money, selected seed (save section `player_state`) |
| `game/farming/` | `CropData`/`CropCatalog`, `CropState`, `PlotState`, `FarmState` (save section `farm`), `FarmActions`, `FarmPlot` node |
| `game/economy/` | `Pricing`, `Shipping`, `ShippingCrate` node, `ShopData`/`Shop` (seed shop) |
| `game/kith/` | `KithData`, `KithState`, `KithRoster` (save section `kith`), `KithConfig`, `KithCare`, `KithBonding`, `KithHelpers`, `world/WildKith` |
| `game/ui/menus/` | `ListMenu` (generic modal list), `ShopMenu`, `KithMenu` |
| `data/items/`, `data/crops/` | Item and crop definitions + catalogs |
| `data/kith/`, `data/shops/` | Kith species and shops + catalogs |
| `game/core/world_state.gd` | `WorldState` autoload: flags, discovered locations |
| `data/maps/` | `MapInfo` per map + `map_catalog.tres` |
| `tools/maps/` | ASCII blockout layouts (source of truth for blockout maps) |
| `game/ui/hud/` | HUD, clock display, message box, prompt, fade |
| `data/config/` | Tunables (`time_config.tres`) |
| `tests/` | Runner scene, `TestCase`, `unit/`, `integration/` |
| `tools/` | Godot installer, placeholder art and test map generators |

## Conventions

- Static typing everywhere. `class_name` for reusable types. Signals in past tense or `*_requested`.
- Rules in `RefCounted`/`Resource` classes (testable without a scene tree); nodes only adapt.
- No new autoloads without a line in `TECHNICAL_DESIGN.md` §4 explaining why.
- Physics layers: 1 world, 2 player, 3 interactables, 4 npcs, 5 water, 6 kith, 7 triggers.
- Anything saved must follow the Saveable contract (`TECHNICAL_DESIGN.md` §9): ids and values only.
- Tests: add `tests/unit/test_<thing>.gd` or `tests/integration/test_<thing>.gd` extending `TestCase`;
  every `test_*` method runs automatically. Pure logic gets unit tests; scenes get integration tests.

## Saves and spikes

- Changing what a provider saves: bump that section's `"version"` and keep reading the old one.
  Changing the file envelope: add a `SaveMigrations` step, bump `SaveFormat.CURRENT_VERSION`, and
  commit a fixture written by the **old** code to `tests/fixtures/saves/`. Never edit old steps or fixtures.
- `spikes/` holds isolated prototypes. No `class_name`, no autoloads, and never reference them from
  `game/`. A spike is rewritten for production, never promoted.

## Farming rules of thumb

- Farming never has its own clock: growth happens only in `FarmState.advance_day()`, called by the
  day transition in `Main`.
- New crop = `CropData` + seed item (tag `seed`) + produce item (tag `crop`) + catalog entries; the
  `ContentDB.validate()` test must stay green. Don't add farming code for a new crop.
- Nodes (`FarmPlot`, `ShippingCrate`) only present and forward; rules stay in `FarmState`,
  `FarmActions`, `Shipping` and `PlayerState`, which are testable without a scene tree.

## Kith rules of thumb

- `KithData` = species (never mutated); `KithState` = one owned individual (ids and values only).
  The party (`KithRoster`) lives in `GameSession`, never in a map or the Player node.
- No second inventory: feeding and bonding take items from `PlayerState.inventory`.
- Helpers never simulate input or walk: they run in the day transition through
  `FarmState.apply_helper_action(action, limit)`. New ability = an id in `ContentDB.KNOWN_ABILITIES`,
  a branch in `apply_helper_action`/`KithHelpers`, config values, species data.
- New species = `KithData` `.tres` + sprite + catalog entry; `ContentDB.validate_kith` must stay green.
- All kith numbers live in `data/config/kith_config.tres`.

## Current phase

Phase 4 (kith foundation + seed shop + first farm helper) is done: 4 prototype kith (data only, no
stats), species vs individual state, a party of 6 with an active kith, feeding and Trust from the one
inventory, prototype bonding (food → calm → Bond Charm), Rillet's watering in the daily tick, Pell's
seed shop, party and shop menus, saves (restart- and migration-tested). Tactical spike v0.2 is
isolated and awaiting the owner's playtest.
**Next: Phase 5 (creature battle MVP), only after the owner approves.** Do not start creature
battles, full tactical warfare, war systems, mass content or final art without explicit approval.

Provisional (keep, don't expand the lore): kith, bonding, Bond Charm, Sera, Lowmere Vale, Aurelian
Crown, Thornwood Compact, the Greying, the 6:00–2:00 day, ~14 real minutes per day, balance formulas,
aspect chart, crop names/values/growth times, immediate (not overnight) shipping, the 4 Phase 4 kith
and their diets, Trust 0–100 and its labels/gains, bonding without battles, seed prices, the
watering helper's Trust 25 / 3 plots per day.
