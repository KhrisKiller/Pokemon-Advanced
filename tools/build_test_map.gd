extends Node
## Builds the placeholder TileSet and the Phase 1 test map scene from an ASCII layout.
## Run (after generate_placeholder_art.gd + --import):
##   godot --headless --path . res://tools/build_test_map.tscn
## (Runs as a scene, not with --script, so autoloads such as EventBus exist while props load.)
##
## The generated files are normal Godot resources and can be edited in the editor afterwards.
## This tool is a bootstrap for the placeholder map only; real maps are painted in the editor.

const TILES_TEXTURE := "res://assets/placeholder/tiles.png"
const TILESET_PATH := "res://game/world/tilesets/placeholder_tileset.tres"
const MAP_PATH := "res://game/world/maps/test_map.tscn"
const WORLD_MAP_SCRIPT := "res://game/world/world_map.gd"
const SIGN_SCENE := "res://game/world/props/sign.tscn"
const CRATE_SCENE := "res://game/world/props/crate.tscn"
const BED_SCENE := "res://game/world/props/bed.tscn"
const T := 16

## Atlas x-coordinates. Keep in sync with TILE_NAMES in generate_placeholder_art.gd.
enum Tile { GRASS, GRASS_ALT, PATH, TILLED, WATER, FLOOR, FLOWERS, WALL, FENCE, TREE, ROCK }

const PHYSICS_WORLD := 0  # TileSet physics layer index → collision layer 1 (world)
const PHYSICS_WATER := 1  # TileSet physics layer index → collision layer 5 (water)

## Legend: ground tile, obstacle tile (-1 = none), entity marker.
const LEGEND := {
	".": [Tile.GRASS, -1], ",": [Tile.GRASS_ALT, -1], ":": [Tile.FLOWERS, -1],
	"=": [Tile.PATH, -1], "~": [Tile.WATER, -1], "_": [Tile.FLOOR, -1], "t": [Tile.TILLED, -1],
	"#": [Tile.FLOOR, Tile.WALL], "f": [Tile.GRASS, Tile.FENCE], "T": [Tile.GRASS, Tile.TREE],
	"o": [Tile.GRASS, Tile.ROCK],
	"P": [Tile.FLOOR, -1], "B": [Tile.FLOOR, -1], "S": [Tile.GRASS, -1], "C": [Tile.GRASS, -1],
}

const LAYOUT := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"T..............................................T",
	"T..................,...........................T",
	"T...##########............:...........o.....T..T",
	"T.T.#________#......T.........~~~~~~~~...o.....T",
	"T...#_B______#.............o.~~~~~~~~~~........T",
	"T...#________#..............~~~~~~~~~~~~.......T",
	"T...#____P___#........T.....~~~~~~~~~~~~o......T",
	"T...#________#C..............~~~~~~~~~~......T.T",
	"T...####__####...........,....~~~~~~~~.........T",
	"T.......==...................o.................T",
	"T.T...,.==.S...:..T............................T",
	"T.......==......:...,...:..................T...T",
	"T....:..==........................,............T",
	"T.......=================================......T",
	"T..,....=================================......T",
	"T......................................==......T",
	"T......:....:..................:.......==.:....T",
	"T.........,.....fffff..fffff........:..==......T",
	"T...............fttttttttttf...........==......T",
	"T.T...........,.fttttttttttf..T........==...T..T",
	"T.........T.....fttttttttttf...........==......T",
	"T...T...........fttttttttttf.......T...==,.....T",
	"T...............fttttttttttf...........==......T",
	"T......T........fttttttttttf.,.........==....T.T",
	"T..T............fttttttttttf...........==......T",
	"T...........T...ffffffffffff.....T.....==......T",
	"T.....T..............................,.==......T",
	"T......................................==......T",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const SIGN_LINES := [
	"WRENFIELD — test grounds.",
	"Walk with WASD, the arrow keys or a gamepad. Press E (or Space) to interact.",
	"The bed in the house ends the day. Stay up past 2 AM and you'll collapse.",
]
const CRATE_LINES := [
	"An old crate stamped with the seal of the Aurel–Saltwhistle Railway.",
	"It's empty. Whoever lived here left in a hurry.",
]


