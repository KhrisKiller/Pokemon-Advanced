extends TestCase
## Player movement, facing, collision against the real test map, and control lock.

const PLAYER_SCENE := preload("res://game/characters/player/player.tscn")
const MAP_SCENE := preload("res://game/world/maps/test_map.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var map: WorldMap
var player: Player


func before_each() -> void:
	map = add_to_root(MAP_SCENE.instantiate()) as WorldMap
	player = PLAYER_SCENE.instantiate() as Player
	map.add_entity(player)


func after_each() -> void:
	for action in ACTIONS:
		Input.action_release(action)


## Open grass south of the path (cell 20,17) — nothing solid nearby.
func _place_in_open_field() -> void:
	player.global_position = Vector2(20 * 16 + 8, 17 * 16 + 12)
	await wait_physics_frames(2)


func test_moves_right_when_input_pressed() -> void:
	await _place_in_open_field()
	var start := player.global_position
	Input.action_press(&"move_right")
	await wait_physics_frames(30)
	assert_gt(player.global_position.x - start.x, 20.0, "moved right")
	assert_almost_eq(player.global_position.y, start.y, 0.5, "no vertical drift")
	assert_eq(player.facing, Vector2.RIGHT)


func test_stops_after_release() -> void:
	await _place_in_open_field()
	Input.action_press(&"move_down")
	await wait_physics_frames(20)
	Input.action_release(&"move_down")
	await wait_physics_frames(20)
	var resting := player.global_position
	await wait_physics_frames(10)
	assert_almost_eq(player.global_position.distance_to(resting), 0.0, 0.01, "friction stops the player")


func test_diagonal_is_not_faster_than_walk_speed() -> void:
	await _place_in_open_field()
	for i in 60:
		player.step_movement(Vector2(1, 1), 1.0 / 60.0)
	assert_almost_eq(player.velocity.length(), player.walk_speed, 0.5)


func test_facing_from_input() -> void:
	assert_eq(Player.facing_from_input(Vector2(0.9, 0.2), Vector2.DOWN), Vector2.RIGHT)
	assert_eq(Player.facing_from_input(Vector2(-0.1, -0.8), Vector2.DOWN), Vector2.UP)
	assert_eq(Player.facing_from_input(Vector2.ZERO, Vector2.LEFT), Vector2.LEFT, "no input keeps facing")
	var diag := Vector2(1, 1).normalized()
	assert_eq(Player.facing_from_input(diag, Vector2.DOWN), Vector2.DOWN, "diagonal keeps a matching facing")
	assert_eq(Player.facing_from_input(diag, Vector2.UP), Vector2.RIGHT, "diagonal picks horizontal otherwise")


func test_facing_moves_interaction_probe() -> void:
	player.set_facing(Vector2.LEFT)
	assert_lt(player.probe.position.x, 0.0)
	assert_eq(player.sprite.frame, Player.Frame.LEFT)
	player.set_facing(Vector2.UP)
	assert_lt(player.probe.position.y, -10.0)
	assert_eq(player.sprite.frame, Player.Frame.UP)


func test_house_wall_blocks_movement() -> void:
	# Inside the house, just below the top wall (row 3). Walk up into it.
	player.global_position = Vector2(8 * 16 + 8, 5 * 16 + 14)
	await wait_physics_frames(2)
	var start_y := player.global_position.y
	Input.action_press(&"move_up")
	await wait_physics_frames(60)
	var wall_bottom := 4 * 16.0
	assert_lt(player.global_position.y, start_y - 10.0, "walked up to the wall")
	assert_gt(player.global_position.y, wall_bottom, "stopped by the wall")


func test_water_blocks_movement() -> void:
	# Left of the pond on row 6 (water starts at column 28). Walk right into it.
	player.global_position = Vector2(25 * 16 + 8, 6 * 16 + 12)
	await wait_physics_frames(2)
	var start_x := player.global_position.x
	Input.action_press(&"move_right")
	await wait_physics_frames(90)
	assert_gt(player.global_position.x, start_x + 20.0, "walked up to the shore")
	assert_lt(player.global_position.x, 28 * 16.0, "stopped at the water")


func test_modal_locks_and_unlocks_control() -> void:
	await _place_in_open_field()
	EventBus.modal_opened.emit(&"test_modal")
	assert_false(player.is_control_enabled())
	var start := player.global_position
	Input.action_press(&"move_right")
	await wait_physics_frames(20)
	assert_almost_eq(player.global_position.x, start.x, 0.01, "no movement while a modal is open")
	EventBus.modal_closed.emit(&"test_modal")
	assert_true(player.is_control_enabled())
	await wait_physics_frames(20)
	assert_gt(player.global_position.x, start.x + 5.0, "moves again after the modal closes")


func test_camera_limits_match_map_bounds() -> void:
	map.apply_camera_limits(player.camera)
	var bounds := map.get_bounds()
	assert_eq(bounds.size, Vector2(48 * 16, 30 * 16))
	assert_eq(player.camera.limit_left, 0)
	assert_eq(player.camera.limit_top, 0)
	assert_eq(player.camera.limit_right, 48 * 16)
	assert_eq(player.camera.limit_bottom, 30 * 16)
