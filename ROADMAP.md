# MONSERA — Roadmap

> Structure: **EPIC → MILESTONE → FEATURE → task**. `[x]` = done and verified by tests or a manual run.
> The first major goal is the **Vertical Slice** (`GDD.md` §15). Nothing past it is scheduled in detail.

## Phases

| Phase | Name | Exit criterion | Status |
| --- | --- | --- | --- |
| 0 | Pre-production & architecture | All foundation docs exist and agree | ✅ |
| 1 | Basic Godot project | Project boots; player walks a test map with camera, interaction and a day clock; tests run in CI | ✅ |
| 2 | Player & world | Map transitions, farm + village + forest blockouts, NPC placeholders, **save/load v1** | ⏳ next |
| 3 | Basic farming | Till → plant → water → sleep → grow → harvest → sell loop, with saves | ⏳ |
| 4 | Basic creature system | Kith data, instances, retinue, feeding/trust, one utility action | ⏳ |
| 5 | Creature battle | Wild 1v1 battle + bonding from an overworld encounter | ⏳ |
| 6 | Exploration | Utility gates, Loamox haul + mount, Sunken Kiln dungeon | ⏳ |
| 7 | Basic tactical combat | One tactical battle playable end to end, win or lose | ⏳ |
| 8 | Connect systems | Rations→provisions, war tension→prices/dialogue, wounds→farm rest, callings | ⏳ |
| 9 | Vertical slice | 30–60 minute slice playable by a stranger without help | ⏳ |
| 10 | Polish & expansion | Art pass, audio, balance, then the next region | ⏳ |

**Risk-first rule:** the tactical prototype (Phase 7) may start a greybox spike during Phase 4–5 if
the team wants to de-risk it earlier (see "Risks" below).

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Scope explosion (four genres in one game) | Never finishing | Vertical slice first; systems validated with 1–3 content items before mass content; each phase has an exit criterion |
| Tactical combat isn't fun, or is too big to build | The war pillar collapses | Optional early greybox spike; fallback (inherited from Design.pdf): tactics only for story battles |
| Systems feel disconnected ("four minigames") | Core promise fails | Interaction matrix in `SYSTEMS.md`; Phase 8 is dedicated to links; slice beats require cross-system use |
| Two combat systems double the balance work | Slow tuning | Shared aspect chart and stats with separate derived profiles; formulas in one tested place |
| Save compatibility breaks as systems grow | Lost playtest saves | Versioned save sections with migrations from Save v1 |
| Creature designs drift towards existing franchises | Legal/identity risk | Originality rules in `CREATURE_BIBLE.md` and `ART_BIBLE.md`; review every concept |
| Solo/beginner developer bandwidth | Stalls | Small phases, tests + CI, docs that stay truthful, `CLAUDE.md` workflow |
| Art production cost | Placeholder look forever | Style test before production; limited slice asset list |

---

## EPIC: CORE

### Milestone: Foundation (Phase 1) ✅
- Feature: Project setup
  - [x] Godot 4.7.2 project, GL Compatibility, 640×360 integer scaling
  - [x] Input map (keyboard + gamepad): move, interact, debug skip hour
  - [x] Physics layer names
  - [x] `EventBus` autoload
  - [x] Pinned Godot installer script, `.gitignore`, `.gitattributes`
- Feature: Tests & CI
  - [x] Headless test runner scene + `TestCase` base
  - [x] GitHub Actions workflow running the suite (46 tests)
  - [x] Screenshot tool that drives the real game (`tools/capture_screenshots.tscn`)
- Feature: Time
  - [x] `TimeConfig` resource, `GameTime` model, `Clock` autoload
  - [x] Pause requests keyed by reason
  - [x] Curfew at 2:00, `end_day()`
  - [x] Day/night tint
  - [x] Unit tests for calendar math, rollover, serialization
- Feature: Interaction
  - [x] `Interactable` base, `InteractionProbe`, closest-target selection
  - [x] Sign and bed props
  - [x] Integration tests
- Feature: Day transition
  - [x] Sleep and curfew flow with fade, wake-up message

