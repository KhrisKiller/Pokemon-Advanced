# MONSERA

*Working title.* An original 2D top-down RPG made in **Godot 4**. It combines:

- **Farming and village life:** days, seasons, crops, neighbours
- **Creature bonding:** discover, bond with and raise *kith*, creatures that help on the farm, carry you
  through the wilds and fight beside you
- **Tactical warfare:** grid battles where your kith are the units and your harvest feeds the army
- **Exploration:** forests, ruins and dungeons opened by your kith's abilities

You arrive in a quiet border valley to restore an abandoned farm. A war is coming. How you live, and
how much you fight, is up to you.

## Status

**Phase 2: player & world, complete.** Walk between the farm, the village and the forest
(placeholder blockouts), talk to two placeholder NPCs, sleep to auto-save, and continue after a
restart. An isolated tactical combat prototype lives in `spikes/tactical/`. See [ROADMAP.md](ROADMAP.md).

## Run it

```bash
tools/install_godot.sh                                    # pinned Godot 4.7.2 (Linux); or install it yourself
godot --path . --import --headless                        # first time only
godot --path .                                            # play
godot --headless --path . res://tests/test_runner.tscn    # tests
```

Controls: **WASD/arrows/left stick** move · **E/Space/gamepad A** interact and advance text ·
debug builds: **T** skip one hour, **F5** quicksave, **F9** quickload. The game continues from your
save automatically; delete `user://saves/` to start over.

Tactical spike: `godot --path . res://spikes/tactical/tactical_spike.tscn`

## Documentation

| Doc | Contents |
| --- | --- |
| [GDD.md](GDD.md) | Vision, pillars, loops, vertical slice |
| [SYSTEMS.md](SYSTEMS.md) | Every system, how they connect, real status |
| [WORLD_BIBLE.md](WORLD_BIBLE.md) | Setting, peoples, factions, places, cast |
| [CREATURE_BIBLE.md](CREATURE_BIBLE.md) | Kith design rules, aspects, roster |
| [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md) | Architecture and decisions |
| [ROADMAP.md](ROADMAP.md) | Epics → milestones → features → tasks |
| [ART_BIBLE.md](ART_BIBLE.md) | Visual rules |
| [CLAUDE.md](CLAUDE.md) | Working rules for AI-assisted development |

`docs/history/` holds the original *Design.pdf* (a superseded ROM-hack plan).
MONSERA uses no code or assets from any existing game.
