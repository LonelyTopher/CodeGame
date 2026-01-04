extends RefCounted
class_name SaveSystem

const SAVE_DIR := "user://saves"


# -------------------------------------------------
# Core save / load helpers
# -------------------------------------------------

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _path_for(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]

func save(slot: String, state: Dictionary) -> bool:
	_ensure_dir()
	var path := _path_for(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return true

func load_slot(slot: String) -> Dictionary:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var txt := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func exists(slot: String) -> bool:
	return FileAccess.file_exists(_path_for(slot))

func delete(slot: String) -> bool:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

func list_slots() -> Array[String]:
	_ensure_dir()
	var out: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			out.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# -------------------------------------------------
# Autoload helper (SaveSystem is RefCounted)
# -------------------------------------------------

func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null

	var root: Node = tree.get_root()
	return root.get_node_or_null(name)


# -------------------------------------------------
# Terminal filesystem state
# -------------------------------------------------

func build_terminal_state(term: Terminal) -> Dictionary:
	if term == null or term.fs == null:
		return {}

	var fs_data: Dictionary = term.fs.to_data()

	return {
		"cwd": term.cwd,
		"fs": fs_data
	}

func apply_terminal_state(term: Terminal, state: Dictionary) -> bool:
	if term == null or term.fs == null:
		return false
	if state.is_empty():
		return false

	var fs_data: Variant = state.get("fs", {})
	if typeof(fs_data) != TYPE_DICTIONARY:
		return false

	term.fs.from_data(fs_data as Dictionary)
	term.cwd = String(state.get("cwd", "/home"))

	if not term.fs.is_dir(term.cwd):
		term.cwd = "/home"
		if not term.fs.is_dir("/home"):
			term.fs.mkdir("/home")

	return true


# -------------------------------------------------
# Player device network state
# -------------------------------------------------

func build_player_device_state() -> Dictionary:
	if not Engine.has_singleton("WorldNetwork"):
		return {}

	var world := Engine.get_singleton("WorldNetwork")
	if world == null or world.player_device == null:
		return {}

	var d = world.player_device
	return {
		"hostname": d.hostname,
		"mac": d.mac,
		"ip_address": d.ip_address,
		"online": d.online
	}

func apply_player_device_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	if not Engine.has_singleton("WorldNetwork"):
		return false

	var world := Engine.get_singleton("WorldNetwork")
	if world == null or world.player_device == null:
		return false

	var d = world.player_device
	d.hostname   = String(state.get("hostname", d.hostname))
	d.mac        = String(state.get("mac", d.mac))
	d.ip_address = String(state.get("ip_address", d.ip_address))
	d.online     = bool(state.get("online", d.online))

	return true


# -------------------------------------------------
# Player progression state (PlayerBase)
# -------------------------------------------------

func build_player_progress_state() -> Dictionary:
	var player = _autoload("PlayerBase")
	if player == null:
		return {}

	return {
		"level": int(player.level),
		"xp": int(player.xp),
		"currencies": player.build_currency_state()
	}

func apply_player_progress_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var player = _autoload("PlayerBase")
	if player == null:
		return false

	var lv := int(state.get("level", player.level))
	var xp := int(state.get("xp", player.xp))

	lv = clamp(lv, 1, 50)
	xp = max(xp, 0)

	player.level = lv
	player.xp = xp

	var cur_state: Variant = state.get("currencies", {})
	if typeof(cur_state) == TYPE_DICTIONARY:
		player.apply_currency_state(cur_state as Dictionary)

	# Optional: nudge UI/listeners to refresh if they use signals
	if player.has_signal("player_xp_changed"):
		player.emit_signal("player_xp_changed", player.xp, player.level)

	return true


# -------------------------------------------------
# Stats progression state (StatsSystem -> StatBase instances)
# -------------------------------------------------

func build_stats_progress_state() -> Dictionary:
	var stats_system = _autoload("StatsSystem")
	if stats_system == null:
		return {}

	var out: Dictionary = {}
	var stats_dict: Dictionary = stats_system.stats

	for stat_id in stats_dict.keys():
		var stat = stats_dict[stat_id]
		if stat == null:
			continue

		out[String(stat_id)] = {
			"level": int(stat.level),
			"xp": int(stat.xp)
		}

	return out


func apply_stats_progress_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var stats_system = _autoload("StatsSystem")
	if stats_system == null:
		return false

	var stats_dict: Dictionary = stats_system.stats
	if stats_dict.is_empty():
		return false

	# Map stringified keys -> actual key objects used by stats_dict (StringName, int, etc.)
	var key_lookup: Dictionary = {}
	for k in stats_dict.keys():
		key_lookup[String(k)] = k

	for saved_id in state.keys():
		var saved_key := String(saved_id)

		if not key_lookup.has(saved_key):
			continue

		var real_key = key_lookup[saved_key]
		var stat = stats_dict[real_key]
		if stat == null:
			continue

		var s: Variant = state[saved_id]
		if typeof(s) != TYPE_DICTIONARY:
			continue

		var lv := int((s as Dictionary).get("level", stat.level))
		var xp := int((s as Dictionary).get("xp", stat.xp))

		lv = clamp(lv, 1, 50)
		xp = max(xp, 0)

		stat.level = lv
		stat.xp = xp

		if stat.has_signal("xp_changed"):
			stat.emit_signal("xp_changed", saved_key, stat.xp, stat.level)

	return true

# -------------------------------------------------
# Combined save / load (filesystem + network + progression)
# -------------------------------------------------

func build_full_state(term: Terminal) -> Dictionary:
	var data := build_terminal_state(term)
	data["version"] = 1
	data["player_device"] = build_player_device_state()
	data["player"] = build_player_progress_state()
	data["stats"] = build_stats_progress_state()
	return data

func apply_full_state(term: Terminal, state: Dictionary) -> bool:
	if state.is_empty():
		return false

	# Terminal is important, but don't hard-fail if it can't apply
	var ok_term := true
	if state.has("fs") or state.has("cwd"):
		ok_term = apply_terminal_state(term, state)

	# Device is optional (depends on init order / singleton availability)
	var dev_state: Variant = state.get("player_device", {})
	if typeof(dev_state) == TYPE_DICTIONARY and not (dev_state as Dictionary).is_empty():
		apply_player_device_state(dev_state as Dictionary)

	# Player is important
	var ok_player := true
	var player_state: Variant = state.get("player", {})
	if typeof(player_state) == TYPE_DICTIONARY and not (player_state as Dictionary).is_empty():
		ok_player = apply_player_progress_state(player_state as Dictionary)

	# Stats are important
	var ok_stats := true
	var stats_state: Variant = state.get("stats", {})
	if typeof(stats_state) == TYPE_DICTIONARY and not (stats_state as Dictionary).is_empty():
		ok_stats = apply_stats_progress_state(stats_state as Dictionary)

	# Success if player OR stats OR terminal applied.
	# (Terminal might be irrelevant in some screens; player/stats are the real win.)
	return ok_player or ok_stats or ok_term


# -------------------------------------------------
# Convenience wrappers
# -------------------------------------------------

func save_game(slot: String, term: Terminal) -> bool:
	return save(slot, build_full_state(term))

func load_game(slot: String, term: Terminal) -> bool:
	var data := load_slot(slot)
	return apply_full_state(term, data)

#--------------------------------------------------
# More convenience wrappers
# -------------------------------------------------
# PUBLIC API — commands depend on this
func save_terminal(slot: String, term: Terminal) -> bool:
	# Backwards-compatible: terminal save now saves FULL state too
	return save_game(slot, term)

func load_terminal(slot: String, term: Terminal) -> bool:
	# Backwards-compatible: terminal load now loads FULL state too
	return load_game(slot, term)
