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
godot --path .                                    # run the game (needs a display)
godot --headless --path . --script res://tools/generate_placeholder_art.gd  # regenerate placeholder PNGs
godot --headless --path . --script res://tools/build_test_map.gd            # regenerate the test map scene
```

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
| `game/world/` | `WorldMap` base, `DayNightTint`, maps, props, tileset |
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

## Current phase

Phase 0 (docs) is done. **Now: Phase 1** — Godot project, player movement, camera, test map, interaction, day/time.
