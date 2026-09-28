extends TestCase
## Placeholder NPCs: identity, position, interaction and dialogue; persistence of "met".

const NPC_SCENE := preload("res://game/characters/npc/npc.tscn")
const PLAYER_SCENE := preload("res://game/characters/player/player.tscn")
const MAIN_SCENE := preload("res://game/main/main.tscn")
const TAMSIN := preload("res://data/npcs/tamsin.tres")
const ODILE := preload("res://data/npcs/odile.tres")

var conversations: Array = []


func before_each() -> void:
	conversations.clear()
	EventBus.conversation_requested.connect(_on_conversation)
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 0.0


func after_each() -> void:
	EventBus.conversation_requested.disconnect(_on_conversation)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	Clock.setup(load("res://data/config/time_config.tres"))
	Clock.time_scale = 1.0


func _on_conversation(speaker: String, lines: PackedStringArray) -> void:
	conversations.append([speaker, lines])


func _spawn_npc(data: NpcData, pos: Vector2) -> Npc:
	var npc := NPC_SCENE.instantiate() as Npc
	npc.data = data
	npc.position = pos
	add_to_root(npc)
	return npc


func test_npc_data_is_complete() -> void:
	for data: NpcData in [TAMSIN, ODILE]:
		assert_ne(String(data.id), "", "id")
		assert_ne(data.display_name, "", "name")
		assert_not_null(data.sprite, "%s sprite" % data.id)
		assert_gt(data.first_meeting_lines.size(), 0, "%s first lines" % data.id)
		assert_gt(data.repeat_lines.size(), 0, "%s repeat lines" % data.id)
		assert_eq(data.get_met_flag(), StringName("met_%s" % data.id))


func test_first_meeting_then_repeat_lines() -> void:
	var npc := _spawn_npc(TAMSIN, Vector2(100, 100))
	assert_eq(npc.prompt, "Talk")
	npc.interact(null)
	npc.interact(null)
	assert_eq(conversations.size(), 2)
	assert_eq(conversations[0][0], "Tamsin", "speaker name")
	assert_eq(conversations[0][1], TAMSIN.first_meeting_lines)
	assert_eq(conversations[1][1], TAMSIN.repeat_lines)
	assert_true(WorldState.has_flag(&"met_tamsin"))


func test_npc_turns_to_face_the_speaker() -> void:
	var npc := _spawn_npc(ODILE, Vector2(100, 100))
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(130, 100)
	add_to_root(player)
	npc.interact(player)
	assert_eq(npc.facing, Vector2.RIGHT)
	player.position = Vector2(100, 60)
	npc.interact(player)
	assert_eq(npc.facing, Vector2.UP)


func test_npc_without_data_cannot_be_talked_to() -> void:
	var npc := _spawn_npc(null, Vector2(100, 100))
	assert_false(npc.can_interact(null))
	npc.interact(null)
	assert_eq(conversations.size(), 0)


func test_npc_body_blocks_the_player() -> void:
	var npc := _spawn_npc(TAMSIN, Vector2(200, 200))
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(200, 240)
	add_to_root(player)
	await wait_physics_frames(2)
	for i in 60:
		player.step_movement(Vector2.UP, 1.0 / 60.0)
		await tree.physics_frame
	assert_gt(player.position.y, npc.position.y, "stopped below the NPC")
	assert_lt(player.position.y, 230.0, "walked up to the NPC")


func test_npcs_are_placed_in_their_maps() -> void:
	var catalog: MapCatalog = load("res://data/maps/map_catalog.tres")
	var expected := {&"village": &"tamsin", &"forest": &"odile"}
	for map_id: StringName in expected:
		var map := catalog.instantiate_map(map_id)
		add_to_root(map)
		var found: Array[StringName] = []
		for node in map.entities.get_children():
			if node is Npc:
				found.append((node as Npc).data.id)
		assert_eq(found, [expected[map_id]] as Array[StringName], "%s NPCs" % map_id)


func test_talking_in_game_shows_speaker_and_persists_after_restart() -> void:
	var main := MAIN_SCENE.instantiate() as Main
	main.fade_duration = 0.0
	add_to_root(main)
	await wait_frames(2)
	main.change_map(&"village", &"from_farm")
	var tamsin := main.current_map.entities.get_node("Tamsin") as Npc
	main.player.global_position = tamsin.global_position + Vector2(0, 16)
	main.player.set_facing(Vector2.UP)
	await wait_physics_frames(3)
	assert_eq(main.hud.get_prompt_text(), "[E] Talk")
	assert_true(main.player.try_interact())
	var box := main.hud.message_box
	assert_true(box.is_open())
	assert_eq(box.get_speaker(), "Tamsin")
	assert_eq(box.get_current_line(), TAMSIN.first_meeting_lines[0])
	assert_eq(tamsin.facing, Vector2.DOWN, "Tamsin faces the player below her")
	while box.is_open():
		box.advance()

	assert_eq(SaveService.save_game(main.save_slot), OK)
	main.free()
	WorldState.reset()
	main = MAIN_SCENE.instantiate() as Main
	main.fade_duration = 0.0
	add_to_root(main)
	await wait_frames(2)
	assert_true(WorldState.has_flag(&"met_tamsin"), "met flag survived the restart")
	tamsin = main.current_map.entities.get_node("Tamsin") as Npc
	assert_eq(tamsin.get_lines(), TAMSIN.repeat_lines, "she remembers you")
