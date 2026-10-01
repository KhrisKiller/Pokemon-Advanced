extends Node
## Builds the placeholder TileSet and every blockout map scene from ASCII layouts.
## Run (after generate_placeholder_art.gd + --import):
##   godot --headless --path . res://tools/build_maps.tscn
## (Runs as a scene, not with --script, so autoloads such as EventBus exist while props load.)
##
## Inputs:  tools/maps/<map_id>.txt (one character per 16 px cell) + the MAPS config below.
## Outputs: game/world/tilesets/placeholder_tileset.tres, game/world/maps/<map_id>.tscn
## The outputs are normal Godot resources and can be edited in the editor afterwards, but
## re-running this tool overwrites them: while maps are blockouts, edit the .txt layouts.

const TILES_TEXTURE := "res://assets/placeholder/tiles.png"
const TILESET_PATH := "res://game/world/tilesets/placeholder_tileset.tres"
const LAYOUT_DIR := "res://tools/maps"
const MAP_DIR := "res://game/world/maps"
const WORLD_MAP_SCRIPT := "res://game/world/world_map.gd"
const MAP_TRANSITION_SCRIPT := "res://game/world/map_transition.gd"
const SIGN_SCENE := "res://game/world/props/sign.tscn"
const CRATE_SCENE := "res://game/world/props/crate.tscn"
const BED_SCENE := "res://game/world/props/bed.tscn"
const NPC_SCENE := "res://game/characters/npc/npc.tscn"
const FARM_PLOT_SCENE := "res://game/farming/farm_plot.tscn"
const WILD_KITH_SCENE := "res://game/kith/world/wild_kith.tscn"
const SHIPPING_CRATE_SCENE := "res://game/economy/shipping_crate.tscn"
const T := 16

## Atlas x-coordinates. Keep in sync with TILE_NAMES in generate_placeholder_art.gd (append only).
enum Tile {
	GRASS, GRASS_ALT, PATH, TILLED, WATER, FLOOR, FLOWERS, WALL, FENCE, TREE, ROCK,
	COBBLE, TALL_GRASS, MUD, BRIDGE, RAIL, ROOF, LOG,
	SOIL,
}

const PHYSICS_WORLD := 0  # TileSet physics layer index → collision layer 1 (world)
const PHYSICS_WATER := 1  # TileSet physics layer index → collision layer 5 (water)

## Terrain legend shared by all maps: character → [ground tile, obstacle tile or -1].
const TERRAIN := {
	".": [Tile.GRASS, -1], ",": [Tile.GRASS_ALT, -1], ":": [Tile.FLOWERS, -1],
	"=": [Tile.PATH, -1], "~": [Tile.WATER, -1], "_": [Tile.FLOOR, -1], "t": [Tile.TILLED, -1],
	"c": [Tile.COBBLE, -1], "g": [Tile.TALL_GRASS, -1], "m": [Tile.MUD, -1],
	"b": [Tile.BRIDGE, -1], "r": [Tile.RAIL, -1], "s": [Tile.SOIL, -1],
	"#": [Tile.FLOOR, Tile.WALL], "f": [Tile.GRASS, Tile.FENCE], "T": [Tile.GRASS, Tile.TREE],
	"o": [Tile.GRASS, Tile.ROCK], "R": [Tile.GRASS, Tile.ROOF], "L": [Tile.GRASS, Tile.LOG],
}

