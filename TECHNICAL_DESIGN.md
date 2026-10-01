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
  core/                  Engine-agnostic services: event bus, time, interaction, save, world state, ContentDB
  main/                  Entry scene; composes world + HUD; map and day transitions; player save section;
                         GameSession; NewGameConfig
  items/                 ItemData, ItemCatalog, Inventory
  farming/               CropData/CropCatalog, CropState, PlotState, FarmState, FarmActions, FarmPlot
  economy/               Pricing, Shipping, ShippingCrate, ShopData/ShopOffer/ShopCatalog, Shop
  kith/                  KithData/KithCatalog, KithConfig, KithState, KithRoster, KithCare, KithBonding,
                         KithHelpers; world/WildKith
  characters/player/     Player controller
  characters/npc/        NpcData + Npc (placeholder NPCs)
  world/                 WorldMap, MapInfo/MapCatalog, MapTransition, maps, props, tilesets, day/night tint
  ui/hud/                HUD, clock display, message box, prompt, location banner, screen fade, kith label
  ui/menus/              ListMenu (generic modal list), ShopMenu, KithMenu
  (combat/ tactical/ dialogue/ quests/ progression/ audio/ are created by the phase that
   implements them)
data/                    Content as Godot Resources (.tres). No code.
  config/                Tunable configs (time_config, day_night_gradient, new_game, kith_config)
  maps/                  MapInfo per map + map_catalog.tres
  npcs/                  NpcData per NPC
  items/, crops/         ItemData / CropData + catalogs
  kith/, shops/          KithData / ShopData + catalogs
assets/                  Art and audio source files, grouped by kind
  placeholder/           Generated placeholder art (see tools/). Replaced during Phase 10.
tests/                   Headless test runner, unit/ and integration/ tests, fixtures/saves/,
                         persistence/ (two-process restart test)
