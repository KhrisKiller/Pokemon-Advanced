class_name GameSession
extends RefCounted
## The mutable state of one play session that isn't global world state: the player's belongings,
## the farm and the bonded kith. Owned by Main and injected into map objects that need it (nodes in the
## "session_aware" group get bind_session(session) when their map loads). No autoload.

const SESSION_AWARE_GROUP := &"session_aware"

var player: PlayerState
var farm: FarmState
var kith: KithRoster
var kith_config: KithConfig


func _init(new_game: NewGameConfig, content: Object, kith_rules: KithConfig = null) -> void:
	player = PlayerState.new(new_game, content)
	farm = FarmState.new(content)
	kith_config = kith_rules if kith_rules != null else KithConfig.new()
	kith = KithRoster.new(kith_config, content)


## Save providers owned by the session, in load order.
func get_save_providers() -> Array[Object]:
	return [player, farm, kith]
