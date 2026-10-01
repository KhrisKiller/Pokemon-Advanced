class_name NewGameConfig
extends Resource
## What a new game starts with (data/config/new_game.tres). Also applied when loading an older
## save that has no player_state section yet.

@export_range(0, 1000000) var starting_money: int = 0
## item id (String) → quantity
@export var starting_items: Dictionary = {}
@export_range(1, 99) var inventory_slots: int = 24
## Items granted once when an older save is loaded, keyed by the player_state section version that
## introduced them: {"2": {"bond_charm": 3}} gives a pre-Phase-4 save (version 1) what a new game
## would have started with. String keys (version) → {item id (String) → quantity}.
@export var upgrade_grants: Dictionary = {}
