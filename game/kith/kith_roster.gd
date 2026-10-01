class_name KithRoster
extends RefCounted
## The kith the player owns (the party; there is no storage box yet). Pure state + rules.
## Save section "kith". Independent of tactical units and battles, which will read from it.

signal changed
signal active_changed(uid: StringName)

const SAVE_VERSION := 1

var config: KithConfig
var content: Object
var active_uid: StringName = &""
var _members: Array[KithState] = []
var _next_uid: int = 1


func _init(kith_config: KithConfig = null, content_source: Object = null) -> void:
	config = kith_config if kith_config != null else KithConfig.new()
	content = content_source


func reset() -> void:
	_members.clear()
	active_uid = &""
	_next_uid = 1
	changed.emit()
	active_changed.emit(active_uid)


# --- membership ------------------------------------------------------------------------------

func get_members() -> Array[KithState]:
	return _members.duplicate()


func size() -> int:
	return _members.size()


func is_full() -> bool:
	return _members.size() >= config.party_limit


func get_kith(uid: StringName) -> KithState:
	for kith in _members:
		if kith.uid == uid:
			return kith
	return null


func get_active() -> KithState:
	return get_kith(active_uid)


func get_species(kith: KithState) -> KithData:
	return content.get_kith(kith.species_id) if content != null and kith != null else null


## Creates a new individual of `species_id` and adds it. Returns null if the party is full or the
## species is unknown. The first kith becomes active.
func add_new(species_id: StringName, day: int = 0, origin: StringName = &"") -> KithState:
	if is_full() or content == null or content.get_kith(species_id) == null:
		return null
	var kith := KithState.new(StringName("kith_%04d" % _next_uid), species_id)
	_next_uid += 1
	kith.trust = config.starting_trust
	kith.bonded_day = day
	kith.origin = origin
	_members.append(kith)
	changed.emit()
	if active_uid == &"":
		set_active(kith.uid)
	return kith


## Removes a kith (e.g. released). Returns it, or null. The next member becomes active if needed.
func remove(uid: StringName) -> KithState:
	var kith := get_kith(uid)
	if kith == null:
		return null
	_members.erase(kith)
	changed.emit()
	if active_uid == uid:
		set_active(_members[0].uid if not _members.is_empty() else &"")
	return kith


## Moves a member to another position in the party order (swap with neighbours to reorder).
func move(uid: StringName, new_index: int) -> bool:
	var kith := get_kith(uid)
	if kith == null or new_index < 0 or new_index >= _members.size():
		return false
	_members.erase(kith)
	_members.insert(new_index, kith)
	changed.emit()
	return true


func set_active(uid: StringName) -> bool:
	if uid != &"" and get_kith(uid) == null:
		return false
	if active_uid != uid:
		active_uid = uid
		active_changed.emit(active_uid)
	return true


func set_nickname(uid: StringName, nickname: String) -> bool:
	var kith := get_kith(uid)
	if kith == null:
		return false
	kith.nickname = nickname.strip_edges().left(16)
	changed.emit()
	return true


# --- daily tick ------------------------------------------------------------------------------

## Morning reset of per-day state (called by the day transition, like FarmState.advance_day).
func start_new_day() -> void:
	for kith in _members:
		kith.fed_today = 0
		kith.helper_actions_today = 0
	changed.emit()


# --- persistence (Saveable contract) ---------------------------------------------------------

func get_save_id() -> StringName:
	return &"kith"


func to_save_data() -> Dictionary:
	var members: Array = []
	for kith in _members:
		members.append(kith.to_dict())
	return {"version": SAVE_VERSION, "next_uid": _next_uid, "active_uid": String(active_uid), "members": members}


## {} (a save from before Phase 4) gives an empty party.
func load_save_data(data: Dictionary) -> void:
	_members.clear()
	_next_uid = maxi(1, int(data.get("next_uid", 1)))
	var members: Variant = data.get("members", [])
	if typeof(members) == TYPE_ARRAY:
		for entry: Variant in members:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var kith := KithState.from_dict(entry)
			if kith.uid == &"":
				continue
			# Never reuse an id (even one skipped below, or if next_uid was missing or stale).
			_next_uid = maxi(_next_uid, int(String(kith.uid).trim_prefix("kith_")) + 1)
			if get_kith(kith.uid) != null:
				continue
			if content != null and content.get_kith(kith.species_id) == null:
				push_warning("Saved kith %s has unknown species '%s'; skipped." % [kith.uid, kith.species_id])
				continue
			kith.trust = mini(kith.trust, config.trust_max)
			_members.append(kith)
	active_uid = StringName(str(data.get("active_uid", "")))
	if get_kith(active_uid) == null:
		active_uid = _members[0].uid if not _members.is_empty() else &""
	changed.emit()
	active_changed.emit(active_uid)
