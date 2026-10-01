class_name WildKith
extends Interactable
## A wild kith standing in a map, waiting to be befriended (prototype: no battles, no wandering).
## Presentation only: the bonding rules are KithBonding; calm and "already bonded" are WorldState
## flags keyed by `spawn_id`, so each spot can be bonded once and stays empty afterwards.

## Species id (data/kith/).
@export var kith_id: StringName = &""
## "<map_id>:<marker>" — set by the map builder. Stable id used in world flags.
@export var spawn_id: StringName = &""

var _session: GameSession

@onready var _sprite: Sprite2D = $Sprite2D


func _init() -> void:
	super()
	add_to_group(GameSession.SESSION_AWARE_GROUP)


func _ready() -> void:
	var species := get_species()
	if species != null and species.sprite != null:
		_sprite.texture = species.sprite
	# Bonded/calm live in WorldState, which a load can replace while this map stays loaded.
	WorldState.flag_changed.connect(_on_flag_changed)
	WorldState.loaded.connect(_on_world_loaded)
	_refresh()


func bind_session(session: GameSession) -> void:
	_session = session
	_refresh()


func get_species() -> KithData:
	return ContentDB.get_kith(kith_id)


func is_bonded() -> bool:
	return KithBonding.is_bonded(WorldState, spawn_id)


func can_interact(actor: Node) -> bool:
	return super(actor) and _session != null and get_species() != null and not is_bonded()


func get_prompt() -> String:
	var species := get_species()
	if species == null:
		return ""
	return KithBonding.prompt_for(KithBonding.next_step(species, spawn_id, WorldState))


func _on_interact(_actor: Node) -> void:
	var species := get_species()
	var result := KithBonding.perform(species, spawn_id, WorldState, _session.player, _session.kith,
			_session.kith_config, ContentDB, Clock.time.day_index)
	var kith: KithState = result["kith"]
	if kith != null:
		EventBus.kith_bonded.emit(kith.uid, kith.species_id)
	if result["message"] != "":
		EventBus.dialogue_requested.emit(PackedStringArray([result["message"]]))
	prompt_changed.emit()
	_refresh()


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == KithBonding.bonded_flag(spawn_id) or flag == KithBonding.calm_flag(spawn_id):
		prompt_changed.emit()
		_refresh()


func _on_world_loaded() -> void:
	prompt_changed.emit()
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var gone := is_bonded()
	visible = not gone
	# A bonded spot is empty: no prompt, nothing to bump into.
	set_deferred(&"monitorable", not gone)
	$Body/Shape.set_deferred(&"disabled", gone)
