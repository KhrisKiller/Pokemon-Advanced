# MONSERA — Creature Bible (Kith)

> Design canon for kith. Data schema lives in `TECHNICAL_DESIGN.md` §7; content lives in
> `data/kith/*.tres` (Phase 4: 4 species, identity/diet/helper data only — no stats yet). Numbers here
> are **starting values** to be tuned by playtesting.

## 1. Design rules for every kith

1. **Original silhouette.** Readable at 32×32 px. Don't design "real animal + element" alone: every
   kith needs a *twist* (an unusual body part, behaviour or relationship with people).
2. **A life outside combat.** Every kith has at least one non-combat role (farm, exploration, mount,
   economy, social). A kith that only fights is incomplete.
3. **A place in the world.** A habitat, a diet, a cultural meaning for at least one people.
4. **Two combat faces.** A creature-battle identity (techniques, traits) *and* a tactical role.
   They may differ: a weak duelist can be a great logistics unit.
5. **Data only.** Adding a kith means adding data + art; never gameplay code.

## 2. Aspects (types)

Six aspects in the prototype. Kith have one or two.

| Attacker ↓ / Defender → | Verdant | Tide | Ember | Stone | Gale | Spark |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| **Verdant** | ½ | **2** | ½ | **2** | ½ | 1 |
| **Tide** | ½ | ½ | **2** | **2** | 1 | 1 |
| **Ember** | **2** | ½ | ½ | ½ | **2** | 1 |
| **Stone** | 1 | 1 | **2** | 1 | ½ | **2** |
| **Gale** | **2** | 1 | 1 | ½ | 1 | ½ |
| **Spark** | ½ | **2** | 1 | 0 | **2** | ½ |

Mnemonics: roots drink water and crack stone; water quenches fire and wears stone; fire burns plants
and feeds on wind; stone smothers fire and grounds lightning; wind scatters seeds and shrugs off
rock; lightning boils water and strikes flyers, but earth absorbs it.
The chart is **data** (`data/aspects/aspect_chart.tres`), shared by both combat systems.

## 3. Stats

| Stat | Creature battle | Tactical (derived) |
| --- | --- | --- |
| **Vitality** | Max HP | Unit HP pool (shown as 10 "strength" pips like squads) |
| **Might** | Physical technique power | Attack value for melee profiles |
| **Focus** | Aspect technique power | Attack value for ranged/aspect profiles |
| **Guard** | Physical defence | Defence |
| **Will** | Aspect defence, status resistance | Morale / resistance to routing |
| **Speed** | Turn order | Initiative tiebreak only. **Movement is NOT speed**: it comes from the tactical profile. |

Growth (provisional, linear so it is easy to read and tune):
`stat = round(base × (0.5 + level / 50)) + potential + training`, and
`vitality = round(base × (1 + level / 25)) + 10 + potential + training`.
Levels go from 1 to 50. *Potential* is a 0–10 hidden per-individual value (breeding axis). *Training*
(0–20 per stat, 60 total) comes from activities and food. Formulas are in one place (`game/creatures/stat_formulas.gd`, Phase 4) and tested.

## 4. Techniques (moves), traits (abilities), status

- **Techniques:** data resources with aspect, category (physical/aspect/support), power, accuracy, uses
  (recharged by sleeping — ties into the day loop), effects list. A kith knows up to 4.
- **Traits:** passive rules (e.g. *Deep Roots*: heals 1/16 per turn when Rooted). One per kith.
- **Status effects (prototype set of 5):**

| Status | Effect (battle) | Tactical equivalent |
| --- | --- | --- |
| Scorched | Loses 1/16 HP per turn, Might −25 % | Loses 1 strength per turn |
| Soaked | Speed −25 %, Spark damage taken ×1.5 | Movement −1 |
| Rooted | Cannot switch out | Cannot move (can attack) |
| Jolted | 25 % chance to lose the turn | Cannot counterattack |
| Drowsy | Falls asleep after next turn unless switched | Skips next action |

## 5. Bonding (capture)

- Wild kith appear in **habitats** (tall grass, water, caves, ruins) based on season/time/weather tables.
- A bond attempt uses a **Bond Charm**. Chance = f(species bond rate, HP missing, status, **calm**).
- **Calm** rises when you offer food the kith likes before/during the encounter. So farming feeds
  collecting, and a pacifist can bond many kith without fighting.
