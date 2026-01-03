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
# Combined save / load (filesystem + network)
# -------------------------------------------------

func build_full_state(term: Terminal) -> Dictionary:
	var data := build_terminal_state(term)
	data["player_device"] = build_player_device_state()
	return data

func apply_full_state(term: Terminal, state: Dictionary) -> bool:
	var ok := apply_terminal_state(term, state)

	var dev_state: Dictionary = state.get("player_device", {})
	if typeof(dev_state) == TYPE_DICTIONARY:
		apply_player_device_state(dev_state)

	return ok


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
	var state := build_terminal_state(term)
	return save(slot, state)

func load_terminal(slot: String, term: Terminal) -> bool:
	var state := load_slot(slot)
	return apply_terminal_state(term, state)
