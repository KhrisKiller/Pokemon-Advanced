class_name WorldMap
extends Node2D
## Base script for every overworld map.
##
## Expected children:
## - `Ground` (TileMapLayer): walkable floor, water (water tiles collide on the `water` layer)
## - `Obstacles` (TileMapLayer): walls, fences, trees, rocks (collide on the `world` layer)
## - `Entities` (Node2D, y-sorted): props, NPCs and the player
## - `SpawnPoints` (Node2D) with Marker2D children named by spawn id (e.g. `Default`)

@export var map_id: StringName = &""
@export var display_name: String = ""

@onready var ground: TileMapLayer = $Ground
@onready var obstacles: TileMapLayer = $Obstacles
@onready var entities: Node2D = $Entities
@onready var spawn_points: Node2D = $SpawnPoints


func get_spawn_position(spawn_id: StringName = &"Default") -> Vector2:
	var marker := spawn_points.get_node_or_null(NodePath(spawn_id)) as Marker2D
	if marker == null:
		push_warning("Map %s has no spawn point '%s'; using the first one." % [map_id, spawn_id])
		marker = spawn_points.get_child(0) as Marker2D
	return marker.global_position


func add_entity(node: Node2D) -> void:
	entities.add_child(node)


## The map's area in world pixels (union of both tile layers).
func get_bounds() -> Rect2:
	var cells := ground.get_used_rect().merge(obstacles.get_used_rect())
	var tile_size := Vector2(ground.tile_set.tile_size)
	return Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)


## Keeps the camera inside the map. If the map is smaller than the view, the camera limits
## still hold the map's edges, so Godot centres on them.
func apply_camera_limits(camera: Camera2D) -> void:
	var bounds := get_bounds()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
