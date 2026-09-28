extends TestCase
## Interactables and the interaction probe.

const PLAYER_SCENE := preload("res://game/characters/player/player.tscn")
const SIGN_SCENE := preload("res://game/world/props/sign.tscn")
const BED_SCENE := preload("res://game/world/props/bed.tscn")

var world: Node2D
var player: Player
var received_lines: Array[PackedStringArray] = []
var sleep_requests: int = 0


func before_each() -> void:
	world = add_to_root(Node2D.new()) as Node2D
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector2(200, 200)
	player.set_facing(Vector2.UP)
	received_lines.clear()
	sleep_requests = 0
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.sleep_requested.connect(_on_sleep_requested)


func after_each() -> void:
	EventBus.dialogue_requested.disconnect(_on_dialogue_requested)
	EventBus.sleep_requested.disconnect(_on_sleep_requested)


func _on_dialogue_requested(lines: PackedStringArray) -> void:
	received_lines.append(lines)


func _on_sleep_requested(_source: Node) -> void:
	sleep_requests += 1


func _spawn(scene: PackedScene, pos: Vector2) -> Interactable:
	var node := scene.instantiate() as Interactable
	node.global_position = pos
	world.add_child(node)
	return node


func test_nothing_in_front_means_no_interaction() -> void:
	await wait_physics_frames(3)
	assert_eq(player.probe.current_target, null)
	assert_false(player.try_interact())


func test_sign_in_front_shows_its_lines() -> void:
	var sign := _spawn(SIGN_SCENE, Vector2(200, 184))
	sign.set("lines", PackedStringArray(["Hello", "World"]))
	await wait_physics_frames(3)
	assert_eq(player.probe.current_target, sign)
	assert_true(player.try_interact())
	assert_eq(received_lines.size(), 1)
	assert_eq(received_lines[0], PackedStringArray(["Hello", "World"]))


func test_sign_behind_player_is_ignored() -> void:
	_spawn(SIGN_SCENE, Vector2(200, 184))
	player.set_facing(Vector2.DOWN)
	await wait_physics_frames(3)
	assert_eq(player.probe.current_target, null)


func test_closest_interactable_wins() -> void:
	var near := _spawn(SIGN_SCENE, Vector2(200, 186))
	var _far := _spawn(SIGN_SCENE, Vector2(209, 180))
	await wait_physics_frames(3)
	assert_eq(player.probe.current_target, near)


func test_disabled_interactable_is_skipped() -> void:
	var sign := _spawn(SIGN_SCENE, Vector2(200, 184))
	sign.enabled = false
	await wait_physics_frames(3)
	assert_eq(player.probe.current_target, null)
	sign.interact(player)
	assert_eq(received_lines.size(), 0, "disabled interactables do nothing")


func test_target_changed_signal_fires() -> void:
	var targets: Array = []
	player.probe.target_changed.connect(func(t: Interactable) -> void: targets.append(t))
	var sign := _spawn(SIGN_SCENE, Vector2(200, 184))
	await wait_physics_frames(3)
	player.set_facing(Vector2.DOWN)
	await wait_physics_frames(3)
	assert_eq(targets, [sign, null])


func test_bed_requests_sleep() -> void:
	var bed := _spawn(BED_SCENE, Vector2(200, 190))
	await wait_physics_frames(3)
	assert_eq(bed.prompt, "Sleep")
	assert_true(player.try_interact())
	assert_eq(sleep_requests, 1)


func test_interacted_signal_carries_actor() -> void:
	var sign := _spawn(SIGN_SCENE, Vector2(200, 184))
	var actors: Array = []
	sign.interacted.connect(func(actor: Node) -> void: actors.append(actor))
	await wait_physics_frames(3)
	player.try_interact()
	assert_eq(actors, [player])
