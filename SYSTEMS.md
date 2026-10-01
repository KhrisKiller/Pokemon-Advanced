# MONSERA — Systems

> What each system does, what it feeds, and its **real** implementation status.
> Status: ✅ implemented & tested · 🟡 partial · 🧪 isolated prototype · 📐 designed only · ⏳ not started.

## 1. System index

| System | Purpose | Status | Code | Data |
| --- | --- | --- | --- | --- |
| Time & calendar | Day/night, days, seasons, curfew, sleep | ✅ | `game/core/time/` | `data/config/time_config.tres` |
| Player controller | Movement, facing, control lock | ✅ | `game/characters/player/` | — |
| Camera | Follows the player, clamped to map | ✅ | `player.tscn`, `WorldMap` | — |
| Maps | Tile layers, entities, spawn points; farm, village, forest blockouts | ✅ blockouts | `game/world/`, `tools/maps/` | `data/maps/` |
| Map transitions | Exits, spawn by id, fade, state preserved | ✅ | `game/world/map_transition.gd`, `game/main/` | `data/maps/map_catalog.tres` |
| Interaction | Interactables and probe, prompts | ✅ | `game/core/interaction/` | per-prop exports |
| Messages | Modal text queue with speaker name tag | 🟡 placeholder for Dialogue | `game/ui/hud/` | — |
| Day transition | Sleep and curfew → next morning (home from any map) → crop growth → kith morning (reset, helpers) → auto-save | ✅ (no world-tick hook yet) | `game/main/main.gd` | — |
| Save / load | Persist everything | ✅ time, world, belongings, farm, kith, player; migrations; restart-tested | `game/core/save/` | `tests/fixtures/saves/` |
| Content DB | Look up content by id | ✅ items, crops, kith species, shops (maps/NPCs still separate) | `game/core/content_db.gd` | `data/items/`, `data/crops/`, `data/kith/`, `data/shops/` |
| Inventory | Items, stacks, tags, money | ✅ | `game/items/`, `game/characters/player/player_state.gd` | `data/items/`, `data/config/new_game.tres` |
| Farming | Plots, crops, growth, harvest, helper actions | ✅ MVP (no tools/seasons yet) | `game/farming/` | `data/crops/` |
| Kith (creatures) | Species vs individuals, party, Trust, diet, bonding, helpers | 🟡 Phase 4 foundation (no stats, battles, maturation) | `game/kith/` | `data/kith/`, `data/config/kith_config.tres` |
| Creature battle | 1v1 turn-based battles, bonding | 📐 | — | `data/moves/` |
| Tactical battle | Grid warfare with kith units | 📐 production · 🧪 isolated spike in `spikes/tactical/` awaiting evaluation | — | `data/maps/tactical/` |
| Exploration gates | Utility/mount-based obstacles | 📐 | — | map data |
| NPCs & schedules | Identity, talk, shopkeepers (now); routines, relationships, gifts (later) | 🟡 3 placeholder NPCs (Pell runs a shop), no schedules | `game/characters/npc/` | `data/npcs/` |
| Dialogue | Data-driven conversations with conditions | 📐 | — | `data/dialogue/` |
| Quests | Stages, conditions, rewards | 📐 | — | `data/quests/` |
| Economy | Prices, shops, modifier stack | 🟡 base-value selling via shipping crate; one seed shop with fixed prices | `game/economy/` | `data/items/`, `data/shops/` |
| Callings | Domain progression without classes | 📐 | — | — |
| World state & war | Flags, tension, factions, daily world tick | 🟡 flags + discovered locations (saved); war not started | `game/core/world_state.gd` | `data/factions/` |
| Audio | Music by time/place, SFX | ⏳ | — | — |

## 2. Interaction matrix

Rows **feed** columns. Every system must feed at least two others. (✔ = designed link, ★ = in vertical slice)

| feeds → | Farming | Kith | C.Battle | Tactical | Explore | NPCs | Economy | World/War |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| **Farming** | | ★ food, trust, calm | ✔ prepared buffs | ★ rations → provisions | | ✔ gifts | ★ crops to sell | ✔ supplies to factions |
| **Kith** | ★ water, till | | ★ combatants | ★ units | ★ haul, mount | ✔ companions | ✔ wool, labour | ✔ recruitment |
| **C. Battle** | | ★ XP, bonding | | ✔ veteran traits | ✔ guardians | ✔ trainer rivals | ✔ prize money | |
| **Tactical** | ✔ land unlocked | ★ wounds, XP, trust | | | ✔ routes open | ★ reactions | ✔ contracts | ★ territory, tension |
| **Exploration** | ✔ seeds, forage | ★ habitats, new kith | ★ encounters | ✔ scouting intel | | ✔ lore quests | ✔ rare goods | ✔ ruins, leystone |
| **NPCs** | ✔ recipes, tools | ✔ trade/gift kith | ✔ trainers | ★ militia allies, commanders | ✔ hints | | ★ shops | ✔ faction sympathy |
| **Economy** | ★ seeds, upgrades | ✔ food, charms | ✔ items | ✔ supplies | ✔ gear | ✔ gifts | | ✔ war profiteering |
| **World/War** | ✔ scarcity, raids | ✔ population shifts | ✔ soldiers as trainers | ★ battles triggered | ✔ routes closed/open | ★ schedules, dialogue | ★ prices | |
| **Time** | ★ growth by day | ✔ technique uses, maturation windows | | ✔ campaign calendar | ✔ day/night kith | ★ schedules | ✔ seasonal prices | ★ daily world tick |

