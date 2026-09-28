extends SceneTree
## Generates MONSERA's placeholder art as PNGs in res://assets/placeholder/.
## Run: godot --headless --path . --script res://tools/generate_placeholder_art.gd
## Then: godot --headless --path . --import
##
## Placeholders are flat shapes drawn in code, so they are 100 % original and trivially replaceable.
## Do not hand-edit the output; change this script (see ART_BIBLE.md §8).

const OUT_DIR := "res://assets/placeholder"
const T := 16  # tile size

## Tile atlas order. Keep in sync with PlaceholderTiles (game/world/placeholder_tiles.gd).
const TILE_NAMES := [
	"grass", "grass_alt", "path", "tilled", "water", "floor", "flowers",
	"wall", "fence", "tree", "rock",
]

const C := {
	"grass": Color("5f9e4a"), "grass_dark": Color("4f8a3d"), "grass_light": Color("78b85a"),
	"path": Color("c8a46a"), "path_dark": Color("a8844e"),
	"soil": Color("7a5236"), "soil_dark": Color("5e3e28"),
	"water": Color("3f7fbf"), "water_light": Color("6fa8dc"), "water_dark": Color("2f5f99"),
	"floor": Color("b98a55"), "floor_dark": Color("9a6f40"),
	"wall": Color("8a8f98"), "wall_dark": Color("5d626b"), "wall_light": Color("a9aeb6"),
	"wood": Color("8a5a32"), "wood_dark": Color("5e3b1f"), "wood_light": Color("b07a48"),
	"leaf": Color("2f7a3a"), "leaf_dark": Color("225c2b"), "leaf_light": Color("4c9a50"),
	"rock": Color("9a948a"), "rock_dark": Color("6d675f"), "rock_light": Color("c2bcb1"),
	"petal_a": Color("f2d45c"), "petal_b": Color("e8739a"),
	"skin": Color("f0c49a"), "hair": Color("5a3a22"), "shirt": Color("3f8f8a"),
	"shirt_dark": Color("2e6b67"), "pants": Color("3d4a6b"), "outline": Color("2a2320"),
	"blanket": Color("b8574a"), "blanket_dark": Color("8f3f35"), "pillow": Color("f1eadb"),
	"paper": Color("efe3c2"),
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_make_tiles(), "tiles.png")
	_save(_make_player(), "player.png")
	_save(_make_sign(), "sign.png")
	_save(_make_bed(), "bed.png")
	_save(_make_crate(), "crate.png")
	print("Placeholder art written to %s" % OUT_DIR)
	quit()


