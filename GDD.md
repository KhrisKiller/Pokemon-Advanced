# MONSERA — Game Design Document

> Working title. Living document: it describes the **intended** game. What is actually built is
> tracked in `SYSTEMS.md` (status column) and `ROADMAP.md`. Last revised: Phase 1 (foundation).

## 1. Elevator pitch

A 2D top-down RPG set in a fantasy, rural-modern world where creatures called **kith** are part of
everyday life. You arrive in a quiet border valley to restore an abandoned farm. You grow crops,
bond with kith, explore forests and ruins, trade, and make friends. Slowly, a war between two
powers creeps into the valley. How far you get involved, as a farmer, trainer, merchant, explorer
or soldier, is up to you.

## 2. Pillars

| # | Pillar | Structural inspiration | What it means in MONSERA |
| - | --- | --- | --- |
| 1 | **Live a life** | Stardew Valley | Days, seasons, farm, village, relationships. The day is the heartbeat of the game. |
| 2 | **Bond with kith** | Creature-collection RPGs | Discover, bond with, raise, feed and mature creatures that are useful everywhere, not only in fights. |
| 3 | **Command in war** | Advance Wars | Grid-based tactical battles where kith are units, terrain matters and supplies come from your farm. |
| 4 | **Explore the unknown** | Top-down Zelda | Forests, caves and ruins gated by kith abilities; small hand-made puzzles and secrets. |

**Unifying rule:** every system feeds at least two others (see `SYSTEMS.md` → interaction matrix).
If a feature cannot say what it feeds and what feeds it, it is cut or redesigned.

## 3. Core fantasy

"I made a life here, and that life is worth protecting."

The player is not the chosen one. They are a newcomer who becomes part of a community. The emotional
engine of the game is **contrast**: the calm of farming and village life against the danger and loss
of war. The player cares about the valley because they have lived in it before it is threatened.

## 4. Player freedom and lifestyles

There is **no class system**. The game tracks seven **Callings** (see §9). A player's lifestyle
emerges from what they do most:

| Lifestyle | Main activities | Main Callings |
| --- | --- | --- |
| Farmer | Crops, animals, processing, cooking | Farming, Commerce |
| Trainer | Bonding, raising, battling, tournaments | Husbandry, Combat |
| Breeder | Pairing kith, diets, traits | Husbandry, Farming |
| Merchant | Buying low, selling high, processing goods, contracts | Commerce, Social |
| Explorer | Mapping, ruins, dungeons, rare kith | Exploration, Combat |
| Soldier | Tactical campaigns, military contracts | Command, Combat |
| Hybrid | Any mix | Any |

**Rules of freedom**

1. The main story never *requires* mastery of one lifestyle. Required steps have at least two routes
   (for example, supply the militia *or* fight with it; bribe the smuggler *or* find the cave route).
2. War participation is optional after the vertical slice's single introductory tactical battle.
   Staying out has consequences, but they are not a game over.
3. The game **recognizes** lifestyles: NPC dialogue, titles, letters and unique quests react to high
   Callings.

## 5. Core loops

### 5.1 Daily loop (minutes)

```
Wake up (6:00) → check mail/weather → farm chores (with kith help)
→ go out: village / explore / battle / trade → evening: social, cook, craft
→ sleep (auto-save, growth and world tick) → next day
```

Time only passes while the player is in control of the world (paused in menus and dialogue).
A day runs from 6:00 to 2:00 (about 14 real minutes at default speed). Staying up past 2:00 means
collapsing from exhaustion: you wake up at home with a small penalty.

### 5.2 Progression loop (days to seasons)

```
EXPLORE → DISCOVER KITH / RESOURCES → FARM / PRODUCE / PROCESS → TRAIN / RAISE KITH
→ TRADE / SELL / CRAFT → ADVENTURE / BATTLE → GAIN RESOURCES / KNOWLEDGE / RELATIONSHIPS
→ IMPROVE FARM / KITH / CHARACTER / COMMUNITY → UNLOCK NEW AREAS → WORLD CHANGES → repeat
```

### 5.3 War loop (seasons to years)

```
WORLD POLITICS → WAR → TACTICAL CAMPAIGNS → TERRITORY / RESOURCES / CONSEQUENCES
→ ECONOMIC AND SOCIAL CHANGES → AFFECTS THE PLAYER'S DAILY LIFE → (feeds back into politics)
```

### 5.4 How the loops touch (examples, all intended)