## 3. System notes

### Time & calendar ✅
6:00→2:00 days, 28-day seasons, 4 seasons, 7-day week. Time pauses during modals (reason-keyed
pause requests). The day transition is the heartbeat hook: farming growth, world tick, NPC schedule
reset and auto-save will all be attached there, in that order.
*Tuning:* 0.7 s per game minute ≈ 14 real minutes per day.

### Player & camera ✅
Analog 8-way movement at 80 px/s (5 tiles/s) with acceleration/friction; 4-way facing.
Camera is smoothed and limited to the map. *Next:* movement classes for mounts; run/stamina (Farming epic).

### Save / load ✅ (v1)
JSON slots with atomic writes and a backup; format v2 with `meta` for a future load screen; tested
v1 → v2 migration from a real fixture; restart-tested in two processes. Auto-save on sleep; the game
continues from slot 1 on start. See `TECHNICAL_DESIGN.md` §9.

### Maps & transitions ✅ (blockouts)
Farm ⇄ village, farm ⇄ forest. One persistent Player node. Exits and spawns are data. Every map is
checked automatically for on-foot reachability. See `TECHNICAL_DESIGN.md` §6.3.

### Interaction ✅
Front-facing probe; closest enabled interactable wins; HUD prompt shows the interact key and the
verb. Extensible by subclassing `Interactable` (sign and bed exist). *Next:* NPC talk, pickups,
farm plots, doors/map transitions.

### Farming ✅ (MVP)
20 plots on the farm. One interact button does the next step: till → plant the selected seed (Q
cycles) → water → inspect → harvest. Crops are data (growth days, regrow, produce, stage art). Growth
happens only in the day transition, and only if the crop was watered that day. Harvests go into the
shared bag; the shipping crate sells crops for money. Everything is saved.
Kith helpers work through `FarmState.apply_helper_action(action, limit)`, called by the daily
simulation, never by fake input (Phase 4: `water`).
*Not yet:* tools, seasons/withering, weather.
*Feel (Phase 3):* the loop is coherent but manual. Every plot is walk-up-and-press, once per plot per
day, which is fine at ~5 plots and tedious at 20. Seeds run out (no seed shop), so the loop ends
unless you grow Bluecap, which regrows. Mature crops are hard to tell apart from growing ones in the
placeholder art. (Phase 4 adds the seed shop and the watering helper, which address the first two.)

### Kith 🟡 (Phase 4 foundation)
Species are `KithData` (`data/kith/`); each owned kith is a `KithState` with a unique uid, nickname,
Trust 0–100 and daily state. The party (`KithRoster`, max 6, one active) is saved in section `kith`
and doesn't care which map is loaded. Wild kith stand in the maps (`WildKith`): offer food it eats
until it is calm, then a Bond Charm, and it joins the party; the spot stays empty (WorldState flag).
Feeding uses the one inventory: one item, Trust +8 (loved) or +3 (liked), once per kith per day.
Helper abilities run in the daily tick: a Rillet with Trust ≥ 25 waters up to 3 growing plots each
morning, wherever the player is. Party screen on **K**. All numbers are in `kith_config.tres`.
*Not yet:* stats, techniques, battles, maturation, storage beyond 6, followers, tactical units.
*Feel (Phase 4, automated runs only):* bonding needs food, and food needs a harvest, so the first
kith comes after a few in-game days of farming; Trust ≥ 25 for watering takes two favourite meals.

### Creature battle 📐
1v1, speed order, 4 techniques with limited uses, switching, items, bond attempts, flee.
Aspect chart shared with tactical. Result → XP, trust, bonding.

### Tactical battle 📐
Separate scene. Grid map from data, terrain with defence and per-movement-class costs, roles,
counterattacks, provisions, objectives (rout/hold/capture/escort/survive), a simple utility AI and
commander doctrines (post-slice). Result → `WorldState` + wounded kith + reputation.

### NPCs, dialogue, quests 📐
Weekly schedules with condition overrides (season, weather, festival, war phase). Relationship
0–10 hearts, gift tastes by tag. Dialogue and quests share the `Condition`/`Effect` vocabulary.

### Economy 🟡
Now: `Pricing.sell_price` = base value; the shipping crate sells every carried crop immediately.
Pell's seed shop (`ShopData` in `data/shops/`, opened by talking to an NPC with `shop_id`) sells the
three seeds at fixed prices, one at a time, with the same money and bag (`Shop.buy`, all-or-nothing).
Planned: base value × modifier stack; shops sell and buy from data lists; overnight shipping is still
an open choice (D18); war tension modifies specific item tags (e.g. rations +50 %).

### Callings 📐
XP per domain from EventBus events (crop harvested, kith bonded, battle won, area discovered, item
sold, tactical victory, gift given). Level curve, small perks.

### World state & war 📐
`WorldState` holds flags/counters/tension/faction control/route status. `WorldEvent` resources are
evaluated in the daily tick. The war advances on a calendar of phases; player actions shift timing and
outcomes. Everything reads world state through `Condition`s, so there are no special cases in code.