- Some kith (guardians, story kith) only bond through quests or high trust.
- **Phase 4 prototype (no battles yet):** a wild kith stands in the map. Offering food it eats adds
  calm (favourite +2, liked +1); at its species' `bond_calm_needed` it accepts a Bond Charm and joins
  the party with Trust 10. Each wild spot bonds once. The battle phase replaces "always succeeds"
  with the chance formula above; calm keeps its meaning.

## 6. Trust, food and diet

- **Trust** 0–100 (provisional, Phase 4; was 0–255 with hearts), shown as a number and a label:
  0–24 *Unfamiliar*, 25–49 *Friendly*, 50–74 *Trusted*, 75–100 *Bonded*. Raised by feeding preferred
  food (Phase 4: favourite +8, liked +3, one meal per day), later also by working together, winning
  and grooming; lowered by fainting, overwork, forced labour, hunger (not implemented).
- Helpers need Trust: a kith only does farm work once *Friendly* (Phase 4: watering at Trust ≥ 25).
- **Diet** per species: `favourite` food tags (e.g. *root*, *berry*, *fish*, *mineral*), `tolerated`,
  `disliked`. Food items carry tags, so new foods need no code. Phase 4 has favourite and liked
  (= tolerated) tags; anything else is refused and not consumed. Current food tags: `food` (any
  edible), `root`, `spicy`, `fungus`.
- Food effects (kept simple): trust, small permanent training points, or a temporary *prepared* buff
  (one per day) usable in the next battle or tactical deployment.
- **No starvation.** Unfed kith lose trust slowly and work less; they never die.

## 7. Maturation (evolution)

Kith mature into a new form when conditions are met. Conditions are data (`EvolutionRule` list):
level, trust threshold, item, food eaten count, season, location, time of day. The player can delay
maturation (some keep a smaller form to keep its utility or mount type).

## 8. Breeding (post-slice; data from day one)

Data fields exist from Phase 4: `breeding_group`, `egg_cycles`, inheritable potential and traits.
Implementation is post-slice.

## 9. Utility and mounts

| Utility | Overworld effect | Gate it opens |
| --- | --- | --- |
| **Water** | Waters growing plots each morning (Phase 4: up to 3 per day, Trust ≥ 25) | — (farm speed) |
| **Till** | Tills soil | — (farm speed) |
| **Haul** | Moves heavy logs/boulders; carries extra goods | Blocked paths |
| **Burrow** | Digs through soft earth | Tunnels, buried items |
| **Glide** | Crosses gaps from ledges | Cliffs, gaps |
| **Swim** | Crosses water (mount) | Rivers, lakes |
| **Light** | Lights dark areas | Caves |
| **Forage** | Finds extra items when exploring | — (economy) |

**Mount types:** LAND (faster, crosses mud), WATER (swim), AIR (glide, later fly), BURROW (travel
underground between burrow points). Mount = changes the player's movement class and collision masks
(water is its own physics layer for this reason — see `TECHNICAL_DESIGN.md`).

## 10. Tactical roles

Original role set (not a copy of any unit roster). A kith's role comes from its data, not its species name.

| Role | Identity | Typical profile |
| --- | --- | --- |
| **Vanguard** | Holds the line, zone control | Move 3, melee, high Guard, *Brace* (no counter damage when defending on fortified terrain) |
| **Skirmisher** | Hit and fade | Move 5, melee, can move after attacking (1 tile) |
| **Scout** | Vision and capture of objectives | Move 6, weak attack, reveals ambushes, captures faster |
| **Artillery** | Indirect fire | Move 3, range 2–3, cannot move and fire in same turn, no counterattack |
| **Aerial** | Ignores terrain, fragile | Move 5, flying movement class, vulnerable to Spark and to *Archer* traits |
| **Support** | Logistics | Move 4, resupplies provisions and heals 1 strength to adjacent allies |
| **Engineer** | Changes the map | Move 3, builds earthworks (+defence), bridges fords, clears obstacles |

