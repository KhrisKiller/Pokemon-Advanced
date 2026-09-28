# data/

Game **content** as Godot Resources (`.tres`). No gameplay code lives here.

| Folder | Content | Status |
| --- | --- | --- |
| `config/` | Tunable rules (`time_config.tres`) | in use |
| `creatures/`, `moves/`, `items/`, `crops/`, `npcs/`, `quests/`, `maps/`, `factions/`, `aspects/` | Planned content types (see `TECHNICAL_DESIGN.md` §7–8) | created by the phase that needs them |

Rules: every content resource has a stable `id` (StringName) that is used in saves and conditions.
Never reference content by file path from gameplay code; use the content registry (planned `ContentDB`).
