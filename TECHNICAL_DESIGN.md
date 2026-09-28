# MONSERA — Technical Design

> Architecture reference. Sections marked **[implemented]** describe code that exists and is tested.
> Sections marked **[planned]** are binding design for future phases; update them when implemented.

## 1. Engine and platform

| Decision | Choice | Why |
| --- | --- | --- |
| Engine | **Godot 4.7.2** (stable) | Pinned version for reproducible builds; `tools/install_godot.sh` installs it |
| Language | **GDScript**, statically typed | Directive; static types catch errors at parse time and are faster |
| Renderer | **GL Compatibility** | 2D-only game; widest PC hardware support and the easiest path to Android later |
| Internal resolution | **640×360**, window 1280×720, stretch `viewport`, scale mode `integer` | Pixel-perfect scaling to 720p/1080p/1440p/4K; 16 px tiles show 40×22.5 tiles |
| Tile size | **16×16 px** | Standard for top-down pixel art; characters 16×24, kith 16–48 px |
| Texture filter | Nearest | Pixel art |
| Platforms | Windows, Linux first; Android later (no mobile optimisation yet) | Directive |

## 2. Repository layout [implemented]

```
project.godot            Godot project (root = res://)
CLAUDE.md, *.md          Design and technical docs (root, as required)
docs/history/            Superseded material (Design.pdf)
game/                    ALL code and scenes, grouped by feature (script + scene side by side)
  core/                  Engine-agnostic services: event bus, time, interaction
  main/                  Entry scene; composes world + HUD; orchestrates day transitions
  characters/player/     Player controller
  world/                 Maps, map base class, props, tilesets, day/night tint
  ui/hud/                HUD, clock display, message box, prompt, screen fade
  (creatures/ combat/ tactical/ farming/ inventory/ economy/ dialogue/ quests/
   progression/ save/ audio/ are created by the phase that implements them)
data/                    Content as Godot Resources (.tres). No code.
  config/                Tunable configs (time_config.tres)
assets/                  Art and audio source files, grouped by kind
  placeholder/           Generated placeholder art (see tools/). Replaced during Phase 10.
tests/                   Headless test runner + unit/integration tests
tools/                   Dev tools: Godot installer, placeholder art and test map generators
.github/workflows/       CI (headless tests)
```

**Deviations from the suggested structure (and why)**

1. The Godot project lives at the **repository root**, not in a `project/` subfolder. That keeps one
   `res://` root, simpler CI and editor paths.
2. **Scenes live next to their scripts** inside `game/<feature>/` rather than in a separate `scenes/`
   tree. Feature folders are self-contained and easy to delete or move.