func _ready() -> void:
	var tileset := _build_tileset()
	var err := ResourceSaver.save(tileset, TILESET_PATH, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("Could not save tileset: %s" % error_string(err))
		get_tree().quit(1)
		return
	var scene := _build_map(load(TILESET_PATH))
	err = ResourceSaver.save(scene, MAP_PATH)
	if err != OK:
		push_error("Could not save map: %s" % error_string(err))
		get_tree().quit(1)
		return
	print("Wrote %s and %s" % [TILESET_PATH, MAP_PATH])
	get_tree().quit()


func _build_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(PHYSICS_WORLD, 1)
	tileset.set_physics_layer_collision_mask(PHYSICS_WORLD, 0)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(PHYSICS_WATER, 1 << 4)
	tileset.set_physics_layer_collision_mask(PHYSICS_WATER, 0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(TILES_TEXTURE)
	atlas.texture_region_size = Vector2i(T, T)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var trunk := PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(5, 8), Vector2(-5, 8)])
	var boulder := PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(6, 6), Vector2(-6, 6)])
	for tile in Tile.values():
		var coords := Vector2i(tile, 0)
		atlas.create_tile(coords)
	tileset.add_source(atlas, 0)

	for tile in Tile.values():
		var data := atlas.get_tile_data(Vector2i(tile, 0), 0)
		match tile:
			Tile.WATER:
				_add_collision(data, PHYSICS_WATER, full)
			Tile.WALL, Tile.FENCE:
				_add_collision(data, PHYSICS_WORLD, full)
				data.y_sort_origin = 8
			Tile.TREE:
				_add_collision(data, PHYSICS_WORLD, trunk)
				data.y_sort_origin = 8
			Tile.ROCK:
				_add_collision(data, PHYSICS_WORLD, boulder)
				data.y_sort_origin = 6
	return tileset


func _add_collision(data: TileData, layer: int, points: PackedVector2Array) -> void:
	data.add_collision_polygon(layer)
	data.set_collision_polygon_points(layer, 0, points)


func _build_map(tileset: TileSet) -> PackedScene:
	var root := Node2D.new()
	root.name = "TestMap"
	root.y_sort_enabled = true
	root.set_script(load(WORLD_MAP_SCRIPT))
	root.set("map_id", &"test_map")
	root.set("display_name", "Wrenfield (test grounds)")

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	ground.z_index = -1
	_add(root, ground, root)

	var obstacles := TileMapLayer.new()
	obstacles.name = "Obstacles"
	obstacles.tile_set = tileset
	obstacles.y_sort_enabled = true
	_add(root, obstacles, root)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	_add(root, entities, root)

	var spawns := Node2D.new()
	spawns.name = "SpawnPoints"
	_add(root, spawns, root)

	for y in LAYOUT.size():
		var row: String = LAYOUT[y]
		for x in row.length():
			var key := row[x]
			var entry: Array = LEGEND[key]
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i(entry[0], 0))
			if entry[1] >= 0:
				obstacles.set_cell(cell, 0, Vector2i(entry[1], 0))
			var base := Vector2(x * T + T / 2.0, (y + 1) * T)  # bottom-centre of the cell
			match key:
				"P":
					var marker := Marker2D.new()
					marker.name = "Default"
					marker.position = base - Vector2(0, 2)
					_add(spawns, marker, root)
				"B":
					_add(entities, _instance(BED_SCENE, "Bed", base), root)
				"S":
					var sign := _instance(SIGN_SCENE, "WelcomeSign", base)
					sign.set("lines", PackedStringArray(SIGN_LINES))
					_add(entities, sign, root)
				"C":
					var crate := _instance(CRATE_SCENE, "RailwayCrate", base)
					crate.set("lines", PackedStringArray(CRATE_LINES))
					_add(entities, crate, root)

	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _instance(path: String, node_name: String, pos: Vector2) -> Node2D:
	var node: Node2D = load(path).instantiate()
	node.name = node_name
	node.position = pos
	return node


func _add(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node