**Movement classes:** foot, heavy, aerial, amphibious, burrow. Terrain cost tables are data per class.
**Terrain affinity:** per-kith bonus on specific terrain (e.g. Tide kith +1 move in fords).
**Provisions:** each unit starts a battle with provisions (from rations the player brings). Moving and
attacking consume them; at 0 the unit is *Hungry* (−move, −attack). Support kith resupply.

## 11. Prototype roster (12 kith)

Status: **design only**, except Sprigmole, Rillet, Cindercoot and Bramblehog, which have Phase 4
data files (identity, diet, helper ability, placeholder sprite; no stats). ✦ = planned to appear in
the vertical slice.

| Phase 4 data | Loves | Also eats | Helper | Calm needed | Found |
| --- | --- | --- | --- | --- | --- |
| Sprigmole | root | — | — (till later) | 2 | Wrenfield farm |
| Rillet | fungus | any food | water | 2 | Mirelight Pond |
| Cindercoot | spicy | — | — | 2 | Whisperwood, south bridge |
| Bramblehog | — | any food | — | 1 | Whisperwood clearing |

| # | Name | Aspects | Concept (the twist) | Non-combat role | Mount | Tactical role | Matures |
| - | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Sprigmole** ✦ | Verdant / Stone | Blind mole carrying a living sapling that "sees" by sensing roots | Till | — | Engineer | → Grovemole (lv 16) |
| 2 | **Grovemole** | Verdant / Stone | Its sapling became a small tree; birds nest in it and warn it of danger | Till (3×3), Forage | — | Engineer | — |
| 3 | **Rillet** ✦ | Tide | Otter-like; stores water in a bladder-tail and sprays it; hoards shiny pebbles | Water | — | Support | → Rillhound (trust 4♥ + lv 14) |
| 4 | **Rillhound** | Tide | Grown Rillet; webbed, sleek, pulls small boats in Brinari ports | Water (3×3), Swim | WATER | Support | — |
| 5 | **Cindercoot** ✦ | Ember / Gale | Marsh bird whose crest smoulders; used by Cindral to roast grain and light kilns | Light, processing boost (roasting) | — | Skirmisher | — |
| 6 | **Bramblehog** ✦ | Verdant | Hedgehog whose spines are living bramble that fruits in summer (drops berries) | Forage, farm guard (no pests) | — | Vanguard | — |
| 7 | **Loamox** ✦ | Stone | Patient ox whose back grows moss-covered stone plates; Rootkin say it carries hills | Haul, Till | LAND | Vanguard (heavy) | — |
| 8 | **Skirl** ✦ | Gale | Kite-shaped gliding lizard that rides thermals and "sings" before storms | Glide, weather forecast (mail) | AIR (glide) | Aerial scout | — |
| 9 | **Arcbeet** | Spark / Stone | Beetle storing charge in a quartz shell; Crown factories farm them | Powers machines (sprinkler post-slice) | — | Artillery | — |
| 10 | **Delvern** | Stone | Blind burrowing eel-serpent that "swims" through soft earth; used by Cindral miners | Burrow, mining | BURROW | Engineer / sapper | — |
| 11 | **Kindlewool** | Ember | Sheep whose wool is warm to the touch; sheared wool sells and warms soldiers in winter | Animal product (wool) | — | Support (logistics) | — |
| 12 | **Obelith** | Stone / Spark | A Kilnwright stone guardian that woke up; a monolith with a glowing core | Story (Sunken Kiln guardian) | — | Vanguard (fortress) | — |

**Starter choice (slice):** Sprigmole, Rillet or Cindercoot from Warden Odile. Each supports a different
early playstyle (till/engineer, water/support, light/skirmisher).

### Per-kith detail template (fill in when the data file is created)

```
Name / id / aspects / size class (S, M, L)
Look: silhouette, palette (see ART_BIBLE), animation personality
Behaviour: wild behaviour, habitat, time/season, rarity
Culture: what each people thinks of it
Diet: favourite tags / tolerated / disliked
Base stats: VIT / MIG / FOC / GUA / WIL / SPD (sum ≈ 300 basic, ≈ 420 mature, ≈ 500 guardian)
Traits: 1 (+1 hidden)
Techniques: learnset by level + teachable tags
Utility: list; mount type
Tactical: role, move class, move, range, terrain affinities
Maturation: rules
Breeding: group, egg cycles
```