### Milestone: Content pipeline (Phase 2–4)
- Feature: Content DB
  - [ ] `ContentDB` autoload, scan `data/<kind>/`, index by id, `.remap` handling
  - [ ] Validation tool: duplicate ids, missing references (runs in tests)
- Feature: Condition/Effect vocabulary
  - [ ] Base `Condition`/`Effect` resources + 5 common ones

## EPIC: SAVE

### Milestone: Save v1 (Phase 2)
- [ ] `SaveService` autoload with provider registration (`get_save_id/to_save_data/load_save_data`)
- [ ] JSON slot files + meta file, versioned sections, migration hook
- [ ] Providers: clock, player (map + position + facing)
- [ ] Auto-save at the end of the day transition
- [ ] Load from title/continue
- [ ] Tests: round trip, missing section tolerance, version migration

### Milestone: Save v2 (Phases 3–8)
- [ ] Providers: inventory, money, farm plots, kith instances, NPC relationships, quests, world state, discovered locations, decisions

## EPIC: WORLD

### Milestone: World structure (Phase 2)
- [ ] Map transition triggers + `SceneRouter` (fade, spawn point by id)
- [ ] Blockouts: Wrenfield farm, Brambleford village, Whisperwood (placeholder tiles)
- [ ] Farmhouse interior
- [ ] Map registry data (id, display name, region, music)
### Milestone: World state (Phase 8)
- [ ] `WorldState` (flags, counters, war tension, route status) + save provider
- [ ] `WorldEvent` resources evaluated in the daily tick
- [ ] Slice events: surveyors arrive (day 3), bridge skirmish (day 4), outcome flags

## EPIC: FARMING

### Milestone: Farming MVP (Phase 3)
- [ ] Farm map with 6–10 plots (tillable tile custom data)
- [ ] `FarmState` + plot model (tilled, watered, crop, stage, days)
- [ ] Tools: hoe, watering can, seeds (hotbar placeholder)
- [ ] `CropData` resources: Pipweed, Emberroot, Bluecap
- [ ] Growth at day transition; watering resets daily; seasonal death
- [ ] Harvest → inventory
- [ ] Sell via shipping bin (paid overnight)
- [ ] Tests: growth timing, watering, regrow, season change
### Milestone: Farming × systems (Phase 8)
- [ ] Creature food integration (crops tagged as kith food)
- [ ] Cooking station: crop → ration (tactical provisions)
- [ ] Kith utility: Rillet waters 3×1, Sprigmole tills 3×1

## EPIC: CREATURES

### Milestone: Kith data (Phase 4)
- [ ] `CreatureData`, `StatBlock`, `TacticalProfile`, `DietProfile`, `EvolutionRule` resources
- [ ] `AspectChart` resource + tests
- [ ] `StatFormulas` + tests
- [ ] 12 species data files (placeholder visuals); 6 fully tuned
- [ ] `CreatureInstance` + save provider
### Milestone: Kith in the world (Phase 4)
- [ ] Retinue (4) + paddock storage
- [ ] Follower kith in the overworld
- [ ] Feeding → trust; diet tags
- [ ] Starter selection at Warden Odile's
### Milestone: Maturation & breeding (post-slice)
- [ ] Evolution rules evaluated after level-up/feeding/day tick
- [ ] Breeding (post-slice)

## EPIC: COMBAT (creature battle)

### Milestone: Battle MVP (Phase 5)
- [ ] `TechniqueData` resources (8–12 techniques)
- [ ] `BattleCreatureState` adapter from `CreatureInstance`
- [ ] Turn state machine: choose → order by speed → resolve → end of turn → check end
- [ ] Damage formula with aspect chart, crits, variance (seeded RNG) + tests
- [ ] 5 status effects + tests
- [ ] Switching, items, flee
- [ ] Bond attempt with calm/food modifier + tests
- [ ] XP, levels, write-back to instance
- [ ] Battle UI (placeholder)
- [ ] Wild encounters from habitat tables (Mirelight Pond)