- Crops become **rations**, which are the **provisions** that keep tactical units fighting.
- Kith raised on the farm are the units you bring to war; wounded kith must rest at the farm.
- War tension changes **prices**, closes **routes**, changes **NPC schedules** and **dialogue**.
- Exploration unlocks **habitats** (new kith), **seeds** (new crops) and **routes** (new trade/war options).
- Kith **utility** (watering, hauling, mounts) speeds up farming and opens exploration paths.
- Relationships unlock **quests**, **shops**, **recipes** and **military allies/commanders**.

## 6. Kith (creatures)

Full design in `CREATURE_BIBLE.md`. Summary:

- **Bonding** (capture): weaken or calm a wild kith, then offer a **Bond Charm**. Offering a kith its
  preferred food raises the chance, so farming directly helps collecting.
- Each kith has **aspects** (types), stats, **traits** (abilities), **techniques** (moves), **trust**
  (friendship), a **diet**, **maturation** (evolution) paths, and utility roles.
- The same kith exists in **creature battles**, **tactical battles** and the **overworld** (farm helper,
  mount, exploration tool) through separate runtime views of the same data.
- Up to 4 kith travel with you (your **retinue**); the rest live in the farm's **paddock**.

## 7. Two combat systems

| | Creature battle | Tactical battle |
| --- | --- | --- |
| Scale | 1v1 (2v2 later) | Squads of up to ~8 units per side on a grid |
| Used for | Wild encounters, trainers, tournaments, story duels | War, skirmishes, sieges, story set pieces |
| Decisions | Technique choice, switching, items | Positioning, terrain, ranges, supply, objectives |
| Shares with the other | Kith data, aspect chart, stats (derived differently) | Same |
| Consequence | XP, trust, bonding, items | Territory, war state, wounded kith, reputation, prices |

They are **separate systems** reading the same `CreatureData` through different adapters
(`BattleCreatureState`, `TacticalUnitState`). See `TECHNICAL_DESIGN.md` §7.

## 8. War

The war does not open the game. Pacing across the full game:

1. **Peace (early spring):** rumours, newspapers, a Crown survey team at the railway.
2. **Tension:** price changes, conscription notices, refugees, soldiers in the tavern.
3. **Conflict reaches the valley:** skirmishes, occupied routes, the player is asked to choose a role.
4. **Open war:** tactical campaigns, territory changes, the valley changes visibly.
5. **Resolution:** depends on accumulated world state; several endings.

The player's involvement ranges from **none** (supply-only or neutral merchant) to **commander**.
The world moves on either way: factions advance on their own schedule, adjusted by player actions.

## 9. Callings (progression without classes)

Seven domains gain XP from matching actions: **Farming, Husbandry, Combat, Exploration, Commerce,
Command, Social**. Each level grants a small perk (stamina cost, prices, move range, and so on).
There is no cap on having several high Callings. First implementation: XP and level only, perks later.

## 10. Economy

Items have a base value. The final price is base value × a stack of modifiers (season, local supply,
region, war tension, relationship with the vendor). Players produce, process (for example, crop →
preserve), buy, sell, fulfil contracts and invest (farm buildings, shop stock). The first
implementation uses fixed prices with a seasonal modifier. The modifier stack is in place from day one.

## 11. Exploration and dungeons

- Top-down areas with **gates** opened by kith utility: haul (heavy logs, boulders), glide (gaps),
  swim (water), burrow (soft earth), light (dark caves), mount (mud or long distances).
- Dungeons are small, hand-authored and themed. Each has one mechanic, one reward that changes how you
  play, lore and optionally a guardian kith.
- The world rewards curiosity: secrets, lore fragments, rare habitats, hidden seeds.

## 12. NPCs and community

NPCs have homes, jobs, weekly schedules, personalities, gift preferences, relationship levels,
personal story arcs and optional romance (post-slice). Schedules and dialogue are data. Each NPC
schedule can be overridden by **world conditions** (season, weather, festival, war phase).

## 13. Story

- **Main story:** the war between the Aurelian Crown and the Thornwood Compact, seen from the valley.
  Neither side is purely good or evil (see `WORLD_BIBLE.md`).
- **Regional stories:** each region has its own conflict.
- **NPC stories:** relationship-driven arcs.
- **Kith lore:** creature origins, ancient bonds, the ruins.
- **Emergent consequences:** world state changes because of the player and the simulation.

## 14. Save philosophy

The game auto-saves when you sleep (like Stardew). Manual saves are also allowed at the farm or
at inns. Everything that defines the world is saved (see `TECHNICAL_DESIGN.md` §9).

