class_name MapCatalog
extends Resource
## Every map the game can travel to, looked up by id. `data/maps/map_catalog.tres`.

@export var maps: Array[MapInfo] = []


func get_map(map_id: StringName) -> MapInfo:
	for info in maps:
		if info != null and info.id == map_id:
			return info
	return null


func has_map(map_id: StringName) -> bool:
	return get_map(map_id) != null


func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for info in maps:
		if info != null:
			ids.append(info.id)
	return ids


## Instantiates the map scene for `map_id`, or null if unknown.
func instantiate_map(map_id: StringName) -> WorldMap:
	var info := get_map(map_id)
	if info == null or not ResourceLoader.exists(info.scene_path):
		return null
	return (load(info.scene_path) as PackedScene).instantiate() as WorldMap
