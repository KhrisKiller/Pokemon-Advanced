class_name MapInfo
extends Resource
## Data describing one overworld map. Lives in data/maps/<id>.tres and is listed in the MapCatalog.

@export var id: StringName = &""
@export var display_name: String = ""
## Path (not a PackedScene) so the catalog doesn't load every map up front.
@export_file("*.tscn") var scene_path: String = ""
## Region grouping for later (music, weather, world simulation).
@export var region: StringName = &""
