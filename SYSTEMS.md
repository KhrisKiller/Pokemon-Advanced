# MONSERA — Systems

> What each system does, what it feeds, and its **real** implementation status.
> Status: ✅ implemented & tested · 🟡 partial · 📐 designed only · ⏳ not started.

## 1. System index

| System | Purpose | Status | Code | Data |
| --- | --- | --- | --- | --- |
| Time & calendar | Day/night, days, seasons, curfew, sleep | 🔨 Phase 1 | `game/core/time/` | `data/config/time_config.tres` |
| Player controller | Movement, facing, control lock | 🔨 Phase 1 | `game/characters/player/` | — |
| Camera | Follows the player, clamped to map | 🔨 Phase 1 | `player.tscn`, `WorldMap` | — |
| Maps | Tile layers, entities, spawn points | 🔨 Phase 1 | `game/world/` | tileset `.tres` |
| Interaction | Interactables and probe, prompts | 🔨 Phase 1 | `game/core/interaction/` | per-prop exports |
| Messages | Simple modal text queue | 🟡 placeholder for Dialogue | `game/ui/hud/` | — |
| Day transition | Sleep and curfew → next morning | 🔨 Phase 1 | `game/main/main.gd` | — |
| Save / load | Persist everything | 📐 contract fixed (`TECHNICAL_DESIGN` §9) | — | — |
| Content DB | Look up content by id | 📐 | — | `data/*` |
| Inventory | Items, stacks, tags | 📐 | — | `data/items/` |
| Farming | Plots, crops, growth, harvest | 📐 | — | `data/crops/` |
| Kith (creatures) | Species data, instances, trust, diet, maturation | 📐 | — | `data/creatures/` |
| Creature battle | 1v1 turn-based battles, bonding | 📐 | — | `data/moves/` |
| Tactical battle | Grid warfare with kith units | 📐 | — | `data/maps/tactical/` |
| Exploration gates | Utility/mount-based obstacles | 📐 | — | map data |
| NPCs & schedules | Routines, relationships, gifts | 📐 | — | `data/npcs/` |
| Dialogue | Data-driven conversations with conditions | 📐 | — | `data/dialogue/` |
| Quests | Stages, conditions, rewards | 📐 | — | `data/quests/` |
| Economy | Prices, shops, modifier stack | 📐 | — | `data/items/`, shops |
| Callings | Domain progression without classes | 📐 | — | — |
| World state & war | Flags, tension, factions, daily world tick | 📐 | — | `data/factions/` |
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

### Time & calendar 🔨 (Phase 1)
6:00→2:00 days, 28-day seasons, 4 seasons, 7-day week. Time pauses during modals (reason-keyed
pause requests). The day transition is the heartbeat hook: farming growth, world tick, NPC schedule
reset and auto-save will all be attached there, in that order.
*Tuning:* 0.7 s per game minute ≈ 14 real minutes per day.

### Player & camera 🔨 (Phase 1)
Analog 8-way movement at 80 px/s (5 tiles/s) with acceleration/friction; 4-way facing.
Camera is smoothed and limited to the map. *Next:* movement classes for mounts; run/stamina (Farming epic).

### Interaction 🔨 (Phase 1)
Front-facing probe; closest enabled interactable wins; HUD prompt shows the interact key and the
verb. Extensible by subclassing `Interactable` (sign and bed exist). *Next:* NPC talk, pickups,
farm plots, doors/map transitions.

### Farming 📐
Plots on tillable tiles; tool actions (till, plant, water, harvest). Crops are data: seasons, stages,
days per stage, regrow, yields, tags (food/medicine/ration). Kith utility waters or tills in patterns.
Growth only at the day transition. Seasonal death at season change.

### Kith 📐
See `CREATURE_BIBLE.md`. Retinue of 4, paddock for the rest. Trust and diet from food tags.

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

### Economy 📐
Base value × modifier stack. Shops sell/buy from data lists; a shipping bin sells overnight
(day transition). War tension modifies specific item tags (e.g. rations +50 %).

### Callings 📐
XP per domain from EventBus events (crop harvested, kith bonded, battle won, area discovered, item
sold, tactical victory, gift given). Level curve, small perks.

### World state & war 📐
`WorldState` holds flags/counters/tension/faction control/route status. `WorldEvent` resources are
evaluated in the daily tick. The war advances on a calendar of phases; player actions shift timing and
outcomes. Everything reads world state through `Condition`s, so there are no special cases in code.
