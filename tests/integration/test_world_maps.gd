extends TestCase
## Validates every map in the catalog: ids, spawns, exit graph, and on-foot connectivity computed
## from the real tile collision data (a "navigable blockout" check).

const CATALOG_PATH := "res://data/maps/map_catalog.tres"
const GAMEPLAY_MAPS: Array[StringName] = [&"farm", &"village", &"forest"]

var catalog: MapCatalog


func before_each() -> void:
	catalog = load(CATALOG_PATH)


func _load_map(map_id: StringName) -> WorldMap:
	var map := catalog.instantiate_map(map_id)
	add_to_root(map)
	return map


func _transitions(map: WorldMap) -> Array[MapTransition]:
	var result: Array[MapTransition] = []
	for node in map.find_children("*", "MapTransition", true, false):
		result.append(node as MapTransition)
	return result


func test_catalog_contains_the_three_areas() -> void:
	for map_id in GAMEPLAY_MAPS:
		assert_true(catalog.has_map(map_id), "%s in catalog" % map_id)
	assert_eq(catalog.get_map(&"nowhere"), null)


func test_every_catalog_entry_matches_its_scene() -> void:
	for map_id in catalog.get_ids():
		var info := catalog.get_map(map_id)
		assert_true(ResourceLoader.exists(info.scene_path), "%s scene exists" % map_id)
		assert_ne(info.display_name, "", "%s has a display name" % map_id)
		var map := _load_map(map_id)
		assert_eq(map.map_id, map_id, "scene declares the same id")
		assert_eq(map.display_name, info.display_name, "%s display names agree" % map_id)
		assert_gt(map.spawn_points.get_child_count(), 0, "%s has spawn points" % map_id)


func test_exits_lead_to_real_spawns_and_back() -> void:
	for map_id in GAMEPLAY_MAPS:
		var map := _load_map(map_id)
		var exits := _transitions(map)
		assert_gt(exits.size(), 0, "%s has exits" % map_id)
		for exit in exits:
			assert_true(catalog.has_map(exit.target_map_id), "%s → %s exists" % [map_id, exit.target_map_id])
			var target := _load_map(exit.target_map_id)
			assert_not_null(target.spawn_points.get_node_or_null(NodePath(exit.target_spawn_id)),
					"%s has spawn %s" % [exit.target_map_id, exit.target_spawn_id])
			var has_way_back := false
			for back in _transitions(target):
				if back.target_map_id == map_id:
					has_way_back = true
			assert_true(has_way_back, "%s → %s has a way back" % [map_id, exit.target_map_id])


func test_all_areas_reachable_from_the_farm() -> void:
	var seen := {&"farm": true}
	var queue: Array[StringName] = [&"farm"]
	while not queue.is_empty():
		var map := _load_map(queue.pop_front())
		for exit in _transitions(map):
			if not seen.has(exit.target_map_id):
				seen[exit.target_map_id] = true
				queue.append(exit.target_map_id)
	for map_id in GAMEPLAY_MAPS:
		assert_true(seen.has(map_id), "%s reachable from the farm" % map_id)


func test_spawns_are_not_inside_exit_triggers() -> void:
	for map_id in GAMEPLAY_MAPS:
		var map := _load_map(map_id)
		for spawn: Marker2D in map.spawn_points.get_children():
			for exit in _transitions(map):
				var shape := exit.get_node("Shape") as CollisionShape2D
				var rect := Rect2(exit.global_position - shape.shape.size / 2.0, shape.shape.size).grow(8.0)
				assert_false(rect.has_point(spawn.global_position),
						"%s spawn %s is clear of %s" % [map_id, spawn.name, exit.name])


func test_every_point_of_interest_is_reachable_on_foot() -> void:
	for map_id in GAMEPLAY_MAPS:
		var map := _load_map(map_id)
		var start := map.ground.local_to_map(map.get_spawn_position(map.spawn_points.get_child(0).name))
		var reachable := _flood(map, start)
		assert_gt(reachable.size(), 200, "%s has room to move" % map_id)
		for spawn: Marker2D in map.spawn_points.get_children():
			assert_true(reachable.has(map.ground.local_to_map(spawn.position)), "%s spawn %s reachable" % [map_id, spawn.name])
		for exit in _transitions(map):
			assert_true(reachable.has(map.ground.local_to_map(exit.position)), "%s exit %s reachable" % [map_id, exit.name])
		for node in map.entities.get_children():
			if node is Interactable:
				var cell := map.ground.local_to_map(node.position - Vector2(0, 8))
				var touched := false
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					touched = touched or reachable.has(cell + offset)
				assert_true(touched, "%s: %s can be walked up to" % [map_id, node.name])


## Cells the player can stand on: no collision on the ground (water) or obstacle layers.
func _walkable(map: WorldMap, cell: Vector2i) -> bool:
	if map.ground.get_cell_source_id(cell) == -1:
		return false
	for layer in [map.ground, map.obstacles]:
		var data := (layer as TileMapLayer).get_cell_tile_data(cell)
		if data == null:
			continue
		for physics_layer in 2:
			if data.get_collision_polygons_count(physics_layer) > 0:
				return false
	return true


func _flood(map: WorldMap, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not seen.has(next) and _walkable(map, next):
				seen[next] = true
				queue.append(next)
	return seen
