# MONSERA — Roadmap

> Structure: **EPIC → MILESTONE → FEATURE → task**. `[x]` = done and verified by tests or a manual run.
> The first major goal is the **Vertical Slice** (`GDD.md` §15). Nothing past it is scheduled in detail.

## Phases

| Phase | Name | Exit criterion | Status |
| --- | --- | --- | --- |
| 0 | Pre-production & architecture | All foundation docs exist and agree | ✅ |
| 1 | Basic Godot project | Project boots; player walks a test map with camera, interaction and a day clock; tests run in CI | ✅ |
| 2 | Player & world | Save/load across restarts with a tested migration; transitions between farm, village and forest blockouts; 2 placeholder NPCs; tactical spike isolated | ✅ |
| 3 | Basic farming | Till → plant → water → sleep → grow → harvest → sell loop, with saves (restart-tested); tactical spike v0.2 isolated | ✅ |
| 4 | Basic creature system | Kith species data vs individuals, party of 6, feeding/Trust, prototype bonding, one helper ability (watering) in the daily tick, seed shop; saves (restart- and migration-tested) | ✅ |
| 5 | Creature battle | Wild 1v1 battle + bonding from an overworld encounter | ⏳ next (needs owner approval) |
| 6 | Exploration | Utility gates, Loamox haul + mount, Sunken Kiln dungeon | ⏳ |
| 7 | Basic tactical combat | One tactical battle playable end to end, win or lose | ⏳ |
| 8 | Connect systems | Rations→provisions, war tension→prices/dialogue, wounds→farm rest, callings | ⏳ |
| 9 | Vertical slice | 30–60 minute slice playable by a stranger without help | ⏳ |
| 10 | Polish & expansion | Art pass, audio, balance, then the next region | ⏳ |

**Risk-first rule:** the riskiest system (tactical combat) was spiked early, in Phase 2, as an isolated
prototype (`spikes/tactical/`). Its verdict (proceed / iterate / fall back) comes from the owner's
evaluation and decides how Phase 7 is scoped.

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
  - [x] `ContentDB` autoload: items and crops by id from catalog resources (no folder scanning, so no `.remap` issues) (Phase 3)
  - [x] `ContentDB.validate()`: duplicate ids, missing seed/produce references, missing art (runs in tests) (Phase 3)
  - [x] Kith species and shops through `ContentDB`; `validate()` checks diets, abilities and shop offers (Phase 4)
  - [ ] Maps and NPCs through `ContentDB` too (maps currently use `MapCatalog` on `Main`)
- Feature: Condition/Effect vocabulary
  - [ ] Base `Condition`/`Effect` resources + 5 common ones

## EPIC: SAVE

### Milestone: Save v1 (Phase 2) ✅
- [x] `SaveService` autoload with provider registration (`get_save_id/to_save_data/load_save_data`)
- [x] JSON slot files, atomic writes, `.bak` fallback, `meta` block (format v2) for a future load screen
- [x] File-format migrations (`SaveMigrations`, v1 → v2) + section-level versions (player v1 → v2)
- [x] Providers: clock, world (flags, discovered locations), player (map + position + facing)
- [x] Auto-save at the end of the day transition; debug quicksave/quickload (F5/F9)
- [x] Continue from slot 1 on start (no title screen yet; see UI)
- [x] Tests: round trip, missing sections, corrupt file → backup, unsupported version, real v1 fixture migration, game boot from v1, **two-process restart test**

### Milestone: Save coverage (Phases 3–8)
- [x] Providers: inventory + money + selected seed (`player_state`), farm plots (`farm`) (Phase 3)
- [x] Provider: kith party (`kith`); `player_state` section v2 grants Bond Charms to older saves; real Phase 3 fixture (Phase 4)
- [ ] Providers: NPC relationships, quests, war state, decisions

## EPIC: WORLD

### Milestone: World structure (Phase 2) ✅
- [x] Map transition triggers (`MapTransition`) + transition flow in `Main` (fade, spawn by id, same Player node)
- [x] Blockouts: Wrenfield farm, Brambleford village, Whisperwood (ASCII layouts → scenes)
- [x] Map registry data (`MapInfo`/`MapCatalog`: id, display name, scene path, region)
- [x] Automated navigability checks (exit graph, on-foot reachability)
- [ ] Farmhouse interior (the house is a roofless blockout for now) — later phase
- [ ] Per-map music id in `MapInfo` — with the audio work
### Milestone: World state (Phases 2 → 8)
- [x] `WorldState` flags (bool/int/String), counters, discovered locations + save provider (Phase 2)
- [ ] War tension, faction control, route status
- [ ] `WorldEvent` resources evaluated in the daily tick
- [ ] Slice events: surveyors arrive (day 3), bridge skirmish (day 4), outcome flags

