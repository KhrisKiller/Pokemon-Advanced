class_name KithMenu
extends ListMenu
## The party screen: inspect kith (Trust, diet, helper status), feed from the bag, choose the
## active kith, rename. Presentation only: rules are KithRoster, KithCare and KithHelpers.

enum Page { PARTY, ACTIONS, FEED, RENAME }

const MODAL_ID := &"kith_menu"

var page: Page = Page.PARTY

var _session: GameSession
var _content: Object
var _uid: StringName = &""
var _name_edit: LineEdit


func _init() -> void:
	super()
	modal_id = MODAL_ID
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Name"
	_name_edit.hide()
	_name_edit.text_submitted.connect(_on_name_submitted)
	get_child(0).add_child(_name_edit)
	get_child(0).move_child(_name_edit, 2)


func bind(session: GameSession, content: Object) -> void:
	_session = session
	_content = content


func open_party() -> bool:
	if _session == null:
		return false
	page = Page.PARTY
	open_menu()
	return true


## The kith whose sub-page is open (or the one under the cursor on the party page).
func get_focused_uid() -> StringName:
	if page == Page.PARTY:
		var members := _session.kith.get_members()
		return members[get_selected()].uid if get_selected() < members.size() else &""
	return _uid


func open_actions(uid: StringName) -> void:
	_uid = uid
	page = Page.ACTIONS
	select(0)
	refresh()


func open_feed() -> void:
	page = Page.FEED
	select(0)
	refresh()


func feed(item_id: StringName) -> Dictionary:
	var kith := _session.kith.get_kith(_uid)
	var result := KithCare.feed(kith, _session.kith.get_species(kith), item_id, _session.player.inventory, _content, _session.kith_config)
	if result["ok"]:
		_session.kith.changed.emit()
	set_message(result["message"])
	return result


func make_active() -> void:
	_session.kith.set_active(_uid)
	var kith := _session.kith.get_kith(_uid)
	set_message("%s is now your active kith." % kith.get_display_name(_session.kith.get_species(kith)))
	page = Page.PARTY


func open_rename() -> void:
	page = Page.RENAME
	var kith := _session.kith.get_kith(_uid)
	_name_edit.text = kith.nickname
	_name_edit.show()
	_name_edit.grab_focus.call_deferred()
	refresh()


func rename(nickname: String) -> void:
	_session.kith.set_nickname(_uid, nickname)
	var kith := _session.kith.get_kith(_uid)
	set_message("Now called %s." % kith.get_display_name(_session.kith.get_species(kith)))
	_leave_rename()


func close_menu() -> void:
	_leave_rename()
	super()


func _go_back() -> void:
	match page:
		Page.PARTY:
			close_menu()
		Page.ACTIONS:
			page = Page.PARTY
			refresh()
		Page.FEED, Page.RENAME:
			_leave_rename()
			page = Page.ACTIONS
			refresh()


func _leave_rename() -> void:
	if _name_edit.visible:
		_name_edit.release_focus()
		_name_edit.hide()
	if page == Page.RENAME:
		page = Page.ACTIONS


func _on_name_submitted(text: String) -> void:
	rename(text)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"open_kith") and not event.is_echo():
		close_menu()
		get_viewport().set_input_as_handled()
		return
	super(event)


# --- pages -----------------------------------------------------------------------------------

func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _session == null:
		return rows
	var roster := _session.kith.get_members()
	if page != Page.PARTY and _session.kith.get_kith(_uid) == null:
		page = Page.PARTY
	match page:
		Page.PARTY:
			_set_title("Kith   (%d/%d)" % [roster.size(), _session.kith_config.party_limit])
			for kith in roster:
				var star := "★ " if kith.uid == _session.kith.active_uid else ""
				rows.append({"text": "%s%s   Trust %d · %s" % [star, _name_of(kith), kith.trust, _session.kith_config.trust_label(kith.trust)],
						"action": open_actions.bind(kith.uid)})
			if roster.is_empty():
				rows.append({"text": "(No kith yet. Wild kith may accept food, then a Bond Charm.)"})
			_set_hint("[E] choose   [Esc] close")
		Page.ACTIONS:
			var kith := _session.kith.get_kith(_uid)
			_set_title(_name_of(kith))
			rows.append({"text": "Feed", "action": open_feed})
			if kith.uid != _session.kith.active_uid:
				rows.append({"text": "Make active", "action": make_active})
			rows.append({"text": "Rename", "action": open_rename})
			rows.append({"text": "Back", "action": _go_back})
			_set_hint("[E] choose   [Esc] back")
		Page.FEED:
			var kith := _session.kith.get_kith(_uid)
			var species := _session.kith.get_species(kith)
			_set_title("Feed %s" % _name_of(kith))
			for item_id in _session.player.inventory.item_ids():
				var item: ItemData = _content.get_item(item_id)
				if item == null or not item.has_tag(&"food"):
					continue
				var taste := "loves it" if species.loves(item) else ("will eat" if species.will_eat(item) else "won't eat")
				rows.append({"text": "%s ×%d   (%s)" % [item.display_name, _session.player.inventory.count(item_id), taste],
						"action": feed.bind(item_id)})
			if rows.is_empty():
				rows.append({"text": "(No food in your bag. Harvest some crops.)"})
			rows.append({"text": "Back", "action": _go_back})
			_set_hint("[E] feed one   [Esc] back")
		Page.RENAME:
			_set_title("Rename %s" % _name_of(_session.kith.get_kith(_uid)))
			rows.append({"text": "Type a name, Enter to confirm, Esc to cancel. Empty = species name."})
			_set_hint("")
	return rows


func _update_detail() -> void:
	if _session == null:
		return
	var uid := get_focused_uid()
	var kith := _session.kith.get_kith(uid)
	if kith == null or page == Page.RENAME:
		_set_detail("")
		return
	_set_detail(describe(kith))


## Inspection text for one kith (also used by tests).
func describe(kith: KithState) -> String:
	var species := _session.kith.get_species(kith)
	var config := _session.kith_config
	var lines := PackedStringArray()
	lines.append("%s · %s" % [species.display_name, ", ".join(_strings(species.aspects))])
	lines.append("Trust %d/%d (%s)" % [kith.trust, config.trust_max, config.trust_label(kith.trust)])
	lines.append("Loves: %s   Eats: %s" % [_tags_or_dash(species.favourite_food_tags), _tags_or_dash(species.liked_food_tags)])
	lines.append("Fed today" if not KithCare.can_eat_today(kith, config) else "Hungry")
	lines.append(helper_status(kith))
	return "\n".join(lines)


func helper_status(kith: KithState) -> String:
	var species := _session.kith.get_species(kith)
	var config := _session.kith_config
	if species == null or not species.has_ability(KithHelpers.WATER):
		return "Helper: none"
	if kith.trust < config.watering_min_trust:
		return "Helper: waters crops once Trust reaches %d" % config.watering_min_trust
	return "Helper: waters up to %d plots each morning (%d today)" % [config.watering_daily_limit, kith.helper_actions_today]


func _name_of(kith: KithState) -> String:
	return kith.get_display_name(_session.kith.get_species(kith)) if kith != null else ""


static func _strings(values: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for value in values:
		out.append(String(value).capitalize())
	return out


static func _tags_or_dash(tags: Array[StringName]) -> String:
	return ", ".join(_strings(tags)) if not tags.is_empty() else "—"
