extends RefCounted
class_name SaveSystem

const SAVE_DIR := "user://saves"

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


# ---- Terminal helpers ----

func build_terminal_state(term: Terminal) -> Dictionary:
	if term == null or term.fs == null:
		return {}

	# Requires your FileSystem.gd to implement to_data()
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

	# Requires your FileSystem.gd to implement from_data(dict)
	term.fs.from_data(fs_data as Dictionary)

	term.cwd = String(state.get("cwd", "/home"))

	# Safety: ensure cwd exists, otherwise reset to /home
	if not term.fs.is_dir(term.cwd):
		term.cwd = "/home"
		if not term.fs.is_dir("/home"):
			term.fs.mkdir("/home")

	return true


# Convenience wrappers (optional)
func save_terminal(slot: String, term: Terminal) -> bool:
	return save(slot, build_terminal_state(term))

func load_terminal(slot: String, term: Terminal) -> bool:
	var data: Dictionary = load_slot(slot)
	return apply_terminal_state(term, data)