## EPIC: FARMING

### Milestone: Farming MVP (Phase 3) ✅
- [x] Farm map with 20 plots (map-builder marker `p`, stable ids `farm:x,y`)
- [x] `FarmState` + `PlotState`/`CropState` (tilled, watered, crop, days grown, harvests)
- [x] One context-sensitive interact (till → plant selected seed → water → inspect → harvest); **Q** cycles seeds
- [x] `CropData` resources: Pipweed (3 days), Emberroot (5), Bluecap (4, regrows every 2)
- [x] Growth in the existing day transition; watering resets daily; unwatered crops don't grow
- [x] Harvest → the shared `Inventory`; bag full → crop kept
- [x] Sell via the shipping crate (immediate) → money
- [x] Save/load of plots, bag, money, selected seed; two-process restart test
- [x] Tests: growth day by day, watering, maturity, harvest, regrow, bag, selling, persistence, growth while away
- [ ] Tools (hoe, watering can) + hotbar — with farming depth
- [ ] Seasons: planting seasons and withering at season change
- [x] Buying seeds from Pell's seed shop (Phase 4)
### Milestone: Farming × systems (Phase 8)
- [x] Creature food integration: crops carry `food` + diet tags (`root`, `spicy`, `fungus`) (Phase 4)
- [ ] Cooking station: crop → ration (tactical provisions)
- [x] Kith utility: Rillet waters up to 3 plots each morning through `FarmState.apply_helper_action` (Phase 4)
- [ ] More helper abilities (Sprigmole tills, …) — same hook, new ability id

## EPIC: CREATURES

### Milestone: Kith foundation (Phase 4) ✅
- [x] `KithData` (species: id, name, aspects, diet tags, helper abilities, calm needed, sprite) in `data/kith/` + `KithCatalog`
- [x] `KithState` (individual: unique uid, species id, nickname, Trust, level/xp placeholders, daily state, origin)
- [x] `KithRoster` party (max 6, order, active kith, nickname) + save provider `kith`; independent of tactical units
- [x] `KithConfig` tunables (party size, Trust thresholds/labels, food gains, helper Trust + daily limit)
- [x] 4 prototype species: Bramblehog (eats anything), Sprigmole (roots), Cindercoot (spicy), Rillet (fungus, waters)
- [x] Feeding from the one inventory (`KithCare`): consumes one item, Trust +8/+3, one feeding per day, refusals keep the item
- [x] Trust 0–100 with labels Unfamiliar / Friendly / Trusted / Bonded (provisional)
- [x] Prototype bonding (`KithBonding`): offer liked food until calm → Bond Charm → new `KithState`; wild spot remembered in `WorldState`
- [x] Wild kith in the maps (`WildKith`, map-builder marker `wild_kith`): Sprigmole on the farm; Rillet, Bramblehog, Cindercoot in Whisperwood
- [x] Watering helper (`KithHelpers`) in the day transition, any map, Trust ≥ 25, ≤ 3 plots/day
- [x] Party screen on **K** (inspect, feed, set active, rename) + HUD active-kith label
- [x] Tests: data/validation, state, party, feeding, bonding, helper rules, in-game flows, save/restart, Phase 3 save migration
### Milestone: Kith data for battles (Phase 5+)
- [ ] Stats (`StatBlock`), `AspectChart` + tests, `StatFormulas` + tests — added to `KithData` by the battle phase
- [ ] `TacticalProfile`, `EvolutionRule` resources
- [ ] More species (target 12 for the slice); 6 fully tuned
### Milestone: Kith in the world (later)
- [ ] Storage beyond the party (paddock)
- [ ] Follower kith in the overworld
- [ ] Starter selection at Warden Odile's
### Milestone: Maturation & breeding (post-slice)
- [ ] Evolution rules evaluated after level-up/feeding/day tick
- [ ] Breeding (post-slice)