## Per-map config. Marker characters (anything not in TERRAIN) must be listed in `markers`:
##   {type: "spawn", name, ground}             Marker2D in SpawnPoints
##   {type: "exit", target, spawn, ground}      MapTransition covering all cells with that char
##   {type: "prop", scene, name, ground, lines?}
##   {type: "sign", ground}                     next entry of `signs` (row-major order)
##   {type: "npc", data, name, ground}          Npc scene with the NpcData resource at `data`
##   {type: "plot", ground}                     FarmPlot with plot_id "<map_id>:<x>,<y>"
##   {type: "wild_kith", kith, ground}          WildKith of species `kith`, spawn_id "<map_id>:<x>,<y>"
##   {type: "ground", ground}                   plain ground (reserved for a later phase)
const MAPS := {
	"test_map": {
		"display_name": "Wrenfield (test grounds)",
		"markers": {
			"P": {"type": "spawn", "name": "Default", "ground": "_"},
			"B": {"type": "prop", "scene": BED_SCENE, "name": "Bed", "ground": "_"},
			"S": {"type": "sign", "ground": "."},
			"C": {"type": "prop", "scene": CRATE_SCENE, "name": "RailwayCrate", "ground": ".", "lines": [
				"An old crate stamped with the seal of the Aurel–Saltwhistle Railway.",
				"It's empty. Whoever lived here left in a hurry.",
			]},
		},
		"signs": [
			{"name": "WelcomeSign", "lines": [
				"WRENFIELD — test grounds.",
				"Walk with WASD, the arrow keys or a gamepad. Press E (or Space) to interact.",
				"The bed in the house ends the day. Stay up past 2 AM and you'll collapse.",
			]},
		],
	},
	"farm": {
		"display_name": "Wrenfield",
		"markers": {
			"P": {"type": "spawn", "name": "Default", "ground": "_"},
			"1": {"type": "spawn", "name": "from_village", "ground": "="},
			"2": {"type": "spawn", "name": "from_forest", "ground": "="},
			"<": {"type": "exit", "target": "village", "spawn": "from_farm", "ground": "="},
			">": {"type": "exit", "target": "forest", "spawn": "from_farm", "ground": "="},
			"B": {"type": "prop", "scene": BED_SCENE, "name": "Bed", "ground": "_"},
			"C": {"type": "prop", "scene": CRATE_SCENE, "name": "RailwayCrate", "ground": ".", "lines": [
				"An old crate stamped with the seal of the Aurel–Saltwhistle Railway.",
				"It's empty. Whoever lived here left in a hurry.",
			]},
			"S": {"type": "sign", "ground": "."},
			"p": {"type": "plot", "ground": "s"},
			"X": {"type": "prop", "scene": SHIPPING_CRATE_SCENE, "name": "ShippingCrate", "ground": "."},
			"7": {"type": "wild_kith", "kith": "sprigmole", "ground": "."},
		},
		"signs": [
			{"name": "FarmSign", "lines": ["WRENFIELD", "The soil in the fenced field is yours to work: till, plant, water, and sleep.", "Sell your harvest at the green crate by the house."]},
			{"name": "WestSignpost", "lines": ["← Brambleford"]},
			{"name": "EastSignpost", "lines": ["Whisperwood →"]},
		],
	},
	"village": {
		"display_name": "Brambleford",
		"markers": {
			"1": {"type": "spawn", "name": "from_farm", "ground": "="},
			">": {"type": "exit", "target": "farm", "spawn": "from_village", "ground": "="},
			"S": {"type": "sign", "ground": "."},
			"N": {"type": "npc", "data": "res://data/npcs/tamsin.tres", "name": "Tamsin", "ground": "c"},
			"Q": {"type": "npc", "data": "res://data/npcs/pell.tres", "name": "Pell", "ground": "."},
		},
		"signs": [
			{"name": "StationSign", "lines": ["Brambleford Station.", "(Blockout: building interiors come later.)"]},
			{"name": "StoreSign", "lines": ["General Store.", "(Closed for now. Pell sells seeds out front.)"]},
			{"name": "HallSign", "lines": ["Reeve's Hall."]},
			{"name": "HouseSignNorth", "lines": ["A quiet cottage."]},
			{"name": "EastRoadSign", "lines": ["Wrenfield →"]},
			{"name": "LodgeSign", "lines": ["Warden's Lodge."]},
			{"name": "HouseSignSouth", "lines": ["A cottage with a tidy garden."]},
			{"name": "TavernSign", "lines": ["The Crooked Lantern."]},
			{"name": "MilitiaSign", "lines": ["Militia Post."]},
		],
	},
	"forest": {
		"display_name": "Whisperwood",
		"markers": {
			"1": {"type": "spawn", "name": "from_farm", "ground": "="},
			"<": {"type": "exit", "target": "farm", "spawn": "from_forest", "ground": "="},
			"S": {"type": "sign", "ground": "."},
			"N": {"type": "npc", "data": "res://data/npcs/odile.tres", "name": "Odile", "ground": "."},
			"7": {"type": "wild_kith", "kith": "rillet", "ground": "."},
			"8": {"type": "wild_kith", "kith": "bramblehog", "ground": "g"},
			"9": {"type": "wild_kith", "kith": "cindercoot", "ground": "."},
		},
		"signs": [
			{"name": "PondSign", "lines": ["Mirelight Pond.", "Wild kith come here to drink. Bring food they like, and a Bond Charm."]},
			{"name": "LogSign", "lines": ["A fallen log blocks the path north.", "(Blockout: a haul gate for a later phase.)"]},
			{"name": "ForestSign", "lines": ["WHISPERWOOD", "Stay on the paths."]},
		],
	},
}


