# Tactical spike

**v0.1 (Phase 2):** "Is grid-based creature warfare fun enough to justify the larger system?"
**v0.2 (Phase 3):** "Does positioning and objective control create a genuinely interesting tactical
decision loop?"

**Status:** isolated prototype. **Not production code.** It is waiting on a human evaluation (see
below). Nothing in `game/` references it, and it must not be promoted as-is.

## v0.2 — what changed

| Asked for | In v0.2 |
| --- | --- |
| 3 vs 3 on 10×8 | Three scenarios, each 3v3 on a 10×8 map |
| Terrain, defence, counterattacks | As v0.1 (forest/hill cover, ford exposure, water blocks foot units, counters) |
| 2+ distinct roles | Vanguard (Bulwark, Brute), flyer (Skimmer), artillery (Slinger), skirmisher (Raider, move 5), VIP (Courier) |
| Hold objective | **Hold the crossing**: survive 8 turns; lose if Red ends a turn on the gold tile |
| Rout objective | **Rout** (mirrored armies, open field with cover): rout Red within 12 turns |
| Reach/Protect objective | **Escort the Courier**: get the Courier to a green exit within 10 turns; lose if it falls |
| 6–10 turn battles | Damage scale lowered to 1.0 for v0.2 scenarios. Competent play lasts 8–12 turns (see table) |

Only two rules were added, both aimed squarely at the question:
- **Zone of control (ZOC):** a ground unit that steps next to an enemy must stop; flyers ignore it.
  Toggle per scenario (`"zoc"`), so its effect can be measured.
- **Danger zone:** `threat_map()` shows which cells enemies can hit next turn and by how many. Press
  **V** in the view to see it. The AI uses it too.

v0.1 is kept as scenario `v01` (the default, unchanged) and its 18 tests still pass. Keys **1–4**
switch scenario in the view.

## v0.2 — results (100 games per Blue policy; Red = greedy AI with 10 % random moves)

`simulate.tscn` bots: **greedy** (best trade, else advance), **noisy** (greedy + 25 % random moves),
**cautious** (reads the danger zone: avoids ending in enemy reach unless the trade is good),
**anchor** (Hold: the nearest ground unit parks on the objective; others play greedy),
**terrain-blind** (ignores cover), **objective-blind** (plays every scenario as a rout).

| Scenario | random | greedy | noisy | cautious | anchor | terrain-blind | objective-blind | noisy, ZOC off |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Hold (3v3) | 0 % | 10 % | 17 % | 1 % | **78 %** | 16 % | 42 % | 7 % |
| Rout (mirror) | 0 % | 8 % | 7 % | **25 %** | 7 % | 10 % | 8 % | 9 % |
| Escort | 0 % | **51 %** | 27 % | 39 % | 47 % | 42 % | **0 %** | 40 % |

| Scenario | Battle length, median turns (competent policy) | Choices per activation |
| --- | --- | --: |
| Hold | 8 (anchor) | 24–26 |
| Rout | 12 (cautious), 9 (greedy) | 18–24 |
| Escort | 10 (greedy) | 20–24 |

### What the data says about the question

**Yes: the objective, not the fight, decides who wins, and the decisive choices are positional.**
1. *Objectives change what good play is.* In Escort, the same fighting AI wins 51 % when it plays for
   the Courier and **0 %** when it ignores the objective. In Hold, simply occupying the tile (anchor)
   wins 78 %, against 10 % for fighting well and ignoring position.
2. *Position beats aggression when the objective demands it.* In Rout the cautious bot (danger-zone
   aware) triples the greedy bot's win rate and makes battles last the full 12 turns.
3. *ZOC is a real lever.* It more than doubles Blue's Hold wins (17 % vs 7 %) and helps the
   defender in Escort (27 % with, 40 % without). One small movement rule noticeably changes who
   controls space.
4. *Decisions stay rich:* about 18–26 legal choices per unit activation, 3 units a side.
5. *Skill matters:* random play never wins any scenario.

**Problems found (design lessons for production):**
- **Rout with a timer favours the side that waits.** Even with mirrored armies, whoever has to advance
  first walks into range and loses (8–25 % for Blue). Production rout battles need a reason for both
  sides to engage (objectives, reinforcements, supply pressure), or no attacker deadline.
- **Single-tile holds invite "park and pray".** Occupying the tile is the dominant strategy. It isn't
  unbeatable (Red breaks the anchor in 22 %), but multi-tile or capture-progress zones would add
  depth.
- **Harsh for beginners:** 0 % for random play everywhere, and small mistakes are costly (Escort
  51 % → 27 % with 25 % noise). Production needs the forecast, the danger zone, and possibly undo.
- **Bots are weak proxies:** they know none of the strategies above unless coded in. **Whether it's
  fun still needs a human playtest** (protocol below).

**Recommendation:** positioning and objective control *do* create a meaningful decision loop in this
spike. Keep for production: objectives first (Hold, Escort-style reach/protect), ZOC, the danger-zone
view, terrain cover, 3–4 units a side, small maps. Rework before production: pure-rout battles and
single-tile holds.