tools/                   Dev tools: Godot installer, placeholder art, map builder (+ maps/*.txt layouts),
                         screenshot tour
spikes/                  ISOLATED prototypes, never referenced by game/ (tactical/ in Phase 2)
.github/workflows/       CI (tests, restart test, spike tests)
```

**Deviations from the suggested structure (and why)**

1. The Godot project lives at the **repository root**, not in a `project/` subfolder. That keeps one
   `res://` root, simpler CI and editor paths.
2. **Scenes live next to their scripts** inside `game/<feature>/` rather than in a separate `scenes/`
   tree. Feature folders are self-contained and easy to delete or move.
3. Empty feature folders are **not** pre-created (git doesn't track them and they hide real status).
   The suggested folders are created by the phase that implements them.
4. Added `tests/`, `tools/`, `data/config/`, `assets/placeholder/`.
5. Added `spikes/` for throwaway prototypes that answer one design question. Rules: no `class_name`,
   no autoloads, nothing in `game/` may reference them. A spike is rewritten, never promoted.

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
| `ContentDB` | `game/core/content_db.gd` | **Read-only** content registry: items, crops, kith species and shops by id, from catalog resources (export-safe, no folder scanning). Global because every system reads content, and content never changes at runtime. `validate()` checks cross-references. |
| `SaveService` | `game/core/save/save_service.gd` | Save slots on disk; provider registry; format upgrades. It has no game knowledge. Listed before `Clock` so it exists first. |
| `Clock` | `game/core/time/clock.gd` | Owns the `GameTime`; advances it in real time; emits time signals; pause requests. |
| `WorldState` | `game/core/world_state.gd` | Persistent world facts: typed flags and discovered locations. It is a global because story, NPCs, maps and (later) quests all read it. |

Autoloads do **not** register themselves as save providers. `Main`, the composition root of a play
session, registers `Clock`, `WorldState`, the session's providers (`PlayerState`, `FarmState`,
`KithRoster`) and itself, so a stray instance (for example in a test) can never become a duplicate section.

**Mutable session state is not global.** `GameSession` (owned by `Main`) holds the player's
belongings, the farm and the kith party (with its `KithConfig`). Map nodes in the `session_aware` group receive `bind_session(session)` when
their map loads (dependency injection, no service locator).

## 5. Physics layers [implemented]

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | `world` | Solid tiles (walls, fences, trees, rocks) and solid props |
| 2 | `player` | Player body |
| 3 | `interactables` | `Interactable` areas (detected by the player's `InteractionProbe`) |
| 4 | `npcs` | NPC bodies (blocks the player) |
| 5 | `water` | Water tiles. **Separate from `world`** so swimming mounts can drop it from their mask. |
| 6 | `kith` | Wild kith bodies (Phase 4; block the player). Followers later. |
| 7 | `triggers` | [planned] Map transitions, cutscene triggers, encounter zones |

The player body's mask is `world + npcs + water + kith`. Mounts change the mask (§10).

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

### 6.3 Maps and map transitions [implemented — Phase 2]

- `WorldMap` (`Node2D` base script for every map): `Ground` and `Obstacles` `TileMapLayer`s, a
  y-sorted `Entities` node (props, NPCs, player), `Marker2D` spawn points in `SpawnPoints`, and
  `MapTransition` areas in `Transitions`. API: `get_spawn_position(id)`, `add_entity(node)`,
  `get_bounds()`, `apply_camera_limits(camera)`. Every map scene declares its `map_id`.
- **Map data:** `MapInfo` resources (`data/maps/<id>.tres`: id, display name, scene *path*, region)
  listed in `MapCatalog` (`data/maps/map_catalog.tres`). Code refers to maps only by id. Adding a map
  means a scene plus a `MapInfo` plus a catalog entry, with no code change.
- **Exits:** `MapTransition` (`Area2D`, layer 7 `triggers`, mask `player`) holds only
  `target_map_id` and `target_spawn_id`. On `body_entered` by the Player it emits
  `EventBus.map_transition_requested(map_id, spawn_id, source)`.
- **Transition flow (owned by `Main`):** ignore the request unless `source` belongs to the current map
  → defer out of the physics callback → modal lock and clock pause → fade out →
  `change_map(id, spawn)` → fade in → release → HUD location banner. `change_map` detaches the old map
  immediately, since only queue-freeing it let its triggers fire again (a bug caught by a test). It
  keeps the **same Player node**, positions it before it enters the new map's physics, updates camera
  limits, marks the location discovered in `WorldState` and emits `EventBus.map_changed`.
- **Home:** after a collapse (curfew) the player wakes at `home_map_id`/`home_spawn_id` (the farm bed)
  from any map.
- **Areas (blockouts, Phase 2):** `farm` (Wrenfield, 50×32: farmhouse and bed, road with west/east
  exits, fenced tilled field, pond), `village` (Brambleford, 54×36: cobbled plaza, 8 blockout
  buildings with signs, railway, east exit), `forest` (Whisperwood, 60×40: winding paths, tall-grass
  patches for future habitats, river with bridges, Mirelight Pond, a log blocking the path to a mud
  flat and the Sunken Kiln ruin, which are future gates). Connections: village ⇄ farm ⇄ forest.
  `test_map` stays in the catalog for tests and experiments.
- **Blockout pipeline:** layouts are ASCII files `tools/maps/<id>.txt` (one character per 16 px
  cell). `tools/build_maps.tscn` turns them, plus a per-map marker config (spawns, exits, props,
  signs, reserved cells), into `game/world/maps/<id>.tscn` and the shared placeholder tileset. While
  maps are blockouts, edit the `.txt` and rebuild. Once a map gets final art, it moves to editor
  painting and leaves the tool.
- **Validation:** `tests/integration/test_world_maps.gd` checks every catalog map: ids match, exits
  lead to real spawns with a way back, every area is reachable from the farm, spawns are clear of
  exits, and every spawn, exit and interactable is reachable **on foot**. The last check is a flood
  fill over the real tile collision data.

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

### 6.5 Placeholder NPCs [implemented — Phase 2, minimal]

- `NpcData` (`data/npcs/<id>.tres`): `id`, `display_name`, `sprite` (4-direction sheet),
  `first_meeting_lines`, `repeat_lines`. Adding an NPC = data + a map marker, no code.
- `Npc` (`game/characters/npc/npc.tscn`) **is an `Interactable`** (prompt "Talk") with a
  `StaticBody2D` on physics layer 4 `npcs` (the player's mask now includes it). On interact it turns
  to face the speaker, picks first-meeting or repeat lines, sets the world flag `met_<id>` (so the
  memory is saved by `WorldState`) and emits `EventBus.conversation_requested(speaker, lines)`. The
  message box shows the speaker's name tag.
- Placed by the map tool (`npc` marker): **Tamsin** in the village plaza, **Odile** at the forest
  entrance, **Pell** outside the general store (Phase 4). All stand still.
- **Shopkeepers (Phase 4):** `NpcData.shop_id` set → interacting sets `met_<id>` and emits
  `EventBus.shop_requested(shop_id, speaker)` instead of dialogue; the HUD opens its `ShopMenu`.
- Deliberately **not** built: schedules, movement, relationships, gifts, quests, conditional
  dialogue. The NPC epic replaces the line lists with the data-driven dialogue system. Because the
  signal carries a speaker and lines, the HUD won't need to change.

### 6.6 Items, inventory and money [implemented — Phase 3]

- `ItemData` (`data/items/<id>.tres`): id, name, description, **tags**, base value (marks), stack
  size, optional icon. Behaviour comes from tags: `seed`, `crop`, `food`. Listed in
  `data/items/item_catalog.tres`.
- `Inventory` (pure `RefCounted`): fixed slots of `{item_id, quantity}`, stack limits from item data,
  `add` (returns overflow), all-or-nothing `remove`, `space_for`, `count`, JSON round trip. It is the
  single inventory model: crops now, kith food, materials and trade later. There is no second
  inventory anywhere.
- `PlayerState` (pure): `inventory`, `money` (never negative), `selected_seed` (the next carried seed,
  cycled with **Q**). Save section `player_state`. A missing section applies `NewGameConfig`
  (`data/config/new_game.tres`: 50 marks, 6 Pipweed, 3 Emberroot and 3 Bluecap seeds, 3 Bond
  Charms). Section v2 (Phase 4): loading a v1 section applies `NewGameConfig.upgrade_grants`
  (`{"2": {"bond_charm": 3}}`) once, so older saves get what a new game now starts with.
- **Economy (placeholder):** `Pricing.sell_price(item, qty)` = base value × quantity. This is the one
  place the future modifier stack plugs in. `Shipping.sell_all()` sells every carried `crop` item.
  The `ShippingCrate` by the farmhouse runs it **immediately** (not overnight) and reports what sold.
- HUD: money under the clock, selected seed bottom-left, a bag panel on **I** (a modal that pauses
  time).
- **Seed shop (Phase 4):** `ShopData` (`data/shops/<id>.tres`: id, name, greeting, `ShopOffer` list of
  item id + price) in `shop_catalog.tres`. `Shop.buy(player, shop, item_id, qty, content)` is
  all-or-nothing: unknown offer, not enough marks or no bag space change nothing. Prices are fixed and
  provisional (Pipweed 20, Emberroot 40, Bluecap 30). No stock, no selling to shops, one shop.
  `ContentDB.validate_shops()` checks offers.

### 6.7 Farming [implemented — Phase 3]

```
CropData (data/crops/*.tres)       definition: seed item, produce item + quantity,
                                   growth_days, regrow_days (0 = single harvest), stage_count, sprite sheet
CropState  (RefCounted)            instance: crop_id, days_grown, times_harvested
PlotState  (RefCounted)            tilled, watered (today), crop: CropState | null
FarmState  (RefCounted, "farm")    all plots by id; till/plant/water/harvest; advance_day()
FarmActions (static)               the context action for one button: TILL → PLANT → WATER → INSPECT → HARVEST
FarmPlot   (Interactable node)     presentation only: draws soil/wet/crop stage; forwards interact
```

- **One clock:** crops only grow in `FarmState.advance_day()`, which `Main` calls in the day transition
  right after `Clock.end_day()` and before the auto-save. A crop that was watered that day gains 1
  day; then all soil dries. Unwatered crops don't grow (and don't die, in the MVP). There's no other
  timer.
- **Plots are map data:** the map builder turns `p` cells into `FarmPlot` nodes with stable ids
  `"<map_id>:<x>,<y>"` (20 plots on the farm, on untilled-soil tiles). State lives in the session's
  `FarmState`, so crops keep growing while the farm map is unloaded.
- **Regrowth:** after a harvest, a regrowing crop goes back to `growth_days − regrow_days`.
- **Prompts are dynamic:** `Interactable.get_prompt()` plus the `prompt_changed` signal; the HUD
  follows them.
- **Adding a crop:** a `CropData` `.tres`, a seed item and a produce item with the right tags, and
  catalog entries. `ContentDB.validate()` (in tests) catches broken references. No code changes.
- **Helper hook (Phase 4):** `FarmState.apply_helper_action(action, limit) -> Array[plot_id]` is how
  anything other than the player's button works the farm. `&"water"` waters dry, tilled plots with
  a growing (not mature) crop, in stable plot-id order, up to `limit`. Kith helpers call it from the
  daily tick; a sprinkler could call it too. Unknown actions warn and do nothing.
- **Deliberately not built:** tools (hoe/can), seasons and withering, weather, fertiliser, quality.

## 7. Kith architecture [implemented — Phase 4 foundation; battle and tactical parts planned]

```
KithData   (Resource, data/kith/<id>.tres)   species, never mutated at runtime
  id, display_name, description, aspects, favourite_food_tags, liked_food_tags,
  helper_abilities (e.g. &"water"), bond_calm_needed, sprite, ui_color
  loves(item) / will_eat(item) / has_ability(id)
KithConfig (Resource, data/config/kith_config.tres)   every tunable number (party size, Trust,
  thresholds/labels, food gains, feeds per day, calm per food, bond item, helper Trust + limit)
KithState  (RefCounted)    one owned individual: uid ("kith_0001", never reused), species_id,
  nickname, trust, level/xp (unused until battles), fed_today, helper_actions_today,
  bonded_day, origin (spawn id). Only ids and values; species rules are looked up, not copied.
KithRoster (RefCounted, save section "kith")   the party: ordered members (max 6), active uid,
  add_new / remove / move / set_active / set_nickname, start_new_day()
KithCare     (static)   feeding from the one Inventory + Trust
KithBonding  (static)   prototype wild bonding: food → calm → Bond Charm → KithRoster.add_new
KithHelpers  (static)   daily helper work through FarmState.apply_helper_action
WildKith     (Interactable node)   presentation: a wild kith in a map, forwards interact to KithBonding
KithMenu / HUD label    presentation of the roster
```

- **Party = the roster.** There is no storage box yet; the party is every owned kith (max 6, from
  config). It has an order and one active kith. It lives in `GameSession`, not in a map or the
  Player node, so map changes don't touch it. Tactical units will be *built from* it, never stored
  in it.
- **Feeding** consumes exactly one item from the shared `Inventory`. Species diets are tags;
  favourite → +8 Trust, liked → +3, one counted meal per kith per day (reset in the daily tick).
  Refused food and a full kith consume nothing.
- **Trust** is an int 0–`trust_max` (100) with labels by threshold (0 Unfamiliar, 25 Friendly,
  50 Trusted, 75 Bonded). Shown in the party screen and the HUD.
- **Bonding (prototype):** wild kith are placed by the map builder (`wild_kith` marker, spawn id
  `"<map>:<x>,<y>"`). Calm and "already bonded" are `WorldState` flags (`kith_calm:<spawn>`,
  `kith_bonded:<spawn>`), so they persist and a spot bonds once. `WildKith` refreshes on
  `WorldState.flag_changed` and `WorldState.loaded`.
- **Helpers in the daily tick:** `Main.run_day_transition`: `Clock.end_day()` →
  `farm.advance_day()` → `kith.start_new_day()` → `KithHelpers.run_daily()` → auto-save. A kith
  helps if its species has the ability, its Trust ≥ `watering_min_trust` (25) and it has actions
  left today (`watering_daily_limit`, 3 plots). Work happens in the morning, wherever the player is;
  the wake-up message reports it ("Rillet watered 3 plots."). No input simulation, no pathing.
- **Validation:** `ContentDB.validate_kith()` checks ids, name/sprite, that each diet matches at least
  one food item, and that abilities are known (`ContentDB.KNOWN_ABILITIES`).

**Planned extensions (not built; how they attach):**

```
KithData   += base_stats: StatBlock, traits, learnset, maturation: Array[EvolutionRule], habitat,
              bond_rate, breeding, mount_type, tactical: TacticalProfile, visual
KithState  += potential/training: StatBlock, known_techniques, current_hp, status, wounded_days
              → derived stats via StatFormulas (never stored); KithState section version 2
BattleCreatureState (RefCounted) — built from a KithState when a creature battle starts
  stat stages, volatile status, technique uses; writes back HP/XP/Trust at the end
TacticalUnitState (RefCounted) — built from a KithState + TacticalProfile for a tactical battle
  grid position, strength pips, provisions; writes back wounds, XP and Trust at the end
```

Rules: `KithData` is never mutated at runtime. The two combat states never reference each other.
Both read aspects through a shared `AspectChart` resource. Adding a species = new `.tres` + art +
catalog entry.

## 8. Other planned system architecture

| System | Core types | Notes |
| --- | --- | --- |
| Inventory | ✅ see §6.6. Later: item use effects, chests, shop stock | Tags drive food, crafting and selling |
| Farming | ✅ MVP, see §6.7. Later: seasons, tools, more helper actions, fertiliser | Growth only in the daily tick |
| Economy | 🟡 `Pricing` + `Shipping` + `Shop.buy` (see §6.6). Later: `PriceModifier` stack (season, region, war tension, relationship), stock, selling to shops | One pricing entry point already exists |
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
- **Sections today:** `clock` (day index, minute), `world` (flags, discovered locations),
  `player_state` (money, inventory slots, selected seed; v2), `farm` (every plot: tilled, watered,
  crop id, days grown, times harvested), `kith` (next uid, active uid, members with every
  `KithState` field), `player` (map id, position, facing). They load in that order; the
  player comes last because it may change the map. Adding sections needed no format change. A save
  from before farming (`tests/fixtures/saves/v2_phase2_before_farming.json`, written by the Phase 2
  code) loads with new-game belongings and an untouched farm. A save from before kith
  (`v2_phase3_before_kith.json`, written by the Phase 3 code) loads with everything intact, an empty
  party, and 3 Bond Charms granted once through the `player_state` v1 → v2 upgrade. Unknown species
  in a saved party are skipped with a warning; their ids are still never reused.
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

- Runner: `godot --headless --path . res://tests/test_runner.tscn [-- --filter=<text>] [--dir=<res://dir>]`
  (running a scene means autoloads and project settings load exactly as in the game). It exits with
  code 0 on success and 1 on any failure, and fails fast if an autoload failed to load.
- Isolation: before every test the runner points `SaveService` at `user://test_saves` and wipes it,
  and resets `WorldState`.
- A test also fails if **any engine or script error** is logged while it runs. The runner installs a
  `Logger` (Godot 4.5+ API), so runtime errors such as a null call can't pass silently.
- `tests/framework/test_case.gd` (`TestCase`): `before_each`/`after_each`, `assert_eq`,
  `assert_true`, `assert_false`, `assert_almost_eq`, `assert_not_null`, plus helpers to add nodes and await
  physics frames. Every `test_*` method in `tests/unit/test_*.gd` and `tests/integration/test_*.gd` is run.
- Unit tests cover pure logic (time, save format and migrations, world state). Integration tests
  instantiate real scenes headlessly: the full farming loop through the real interact button and sleep
  flow, movement against collision, interaction, sleep flow, save/load
  through `Main`, migration from a real v1 file, map validation (exit graph and on-foot
  reachability), map transitions (including real walking through an exit), NPCs, and (Phase 4)
  wild-kith bonding, the party menu, Pell's shop, the watering helper while the player is in
  another map, and loading a real Phase 3 save.
- **Restart test:** `tests/persistence/run_restart_test.sh` saves in one Godot process (in the village,
  day 3, with a worked farm and a bonded, fed, renamed kith plus an active second kith) and verifies
  in a fresh process. It fails on any check or engine error.
- **Save fixtures:** `tests/fixtures/saves/*.json` are real files written by older formats. Every
  fixture must upgrade and load.
- CI: `.github/workflows/tests.yml` installs the pinned Godot, imports, runs the suite, the restart
  test and the spike tests.
- Visual check: `tools/capture_screenshots.tscn` plays a scripted tour of the real game (farm, sign,
  village, Tamsin, Pell's shop, forest, Odile, bonding, party menu, watering helper, night) and
  saves screenshots. It needs a display (`xvfb-run` on
  servers) and uses its own save directory.
- Current suite: 212 tests (128 unit, 84 integration) + the restart test + 30 spike tests.

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
| D12 | Maps addressed by id through a data catalog | Exits holding `PackedScene` references | No map-specific code; lazy loading; saves store ids; cyclic scene references avoided |
| D13 | One persistent Player node moved between maps | Re-instantiate the player per map | Player state (facing, future inventory/party links) survives transitions without copying |
| D14 | Blockout maps generated from ASCII layouts | Paint blockouts in the editor | Diffable, reviewable in PRs, trivially rebuilt when the tileset changes; editor painting starts with final art |
| D15 | `ContentDB` autoload for read-only content | Pass catalogs to every system | Content is global and immutable; one lookup API; validation in one place |
| D16 | Session state (`GameSession`) owned by `Main` and injected | More autoloads (`Farm`, `Player`) | Keeps mutable state out of globals; tests build sessions freely; future multiplayer (one session per player) |
| D17 | One context-sensitive interact button for farming | Tool hotbar (hoe, can, seeds) | Smallest coherent loop; tools come with farming depth later |
| D18 | Shipping crate pays immediately | Overnight shipping (Stardew-style) | Makes crop → value → money visible for the MVP; overnight is a later tuning choice |
| D19 | `KithData` (species) / `KithState` (individual) instead of the planned `CreatureData` / `CreatureInstance` names; no stats in Phase 4 | Build the full planned schema now | Phase 4 forbids battle stats; fields are added by the phase that uses them, with a section version bump |
| D20 | Party of 6 = every owned kith (no storage yet) | Retinue of 4 + paddock (earlier design) | Owner's Phase 4 brief: "up to 6"; storage comes when there are more kith than slots |
| D21 | Trust 0–100 with 4 labels | 0–255 shown as hearts (earlier design) | Owner's Phase 4 brief; readable numbers; provisional |
| D22 | Prototype bonding without battles: food → calm (WorldState flag) → Bond Charm always works | Wait for the battle phase | Lets the farm → food → kith loop exist now; the battle phase adds the chance formula on top of calm |
| D23 | Helpers act in the daily tick through `FarmState.apply_helper_action` | Kith walking to plots; fake player input | Map-independent, deterministic, testable; the same hook serves sprinklers later |
| D24 | Helper work happens in the morning (after growth, before the save) | Evening/overnight | Watered soil at wake-up is visible; crops then grow at the next day transition |
| D25 | Older saves get new starting items via `NewGameConfig.upgrade_grants` keyed by section version | Leave old saves without Bond Charms | Pre-Phase-4 players couldn't bond otherwise (charms aren't sold yet) |
| D26 | One seed shop, fixed prices, buy one at a time | Shop with stock, selling, quantity picker | Smallest version that keeps the loop going (seeds ran out in Phase 3) |
| D27 | Menus built in code from a generic `ListMenu` (text rows) | Bespoke scenes per menu | Two menus now, more later; consistent keys and pausing; real UI theme comes with final art |