func _ready() -> void:
	var tileset := _build_tileset()
	var err := ResourceSaver.save(tileset, TILESET_PATH, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("Could not save tileset: %s" % error_string(err))
		get_tree().quit(1)
		return
	tileset = load(TILESET_PATH)
	for map_id: String in MAPS:
		var scene := _build_map(map_id, MAPS[map_id], tileset)
		if scene == null:
			get_tree().quit(1)
			return
		var path := MAP_DIR.path_join(map_id + ".tscn")
		err = ResourceSaver.save(scene, path)
		if err != OK:
			push_error("Could not save %s: %s" % [path, error_string(err)])
			get_tree().quit(1)
			return
		print("Wrote ", path)
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
	var log_shape := PackedVector2Array([Vector2(-8, -3), Vector2(8, -3), Vector2(8, 5), Vector2(-8, 5)])
	for tile in Tile.values():
		atlas.create_tile(Vector2i(tile, 0))
	tileset.add_source(atlas, 0)

	for tile in Tile.values():
		var data := atlas.get_tile_data(Vector2i(tile, 0), 0)
		match tile:
			Tile.WATER:
				_add_collision(data, PHYSICS_WATER, full)
			Tile.WALL, Tile.FENCE, Tile.ROOF:
				_add_collision(data, PHYSICS_WORLD, full)
				data.y_sort_origin = 8
			Tile.TREE:
				_add_collision(data, PHYSICS_WORLD, trunk)
				data.y_sort_origin = 8
			Tile.ROCK:
				_add_collision(data, PHYSICS_WORLD, boulder)
				data.y_sort_origin = 6
			Tile.LOG:
				_add_collision(data, PHYSICS_WORLD, log_shape)
				data.y_sort_origin = 5
	return tileset


func _add_collision(data: TileData, layer: int, points: PackedVector2Array) -> void:
	data.add_collision_polygon(layer)
	data.set_collision_polygon_points(layer, 0, points)


func _read_layout(map_id: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(LAYOUT_DIR.path_join(map_id + ".txt"))
	var rows := PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges() != "":
			rows.append(line.strip_edges(false, true))
	return rows


func _build_map(map_id: String, config: Dictionary, tileset: TileSet) -> PackedScene:
	var rows := _read_layout(map_id)
	if rows.is_empty():
		push_error("Layout for %s is empty or missing." % map_id)
		return null
	var markers: Dictionary = config.get("markers", {})
	var signs: Array = config.get("signs", [])

	var root := Node2D.new()
	root.name = map_id.to_pascal_case()
	root.y_sort_enabled = true
	root.set_script(load(WORLD_MAP_SCRIPT))
	root.set("map_id", StringName(map_id))
	root.set("display_name", config.get("display_name", map_id))

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
	var transitions := Node2D.new()
	transitions.name = "Transitions"
	_add(root, transitions, root)

	var exit_cells := {}  # char → Array[Vector2i]
	var sign_index := 0
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var key := row[x]
			var cell := Vector2i(x, y)
			var base := Vector2(x * T + T / 2.0, (y + 1) * T)  # bottom-centre of the cell
			var terrain_key := key
			if not TERRAIN.has(key):
				if not markers.has(key):
					push_error("%s: unknown character '%s' at %s" % [map_id, key, cell])
					return null
				var marker: Dictionary = markers[key]
				terrain_key = marker.get("ground", ".")
				match marker["type"]:
					"spawn":
						var spawn := Marker2D.new()
						spawn.name = marker["name"]
						spawn.position = base - Vector2(0, 2)
						_add(spawns, spawn, root)
					"exit":
						if not exit_cells.has(key):
							exit_cells[key] = []
						exit_cells[key].append(cell)
					"prop":
						var prop := _instance(marker["scene"], marker["name"], base)
						if marker.has("lines"):
							prop.set("lines", PackedStringArray(marker["lines"]))
						_add(entities, prop, root)
					"sign":
						if sign_index >= signs.size():
							push_error("%s: more S markers than sign entries" % map_id)
							return null
						var entry: Dictionary = signs[sign_index]
						sign_index += 1
						var sign := _instance(SIGN_SCENE, entry["name"], base)
						sign.set("lines", PackedStringArray(entry["lines"]))
						_add(entities, sign, root)
					"npc":
						var npc := _instance(NPC_SCENE, marker["name"], base - Vector2(0, 2))
						npc.set("data", load(marker["data"]))
						_add(entities, npc, root)
					"plot":
						var plot := _instance(FARM_PLOT_SCENE, "Plot_%d_%d" % [x, y], base)
						plot.set("plot_id", StringName("%s:%d,%d" % [map_id, x, y]))
						_add(entities, plot, root)
					"wild_kith":
						var kith := _instance(WILD_KITH_SCENE, "Wild%s_%d_%d" % [String(marker["kith"]).to_pascal_case(), x, y], base)
						kith.set("kith_id", StringName(marker["kith"]))
						kith.set("spawn_id", StringName("%s:%d,%d" % [map_id, x, y]))
						_add(entities, kith, root)
					"ground":
						pass
			var entry: Array = TERRAIN[terrain_key]
			ground.set_cell(cell, 0, Vector2i(entry[0], 0))
			if entry[1] >= 0:
				obstacles.set_cell(cell, 0, Vector2i(entry[1], 0))
	if sign_index != signs.size():
		push_error("%s: %d sign entries but %d S markers" % [map_id, signs.size(), sign_index])
		return null

	for key: String in exit_cells:
		var marker: Dictionary = markers[key]
		_add(transitions, _make_transition(key, marker, exit_cells[key]), root)

	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _make_transition(key: String, marker: Dictionary, cells: Array) -> Area2D:
	var rect := Rect2i(cells[0], Vector2i.ONE)
	for cell: Vector2i in cells:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	var area := Area2D.new()
	area.name = "To" + String(marker["target"]).to_pascal_case()
	area.set_script(load(MAP_TRANSITION_SCRIPT))
	area.set("target_map_id", StringName(marker["target"]))
	area.set("target_spawn_id", StringName(marker["spawn"]))
	area.position = Vector2(rect.position * T) + Vector2(rect.size * T) / 2.0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = Vector2(rect.size * T)
	shape.shape = box
	area.add_child(shape)
	return area


func _instance(path: String, node_name: String, pos: Vector2) -> Node2D:
	var node: Node2D = load(path).instantiate()
	node.name = node_name
	node.position = pos
	return node


func _add(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node
	for grandchild in child.get_children():
		if grandchild.owner == null:
			grandchild.owner = owner_node