---

# v0.1 notes (Phase 2)

## What it contains (and only this)

| Required element | In the spike |
| --- | --- |
| Small grid | 10×8 cells, 32 px each |
| 2–4 units | 2 Blue (player) vs 2 Red (AI). Placeholder archetypes, not kith: **Bulwark** (heavy, tanky), **Skimmer** (flying, fast, fragile), **Brute** (strong melee), **Slinger** (range 2–3, can't move and fire, no counter) |
| Movement | Dijkstra over per-movement-class terrain costs. Enemies block; allies can be passed through |
| Basic attack | Deterministic damage scaled by the attacker's remaining HP, minus defence, reduced by terrain; adjacent melee defenders counterattack |
| Terrain modifier | Forest +25 %, hill +35 %, ford −15 % defence. Forest/hill/ford cost more to cross. Deep water blocks foot units. Flyers ignore costs **and** cover |
| One objective | **Hold the crossing**: keep Red off the gold tile west of the bridge |
| Victory / defeat | Victory: survive 8 turns or rout Red. Defeat: a Red unit ends its turn on the objective, or Blue is routed |

Not included, on purpose: art, campaign, economy, story, progression, kith data, commanders,
provisions, fog of war.

## Isolation rules

- Everything lives in `spikes/tactical/`. **No `class_name`** (nothing enters the game's global
  class list), no autoloads, no project input actions (it reads raw keys and mouse), no shared scenes.
- Its tests run only when asked for:
  `godot --headless --path . res://tests/test_runner.tscn -- --dir=res://spikes/tactical/tests`
  (it reuses the generic `TestCase` harness). CI runs them as a separate step.
- If the spike is approved, the production tactical system will be **rewritten** in `game/tactical/`
  to the architecture in `TECHNICAL_DESIGN.md` §7–8 (`TacticalUnitState` from `CreatureData`, data-driven
  terrain). Nothing is copied over.
- When exporting builds, exclude `spikes/*` (there are no export presets yet).

## How to play

```bash
godot --path . res://spikes/tactical/tactical_spike.tscn
```

v0.2 adds: **1–4** choose the scenario (v0.1 baseline, Hold, Rout, Escort), **V** toggles Red's
danger zone (numbers = how many Red units can hit that cell). The Courier has a gold ring; exits are
green.

Mouse or arrows move the cursor. **Click/Space** selects a Blue unit, then a blue tile to move to,
then a red-highlighted enemy to attack (click the unit itself to wait). **Right click/Esc**
cancels a selection, or waits after moving. **Tab** ends the turn early. **R** restarts. The panel
shows terrain, unit stats, a damage forecast while targeting, and a battle log.

## Automated probe (v0.1 numbers; see the v0.2 section above for the current probe)

`godot --headless --path . res://spikes/tactical/simulate.tscn` plays Blue with different policies
against the Red AI (damage scale 1.5):

| Blue policy | Games | Win % | Avg. turns | Wins by rout | Choices per activation |
| --- | --: | --: | --: | --: | --: |
| Passive (never acts) | 1 | 0 % | 3.0 | 0 | 32 |
| Random legal moves | 200 | 0 % | 2.5 | 1 | 29 |
| Greedy (same AI as Red) | 1 | 100 % | 4.0 | 1 | 22 |
| Greedy + 25 % random mistakes | 200 | 62 % | 4.0 | 124 | 23 |

What this shows:

1. **Decisions matter a lot.** Random play never wins; competent play always does; a few mistakes
   drop the win rate to 62 %. The scenario is skill-driven rather than luck-driven (there is no RNG).
2. **Each activation has 20–30 real choices** (move, and target from there), so the player has room to
   think.
3. **Battles are short**, about 4 turns, and mostly end in a rout. The 8-turn "hold" condition rarely
   decides the game. With 2v2 a single bad trade often decides it. A 3v3 variant or more HP
   granularity is the obvious next test.
4. **Tuning note:** the first version (damage scale 2.0) let the Brute one-shot the Skimmer (11 damage
   against 10 HP). That felt arbitrary in a scripted playthrough, so it was lowered to 1.5.

## Evaluation protocol (for the owner, about 15 minutes)

Play at least 3 battles, then answer:

1. Did you think about **where** to move, not just **whom** to hit? (terrain, bridge chokepoint, flyer over water)
2. Did counterattacks and the damage forecast make trades feel readable?
3. Did the Skimmer (fragile flyer) feel like a distinct role worth protecting?
4. Was any loss surprising or unfair? Was any win too easy?
5. Would you want to play a longer version (3–4 units, 12×10 map)?
6. **Verdict:** proceed with the production tactical system / iterate the spike / cut back to
   "tactics only for special battles" (the fallback from `GDD.md` §17).

v0.2 additions:
7. Hold: did you find a way to protect the tile holder? Did the ford route matter?
8. Escort: did you route the Courier over the bridge or through the ford, and why?
9. Rout: did it feel like a stand-off? Who had to commit first?
10. Did the danger zone (V) change your moves?

Record the answers and the decision in this README and in `ROADMAP.md`.