3. Empty feature folders are **not** pre-created (git doesn't track them and they hide real status).
   The suggested folders are created by the phase that implements them.
4. Added `tests/`, `tools/`, `data/config/`, `assets/placeholder/`.

## 3. Architectural principles

1. **State is separate from presentation.** Rules live in plain `RefCounted`/`Resource` classes
   (for example `GameTime`) that can be tested without a scene tree. Nodes only adapt state to the
   engine (input, rendering, signals). This is also the basis for future multiplayer (§12).
2. **Content is data.** Gameplay code reads `Resource` definitions from `data/`. It never hardcodes
   content ids, except in tests and story scripts.
3. **Few globals.** Autoloads only for true singletons: `EventBus` (decoupled signals) and `Clock`
   (the one game clock). Planned: `ContentDB`, `SaveService`, `WorldState`. Everything else is a scene.
4. **Signals up, calls down.** Children never reach into parents. Cross-feature communication goes
   through `EventBus` signals, named in past tense for facts (`dialogue_closed`) or `_requested` for
   intents (`sleep_requested`).
5. **One orchestrator per flow.** `Main` owns the sleep/day-transition flow. Systems expose steps,
   not flows.
6. **Deterministic core.** Simulation code must not read wall-clock time or the global RNG. Randomness
   goes through a seeded `RandomNumberGenerator` owned by state (planned for battle and world tick).

## 4. Autoloads [implemented]

| Name | File | Responsibility |
| --- | --- | --- |
| `EventBus` | `game/core/event_bus.gd` | Declares global signals only. No state, no logic. |
| `SaveService` | `game/core/save/save_service.gd` | Save slots on disk; provider registry; format upgrades. It has no game knowledge. Listed before `Clock` so it exists first. |
| `Clock` | `game/core/time/clock.gd` | Owns the `GameTime`; advances it in real time; emits time signals; pause requests. |
| `WorldState` | `game/core/world_state.gd` | Persistent world facts: typed flags and discovered locations. It is a global because story, NPCs, maps and (later) quests all read it. |

Autoloads do **not** register themselves as save providers. `Main`, the composition root of a play
session, registers `Clock`, `WorldState` and itself, so a stray instance (for example in a test)
can never become a duplicate section.

## 5. Physics layers [implemented]

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | `world` | Solid tiles (walls, fences, trees, rocks) and solid props |
| 2 | `player` | Player body |
| 3 | `interactables` | `Interactable` areas (detected by the player's `InteractionProbe`) |
| 4 | `npcs` | [planned] NPC bodies |
| 5 | `water` | Water tiles. **Separate from `world`** so swimming mounts can drop it from their mask. |
| 6 | `kith` | [planned] Overworld kith |
| 7 | `triggers` | [planned] Map transitions, cutscene triggers, encounter zones |

The player body's mask is `world + water`. Mounts change the mask (§10).

## 6. Implemented systems (Phase 1)

### 6.1 Time [implemented]

- `TimeConfig` (`Resource`, `data/config/time_config.tres`): real seconds per game minute (0.7),
  day start (6:00), day end (26:00 = 2:00 next morning), days per season (28), season and weekday
  names, HUD step (10 minutes).
- `GameTime` (`RefCounted`, pure): `day_index` (absolute day, 0-based) + `minute_of_day`
  (360…1560). It has the derived calendar (year, season, day of season, weekday, hour), formatting,
  `advance(minutes)` clamped at day end, `start_next_day()`, and `to_dict()`/`from_dict()` for saves.
- `Clock` (autoload): accumulates real time → whole game minutes. It emits `minute_changed`,
  `time_step_changed` (every 10 min, used by the HUD), `hour_changed`, `curfew_reached` (once, at 2:00),
  `day_started`. It has **pause requests keyed by reason** (`request_pause(&"dialogue")` /
  `release_pause(...)`), so several systems can pause time without fighting each other.
  `end_day()` moves to the next morning. It is called only by the day-transition flow.
- `DayNightTint` (`CanvasModulate`): samples a `Gradient` by hour of day. It only tints the world
  canvas; the HUD's `CanvasLayer` is unaffected.

**Day transition flow (owned by `Main`)**: `EventBus.sleep_requested` (bed) or `Clock.curfew_reached`
→ player control locked → fade out → `Clock.end_day()` (later: growth tick, world tick, auto-save) →
fade in → wake-up message. This is the single place where "end of day" hooks will be added.

### 6.2 Player movement and camera [implemented]

- `Player` (`CharacterBody2D`): 8-direction analog movement (`Input.get_vector`, so diagonals are not
  faster), with acceleration/friction, 4-way facing for sprite and interaction, and `move_and_slide`
  against tile collision. The origin is at the **feet** (y-sort friendly). Collision is a small
  foot box.
- Control lock: the player ignores movement and interact input while any **modal** is open
  (`EventBus.modal_opened/closed`, counted by id).
- `Camera2D` is a child of the player with position smoothing. `WorldMap.apply_camera_limits()` clamps it
  to the map's used rectangle, so the camera never shows outside the map.

### 6.3 Maps [implemented]

- `WorldMap` (`Node2D` base script for every map): `Ground` and `Obstacles` `TileMapLayer`s, a
  y-sorted `Entities` node (props, NPCs, player) and `Marker2D` spawn points in `SpawnPoints`.
  API: `get_spawn_position(id)`, `add_entity(node)`, `get_bounds()`, `apply_camera_limits(camera)`.
- Tiles: `game/world/tilesets/placeholder_tileset.tres` (physics layer 0 → `world`, physics layer
  1 → `water`).
- The test map `game/world/maps/test_map.tscn` (48×30 tiles: house with bed, sign, crate, pond,
  fenced tilled field, paths, tree border) is **generated** by `tools/build_test_map.tscn` from an
  ASCII layout, then committed as a normal scene. It can be opened and painted in the editor; the
  generator is only a bootstrap. Future maps are authored in the editor.

### 6.4 Interaction [implemented]

- `Interactable` (`Area2D`, layer `interactables`): `prompt` text, `enabled`, `interacted(actor)`
  signal, and a virtual `_on_interact(actor)`. Specialised props extend it:
  `SignInteractable` (shows lines) and `BedInteractable` (requests sleep).
- `InteractionProbe` (`Area2D` on the player, placed in front of the facing direction): tracks
  overlapping interactables, picks the **closest enabled** one, and emits `target_changed` (the HUD
  shows "[E] Read").
- Dialogue in Phase 1 is a plain line queue: `EventBus.dialogue_requested(lines)` → HUD `MessageBox`
  (modal, pauses the clock). The real dialogue system (data-driven trees, conditions, speakers) is
  planned for the NPC epic and will replace the payload, not the signal flow.

## 7. Creature data architecture [planned — Phase 4]

```
CreatureData (Resource, data/creatures/<id>.tres) — immutable species definition
  id: StringName, name, description, aspects: Array[StringName]
  base_stats: StatBlock (vitality, might, focus, guard, will, speed)
  traits: Array[TraitData], learnset: Array[LearnsetEntry], teachable_tags
  maturation: Array[EvolutionRule]
  habitat: HabitatInfo, rarity, bond_rate
  diet: DietProfile (favourite/tolerated/disliked food tags)
  breeding: BreedingInfo (group, egg_cycles)
  utility: Array[StringName] (water, till, haul, glide, swim, burrow, light, forage)
  mount_type: StringName (none/land/water/air/burrow)
  tactical: TacticalProfile (role, move_class, move, min/max range, terrain_affinity, can_move_and_fire)
  visual: CreatureVisual (sprite frames, palette, size class, portrait)

CreatureInstance (RefCounted, saved) — one bonded or wild individual
  uid, species_id, nickname, level, xp, potential: StatBlock, training: StatBlock,
  trust, known_techniques, status, current_hp, wounded_days, flags
  → derived stats computed by StatFormulas from species + instance (never stored)

BattleCreatureState (RefCounted) — built from a CreatureInstance when a creature battle starts
  stat stages, volatile status, technique uses; writes back HP/XP/trust at the end

TacticalUnitState (RefCounted) — built from a CreatureInstance + TacticalProfile for a tactical battle
  grid position, strength pips (derived from HP ratio), provisions, has_moved/has_acted, faction
  → writes back wounds, XP and trust at the end
```

Rules: `CreatureData` is never mutated at runtime. The two combat states never reference each other.
Both read aspects through the shared `AspectChart` resource. Adding a species = new `.tres` + art.

**Content registry** [planned]: `ContentDB` autoload scans `data/<kind>/` at start-up and indexes
resources by `id` (handling `.remap` in exported builds). Gameplay looks up content with
`ContentDB.get_creature(&"loamox")`, never by path.

## 8. Other planned system architecture

| System | Core types | Notes |
| --- | --- | --- |
| Inventory | `ItemData` (Resource: id, name, tags, base_value, stack_max, use effects), `Inventory` (RefCounted: slots of `{item_id, qty}`) | Tags drive food, crafting and selling |
| Farming | `CropData` (seasons, stages, days per stage, regrow, yields, water need), `FarmPlot` state in a `FarmState` keyed by map + cell | Growth is advanced by the day-transition flow, not in real time |
| Economy | `PriceService.get_price(item, context)` = base × modifier stack (`PriceModifier` resources: season, region, war tension, relationship) | Vendors are data (`ShopData`) |
| Creature battle | Turn-state machine (`BattleController`) over `BattleCreatureState`s; UI separate; actions as command objects | Commands keep it replayable and future multiplayer-friendly |
| Tactical | `TacticalMapData` (grid, terrain ids, objectives, deployment zones), `TerrainData` (defence, move cost per class), `TacticalBattleState`, `Pathfinder` (Dijkstra over move costs), `TacticalAI` (utility scoring) | Its own scene; returns a `TacticalResult` to the world |
| NPCs | `NpcData` (identity, gift tastes, schedule sets), `ScheduleEntry` (day/time/location), overrides with `Condition`s | Conditions read `WorldState` |
| Quests | `QuestData` (stages, conditions, rewards) | Same `Condition`/`Effect` vocabulary as world events |
| Progression | `CallingProgress` (7 callings: xp, level) | XP events emitted via `EventBus` |
| World simulation | `WorldState` (flags, counters, faction control, war tension 0–100, route status), `WorldEvent` resources (conditions → effects), evaluated in the **daily tick** | Only at day transitions: cheap, deterministic, save-friendly |

`Condition` and `Effect` are small reusable `Resource` classes (e.g. `FlagIsSet`, `TensionAtLeast`,
`SetFlag`, `ModifyPrice`) shared by quests, NPC overrides, world events and dialogue.

## 9. Save system [implemented — Phase 2]

- **Files:** JSON in `user://saves/slot_<n>.json`, not Godot `Resource` files, because loading a
  `.tres` can instantiate arbitrary scripts, which is unsafe for shared saves. Writes are **atomic**
  (`.tmp` then rename). The previous save is kept as `.bak` and loaded automatically if the main file
  is unreadable.
- **Format v2** (current, `SaveFormat`):
  `{ "format_version": 2, "meta": { saved_at, game_version, summary }, "sections": { "<id>": {...} } }`.
  `meta.summary` is gathered from providers' optional `get_save_summary()` (date, time, location), so a
  load screen can list slots without applying them (`SaveService.read_meta(slot)`).
- **Saveable contract:** `get_save_id() -> StringName`, `to_save_data() -> Dictionary`,
  `load_save_data(data: Dictionary)`. The last must accept `{}` (section missing, which means defaults)
  and older versions of its own section. Values must be JSON-safe. Only ids and values are saved,
  never node or resource paths.
- **Sections today:** `clock` (day index, minute), `world` (flags, discovered locations), `player`
  (map id, position, facing). They load in registration order: time, world, then the player (who may
  change the map).
- **Two versioning layers:**
  1. *File format*: `SaveMigrations.migrate()` runs steps v1 → v2 → …. v1 (sections at the top level)
     was the first Phase 2 format; v1 → v2 moved sections under `sections` and added `meta`.
  2. *Section*: each section carries `"version"` and its provider reads old versions. Example: player
     section v1 stored `facing` as `[x, y]` floats; v2 stores `"left"`.
- **Fixtures:** every shipped format has a real file written by that version's code in
  `tests/fixtures/saves/` (`v1_phase2_early.json`). Tests migrate each fixture and boot the game from
  it. Rule: never edit a migration step or a fixture; add new ones.
- **When saving happens:** auto-save at the end of every day transition (sleep or collapse). On start,
  `Main` continues from slot 1 if it exists. Debug builds: F5 quicksave, F9 quickload.
- **Restart test:** `tests/persistence/run_restart_test.sh` saves in one Godot process and verifies in a
  fresh one (see §11).

## 10. Mounts and movement classes [planned]

The player has a `movement_class` (foot, land_mount, water_mount, …) that sets speed and the collision
mask. For example, a water mount removes `water` from the mask and adds shore-edge detection. The
tactical system uses the same movement class vocabulary for terrain costs.

## 11. Testing [implemented]

- Runner: `godot --headless --path . res://tests/test_runner.tscn [-- --filter=<text>]` (running a
  scene means autoloads and project settings load exactly as in the game). It exits with code 0 on
  success and 1 on any failure.
- A test also fails if **any engine or script error** is logged while it runs. The runner installs a
  `Logger` (Godot 4.5+ API), so runtime errors such as a null call can't pass silently.
- `tests/framework/test_case.gd` (`TestCase`): `before_each`/`after_each`, `assert_eq`,
  `assert_true`, `assert_false`, `assert_almost_eq`, `assert_not_null`, plus helpers to add nodes and await
  physics frames. Every `test_*` method in `tests/unit/test_*.gd` and `tests/integration/test_*.gd` is run.
- Unit tests cover pure logic (time, save format and migrations, world state). Integration tests instantiate real scenes headlessly (player
  movement against collision, interaction, the sleep flow, the main scene booting).
- CI: `.github/workflows/tests.yml` installs the pinned Godot, imports, and runs the suite.
- Visual check: `tools/capture_screenshots.tscn` plays a scripted session of the real game (wake up,
  walk out, read the sign, evening, night, sleep) and saves screenshots. It needs a display
  (`xvfb-run` on servers).
- Current suite: 46 tests (23 unit, 23 integration).

## 12. Multiplayer readiness (not implemented)

Not a goal for v1. Choices that keep it possible: state is separate from nodes; simulation is
deterministic with a seeded RNG; player intents are expressed as commands/requests (`sleep_requested`,
battle actions as command objects); content is referenced by stable ids; the world ticks at
discrete points (day transitions, battle turns).

## 13. Conventions

- Files `snake_case.gd/.tscn`; `class_name` in PascalCase for reusable types; signals in past tense.
- Static typing everywhere (`var x: int`, typed arrays, `-> void`).
- `@export` for designer-tunable values; no magic numbers in logic.
- Node names in PascalCase. Access children with `%UniqueName` or `@onready var x := $Path`.
- Every new system: design note here → implement → tests → docs → commit (see `CLAUDE.md`).

## 14. Decision log

| # | Decision | Alternatives considered | Reason |
| - | --- | --- | --- |
| D1 | Godot 4.7.2 pinned | Latest 4.x floating | Reproducible CI; `.tscn` format stability |
| D2 | GL Compatibility renderer | Forward+ / Mobile | 2D only; hardware reach; Android later |
| D3 | 640×360, integer scaling | 480×270, 320×180 | More world visible for farming and tactics while staying pixel-perfect |
| D4 | Custom headless test runner | GUT, gdUnit4 | Zero dependencies, ~150 lines, runs in CI; can migrate later if needed |
| D5 | JSON saves with a provider contract | Godot `Resource` saves | Safety (no script execution), diffable, migratable |
| D6 | Test map generated from ASCII by a tool, then committed as a normal scene | Runtime ASCII maps; hand-authored tile data | Real editable `TileMapLayer` scenes without hand-writing binary tile data |
| D7 | Daily tick for farming, world simulation and economy | Continuous simulation | Simple, deterministic, cheap, save-friendly; matches the game's rhythm |
| D8 | Water is its own physics layer | Water on `world` layer | Swimming mounts can toggle it |
| D9 | Movement ≠ Speed stat in tactics | Derive move from Speed | Keeps the two combat systems independently balanceable |
| D10 | Dev tools that touch game scripts run as scenes | `--script` SceneTree tools | Autoloads don't exist in `--script` mode, so dependent scripts fail to compile |
| D11 | Time pauses during modals via reason-keyed requests | A single `paused` bool | Independent systems (dialogue, fades, menus) can't un-pause each other |
