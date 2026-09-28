# Tactical spike — "Is grid-based creature warfare fun enough to justify the larger system?"

**Status:** isolated prototype, built in Phase 2. **Not production code.** It is waiting on a human
evaluation (see below). Nothing in `game/` references it, and it must not be promoted as-is.

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

Mouse or arrows move the cursor. **Click/Space** selects a Blue unit, then a blue tile to move to,
then a red-highlighted enemy to attack (click the unit itself to wait). **Right click/Esc**
cancels a selection, or waits after moving. **Tab** ends the turn early. **R** restarts. The panel
shows terrain, unit stats, a damage forecast while targeting, and a battle log.

## Automated probe (balance, not fun)

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

Record the answers and the decision in this README and in `ROADMAP.md`.