## EPIC: COMBAT (creature battle)

### Milestone: Battle MVP (Phase 5)
- [ ] `TechniqueData` resources (8–12 techniques)
- [ ] `BattleCreatureState` adapter from `KithState`
- [ ] Turn state machine: choose → order by speed → resolve → end of turn → check end
- [ ] Damage formula with aspect chart, crits, variance (seeded RNG) + tests
- [ ] 5 status effects + tests
- [ ] Switching, items, flee
- [ ] Bond attempt with calm/food modifier + tests
- [ ] XP, levels, write-back to instance
- [ ] Battle UI (placeholder)
- [ ] Wild encounters from habitat tables (Mirelight Pond)

## EPIC: TACTICAL

### Milestone: Tactical spike (Phase 2, isolated) ✅ — awaiting owner evaluation
- [x] `spikes/tactical/`: 10×8 grid, 2v2, movement, attack + counters, terrain modifiers, hold objective, victory/defeat
- [x] Rule tests (separate CI step) and bot simulation (skill-driven: random 0 %, greedy 100 %)
- [ ] Owner playtest using the protocol in `spikes/tactical/README.md`, then a verdict

### Milestone: Tactical spike v0.2 (Phase 3, isolated) ✅ — awaiting owner evaluation
- [x] 3v3 on 10×8, 5 roles, Hold / Rout / Escort (reach + protect) scenarios, zone of control, danger-zone view
- [x] Probe: objectives and position decide outcomes (Escort: objective-blind 0 % vs 51 %; Hold: anchoring 78 % vs 10 %); ZOC matters; rout-with-timer and single-tile holds are weak
- [x] 30 rule tests (v0.1 tests unchanged)
- [ ] Owner playtest (README protocol, questions 1–10) → verdict

### Milestone: Tactical prototype (Phase 7)
- [ ] `TacticalMapData`, `TerrainData` (defence, move costs per class)
- [ ] Grid rendering, cursor, camera
- [ ] `TacticalUnitState` adapter from `KithState` + `TacticalProfile`
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
- [x] Minimal NPC architecture: `NpcData` + `Npc` interactable (identity, position, talk, placeholder lines) (Phase 2)
- [x] 2 placeholder NPCs: Tamsin (village), Odile (forest); "met" remembered via world flag (Phase 2)
- [x] Shopkeeper NPCs: `NpcData.shop_id` opens a shop instead of dialogue (Pell, Phase 4)
- [ ] `NpcData` for the remaining slice NPCs
- [ ] Data-driven dialogue with conditions (replaces the placeholder line lists)
- [ ] Schedules (day/time → location) with world-state overrides
- [ ] Relationship points + gifts by tag
- [ ] War-reactive dialogue sets

## EPIC: ECONOMY

### Milestone: Economy MVP (Phase 3 → later)
- [x] Inventory (slots, stacks, tags) + tests (Phase 3)
- [x] Money + HUD (Phase 3)
- [x] `Pricing.sell_price` (base value) + `Shipping.sell_all` + placeholder shipping crate (Phase 3)
- [ ] Price modifier stack (season modifier first) + tests
- [x] Seed shop (Pell): `ShopData` offers + `Shop.buy`, fixed provisional prices, buy one at a time (Phase 4)
- [ ] General store: charms and goods, selling to shops, stock
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
- [x] Location banner on map change; speaker name tag in the message box (Phase 2)
- [x] Money display, selected-seed display, bag panel on **I** (pauses time) (Phase 3)
- [ ] Title screen (continue / new game) and pause menu (resume, save, settings, quit) — not in the Phase 3 scope; still open
- [x] Generic modal `ListMenu` (pauses time; ↑/↓, E, Esc); shop menu; kith party screen on **K**; active-kith HUD label (Phase 4)
- [ ] Hotbar (with tools), battle UI (Phase 5), tactical UI (Phase 7)
- [ ] Pixel font + UI theme resource (Phase 10 at latest)
- [ ] Controller glyphs

## EPIC: ART & AUDIO

- [x] Placeholder art generator (tiles, player, props)
- [ ] Style test: 1 map in final style (Phase 9–10, see `ART_BIBLE.md`)
- [ ] Final tilesets for the slice; kith sprites for the 6 slice kith
- [ ] Music: farm day/night, village, forest, battle, tactical; SFX set