func _save(image: Image, file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s (%s)" % [path, error_string(err)])


func _new_image(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


func _dots(img: Image, ox: int, points: Array, color: Color) -> void:
	for p: Vector2i in points:
		img.set_pixel(ox + p.x, p.y, color)


# --- tiles -----------------------------------------------------------------------------------

func _make_tiles() -> Image:
	var img := _new_image(T * TILE_NAMES.size(), T)
	for i in TILE_NAMES.size():
		var ox := i * T
		match TILE_NAMES[i]:
			"grass":
				_rect(img, ox, 0, T, T, C.grass)
				_dots(img, ox, [Vector2i(3, 4), Vector2i(11, 2), Vector2i(7, 10), Vector2i(13, 12)], C.grass_dark)
			"grass_alt":
				_rect(img, ox, 0, T, T, C.grass)
				for p: Vector2i in [Vector2i(2, 5), Vector2i(9, 3), Vector2i(12, 11), Vector2i(5, 12)]:
					img.set_pixel(ox + p.x, p.y, C.grass_light)
					img.set_pixel(ox + p.x + 1, p.y - 1, C.grass_light)
					img.set_pixel(ox + p.x + 2, p.y, C.grass_light)
			"path":
				_rect(img, ox, 0, T, T, C.path)
				_dots(img, ox, [Vector2i(2, 3), Vector2i(10, 6), Vector2i(5, 12), Vector2i(13, 13)], C.path_dark)
			"tilled":
				_rect(img, ox, 0, T, T, C.soil)
				for row in [3, 7, 11, 15]:
					_rect(img, ox + 1, row, T - 2, 1, C.soil_dark)
			"water":
				_rect(img, ox, 0, T, T, C.water)
				_rect(img, ox + 2, 4, 5, 1, C.water_light)
				_rect(img, ox + 9, 10, 4, 1, C.water_light)
				_rect(img, ox, 15, T, 1, C.water_dark)
			"floor":
				_rect(img, ox, 0, T, T, C.floor)
				for row in [0, 5, 10, 15]:
					_rect(img, ox, row, T, 1, C.floor_dark)
			"flowers":
				_rect(img, ox, 0, T, T, C.grass)
				for p: Vector2i in [Vector2i(3, 3), Vector2i(10, 5), Vector2i(6, 11), Vector2i(12, 12)]:
					var petal: Color = C.petal_a if (p.x + p.y) % 2 == 0 else C.petal_b
					_rect(img, ox + p.x - 1, p.y, 3, 1, petal)
					_rect(img, ox + p.x, p.y - 1, 1, 3, petal)
			"wall":
				_rect(img, ox, 0, T, T, C.wall)
				_rect(img, ox, 0, T, 2, C.wall_light)
				for row in [5, 10, 15]:
					_rect(img, ox, row, T, 1, C.wall_dark)
				_rect(img, ox + 7, 0, 1, 5, C.wall_dark)
				_rect(img, ox + 3, 5, 1, 5, C.wall_dark)
				_rect(img, ox + 11, 5, 1, 5, C.wall_dark)
				_rect(img, ox + 7, 10, 1, 5, C.wall_dark)
			"fence":
				_rect(img, ox + 1, 4, 2, 11, C.wood_dark)
				_rect(img, ox + 13, 4, 2, 11, C.wood_dark)
				_rect(img, ox, 6, T, 2, C.wood)
				_rect(img, ox, 11, T, 2, C.wood)
			"tree":
				_rect(img, ox + 6, 10, 4, 6, C.wood_dark)
				_rect(img, ox + 2, 1, 12, 10, C.leaf)
				_rect(img, ox + 1, 3, 14, 6, C.leaf)
				_rect(img, ox + 3, 2, 5, 3, C.leaf_light)
				_rect(img, ox + 2, 9, 12, 2, C.leaf_dark)
			"rock":
				_rect(img, ox + 2, 5, 12, 9, C.rock)
				_rect(img, ox + 3, 4, 10, 1, C.rock)
				_rect(img, ox + 4, 5, 5, 2, C.rock_light)
				_rect(img, ox + 2, 13, 12, 1, C.rock_dark)
	return img


# --- characters and props --------------------------------------------------------------------

## 4 frames of 16×24, facing: down, up, left, right.
func _make_player() -> Image:
	var img := _new_image(16 * 4, 24)
	for f in 4:
		var ox := f * 16
		_rect(img, ox + 5, 20, 2, 3, C.pants)  # legs
		_rect(img, ox + 9, 20, 2, 3, C.pants)
		_rect(img, ox + 4, 12, 8, 8, C.shirt)  # body
		_rect(img, ox + 4, 18, 8, 2, C.shirt_dark)
		_rect(img, ox + 4, 3, 8, 9, C.skin)  # head
		_rect(img, ox + 4, 2, 8, 3, C.hair)
		match f:
			0:  # down: eyes visible
				img.set_pixel(ox + 6, 8, C.outline)
				img.set_pixel(ox + 9, 8, C.outline)
			1:  # up: back of the head
				_rect(img, ox + 4, 2, 8, 9, C.hair)
			2:  # left
				_rect(img, ox + 8, 2, 4, 7, C.hair)
				img.set_pixel(ox + 5, 8, C.outline)
			3:  # right
				_rect(img, ox + 4, 2, 4, 7, C.hair)
				img.set_pixel(ox + 10, 8, C.outline)
	return img


func _make_sign() -> Image:
	var img := _new_image(16, 16)
	_rect(img, 7, 9, 2, 7, C.wood_dark)
	_rect(img, 1, 2, 14, 8, C.wood)
	_rect(img, 1, 9, 14, 1, C.wood_dark)
	_rect(img, 3, 4, 10, 1, C.wood_light)
	_rect(img, 3, 6, 8, 1, C.wood_light)
	return img


## 16×32 bed seen from above, pillow at the top.
func _make_bed() -> Image:
	var img := _new_image(16, 32)
	_rect(img, 1, 1, 14, 30, C.wood_dark)
	_rect(img, 2, 2, 12, 28, C.wood)
	_rect(img, 3, 3, 10, 6, C.pillow)
	_rect(img, 2, 11, 12, 18, C.blanket)
	_rect(img, 2, 11, 12, 2, C.blanket_dark)
	return img


func _make_crate() -> Image:
	var img := _new_image(16, 16)
	_rect(img, 1, 2, 14, 13, C.wood)
	_rect(img, 1, 2, 14, 1, C.wood_light)
	_rect(img, 1, 14, 14, 1, C.wood_dark)
	_rect(img, 1, 2, 1, 13, C.wood_dark)
	_rect(img, 14, 2, 1, 13, C.wood_dark)
	for i in 11:
		img.set_pixel(3 + i, 4 + i, C.wood_dark)
	return img