## EPIC: TACTICAL

### Milestone: Tactical prototype (Phase 7)
- [ ] `TacticalMapData`, `TerrainData` (defence, move costs per class)
- [ ] Grid rendering, cursor, camera
- [ ] `TacticalUnitState` adapter from `CreatureInstance` + `TacticalProfile`
- [ ] Pathfinding (Dijkstra over costs) + reachable-tile highlight + tests
- [ ] Attack ranges (melee, ranged min/max, no move-and-fire) + counterattacks
- [ ] Tactical damage formula (strength pips, terrain defence, aspect chart) + tests
- [ ] Provisions: consumption, Hungry state, Support resupply
- [ ] Enemy AI v1: utility score (attack best target / advance / hold)
- [ ] Objectives: rout, hold N turns
- [ ] Brambleford Crossing map; win/lose; return to overworld with `TacticalResult`
### Milestone: Tactical × world (Phase 8)
- [ ] Rations → provisions at deployment
- [ ] Wounded kith rest N days at the farm
- [ ] Outcome writes world state (tension, flags, NPC reactions)
### Milestone: Commanders (post-slice)
- [ ] Commander data, doctrines, rally powers

## EPIC: EXPLORATION

### Milestone: Exploration MVP (Phase 6)
- [ ] Whisperwood map with Mirelight Pond habitat
- [ ] Utility gates: log (haul), mud (land mount)
- [ ] Mount system: movement classes, mount/dismount, collision mask change
- [ ] Forage spawns (daily)
- [ ] Sunken Kiln: 3–5 rooms, pressure plates + heat vents, guardian, Kilnwright Lantern reward
- [ ] Lore fragments (readable)

## EPIC: NPC

### Milestone: NPC MVP (Phase 2 placeholders → Phase 8 schedules)
- [ ] `NpcData` resources for the 5 slice NPCs
- [ ] Talk interaction; data-driven dialogue with conditions (replace the Phase 1 message queue)
- [ ] Schedules (day/time → location) with world-state overrides
- [ ] Relationship points + gifts by tag
- [ ] War-reactive dialogue sets

## EPIC: ECONOMY

### Milestone: Economy MVP (Phase 3)
- [ ] Inventory (slots, stacks, tags) + tests
- [ ] Money + HUD
- [ ] `PriceService` with modifier stack (season modifier first) + tests
- [ ] General store (Pell): buy seeds/charms, sell goods
### Milestone: Reactive economy (Phase 8)
- [ ] War tension modifiers by item tag
- [ ] Contracts (militia buys rations)

## EPIC: PROGRESSION

- [ ] `CallingProgress` (7 callings), XP from EventBus events, level curve (Phase 8)
- [ ] Callings UI page
- [ ] Perks (post-slice)

## EPIC: STORY

### Milestone: Slice narrative (Phases 2–9)
- [ ] Arrival cutscene (train → station → Reeve)
- [ ] Starter kith scene
- [ ] Surveyors' arrival event (day 3)
- [ ] Captain Brask's request + bridge battle briefing/debriefing
- [ ] Ending hook
- [ ] Main-story outline beyond the slice (doc only)

## EPIC: UI

### Milestone: UI foundation (Phase 1–2)
- [x] HUD clock (date + time, 10-minute steps)
- [x] Interaction prompt with the bound key
- [x] Message box (modal, pauses time)
- [x] Screen fade
- [ ] Pause menu (resume, save, settings, quit) (Phase 2)
- [ ] Inventory/hotbar (Phase 3), kith party screen (Phase 4), battle UI (Phase 5), tactical UI (Phase 7)
- [ ] Pixel font + UI theme resource (Phase 10 at latest)
- [ ] Controller glyphs

## EPIC: ART & AUDIO

- [x] Placeholder art generator (tiles, player, props)
- [ ] Style test: 1 map in final style (Phase 9–10, see `ART_BIBLE.md`)
- [ ] Final tilesets for the slice; kith sprites for the 6 slice kith
- [ ] Music: farm day/night, village, forest, battle, tactical; SFX set