## 15. Vertical slice (first major milestone)

**Goal:** 30–60 minutes that prove the four pillars work *together*. It covers about 4 in-game days.

**Content**

- 1 small village (**Brambleford**), 1 small farm (**Wrenfield**), 1 exploration area (**Whisperwood**)
  with 1 habitat (**Mirelight Pond**), 1 small dungeon (**the Sunken Kiln**, 3–5 rooms),
  1 tactical battlefield (**Brambleford Crossing**).
- 12 kith defined in data; 5–6 appear in the slice.
- 3 crops (Turnip-analog *Pipweed*, *Emberroot*, *Bluecap*), 1 cooked ration.
- 4–5 NPCs, 1 shop, basic inventory, fixed economy with seasonal modifier.
- Bonding, 1v1 creature battle, XP and levels, trust from feeding.
- 1 mount or utility interaction (**Loamox**: haul the log off the forest path; ride it across the mud).
- 1 tactical battle (defend the bridge).
- Save and load.

**Scripted path (the player can deviate between beats)**

| Day | Beat | Systems proven |
| --- | --- | --- |
| 1 | Arrive by train, meet Reeve Tamsin, receive Wrenfield. Choose a first kith at Warden Odile's. Clear and plant 6 plots. | Movement, dialogue, farming, kith |
| 1 | Visit the general store: sell forage, buy seeds. Sleep. | Economy, inventory, time, save |
| 2 | Water with your kith's help. Explore Whisperwood: battle and bond with a wild kith at Mirelight Pond. | Utility, exploration, battle, bonding |
| 2–3 | A fallen log blocks the east path. Bond with or borrow a Loamox, haul the log, ride across the mud to the Sunken Kiln. Clear the dungeon and get a reward. | Mount/utility, dungeon, progression |
| 3 | Harvest, cook rations. Crown surveyors arrive at the station: tension rises, prices change. | Farming→economy, world state |
| 4 | Militia Captain Brask asks for help: a Crown scouting column is testing the bridge. Your rations become provisions. Tactical battle at Brambleford Crossing. | Tactical, farm→war link |
| 4 | Return home. NPC dialogue reacts to the outcome. Sleep and save. End of slice. | World reaction, save |

## 16. Out of scope until after the vertical slice

Multiplayer, romance, breeding execution (data only), full economy simulation, fog of war, weather
simulation beyond flags, more than one region, voice, mobile UI, procedural content.

## 16b. Decision status (owner review after Phase 1)

**Approved:** creatures are central · food is an alternative path to bonding · no permanent kith death
· tactical movement is independent of Speed · two separate combat systems sharing creature data ·
farming, creatures, economy, exploration and warfare stay interconnected · player lifestyle stays
unrestricted.

**Provisional until validated by gameplay (don't expand the lore around them yet):** the terms kith,
bonding and Bond Charm; the names Sera, Lowmere Vale, Aurelian Crown, Thornwood Compact and the
Greying; the 6:00–2:00 day cycle and ~14 real minutes per day; the current balance formulas; the
current aspect chart; the Phase 3 crops (Pipweed, Emberroot, Bluecap), their values and growth
times, and selling at the shipping crate immediately (not overnight).

## 17. Heritage from Design.pdf

`docs/history/Design.pdf` described a Pokémon Emerald ROM hack. The approach was abandoned. These
**design ideas** survived; the implementation is new and original:

| Idea in Design.pdf | What MONSERA keeps |
| --- | --- |
| Combine creature exploration, Stardew-like farm life and grid tactics | Three of the four pillars (Zelda-like exploration was added) |
| Build a small farm prototype and a tactical prototype **before** big content | Phase order in `ROADMAP.md`; tactical risk is tested early |
| Crops grow by stages, get watered and harvested; growth by in-game days, not real hours | Farming design |
| Sleeping saves the game and advances the day; custom calendar with seasons | Time system (implemented) |
| Tactical battle as a **separate screen/system** reusing the damage/type rules | Two combat systems sharing data |
| Crops give items for combat; combat unlocks farming zones | Farm → provisions; war/exploration → new land |
| Neighbours with friendship and seasonal festivals | NPC and community systems |
| Build and test one chapter at a time; cut scope if needed | Scope control rules in `CLAUDE.md` |
| Plan save data early | Save architecture in `TECHNICAL_DESIGN.md` |
| Risk: tactical combat may be too hard; fallback is tactics only for special battles | Kept as a documented fallback |

Discarded: GBA hardware limits, the 16-colour palette rule, all Pokémon tools, code, names and assets.
