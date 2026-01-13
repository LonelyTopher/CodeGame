extends RefCounted
class_name FileSystem

# ---- Data model: nested dictionaries ----
# A directory node is:
# {
#   "type":"dir",
#   "children": { name: node, ... },
#   "locked": bool,                 # OPTIONAL (default false)
#   "lock_type": String,            # OPTIONAL ("password" for now)
#   "credential_id": String,        # OPTIONAL (what unlock expects)
#   "hint": String                  # OPTIONAL (flavor)
# }
#
# A file node is:      { "type":"file", "content":"..." }
# A data node is:      { "type":"data", "data":Dictionary, "protected":bool, "meta":Dictionary }

var root: Dictionary = {
	"type": "dir",
	"children": {},
	"locked": false
}

func _init() -> void:
	# IMPORTANT:
	# Do NOT seed defaults here.
	# Constructors should create an EMPTY filesystem so loading doesn't get overwritten.
	pass


# -------------------------------------------------
# Seeding (explicit, called only for "new game")
# -------------------------------------------------
func seed_defaults() -> void:
	mkdir("/home")
	write_file(
		"/home/readme.txt",
		"Welcome!\n\nType 'help' to see commands.\nTry: ls, cd home, cat readme.txt\n"
	)

# Safe version: only seeds if filesystem is empty
func seed_defaults_if_empty() -> void:
	var children: Dictionary = root.get("children", {})
	if typeof(children) == TYPE_DICTIONARY and not (children as Dictionary).is_empty():
		return
	seed_defaults()


# -------------------------------------------------
# Internal: normalize directory defaults so old content
# doesn't suddenly become "locked" or missing keys.
# -------------------------------------------------
func _ensure_dir_defaults(dir_node: Dictionary) -> void:
	# Only applies to dirs
	if dir_node.get("type", "") != "dir":
		return

	# locked defaults to false
	if not dir_node.has("locked"):
		dir_node["locked"] = false

	# Optional fields default to empty
	if not dir_node.has("lock_type"):
		dir_node["lock_type"] = ""
	if not dir_node.has("credential_id"):
		dir_node["credential_id"] = ""
	if not dir_node.has("hint"):
		dir_node["hint"] = ""

	# Ensure children exists
	if not dir_node.has("children") or typeof(dir_node["children"]) != TYPE_DICTIONARY:
		dir_node["children"] = {}


# ---------- Path helpers ----------
func _split_path(path: String) -> Array[String]:
	var p := path.strip_edges()
	if p == "" or p == "/":
		return []
	p = p.trim_prefix("/").trim_suffix("/")
	var packed := p.split("/", false)
	var parts: Array[String] = []
	parts.assign(packed)
	return parts

func _get_dir_node(path: String) -> Dictionary:
	var parts := _split_path(path)
	var node: Dictionary = root
	_ensure_dir_defaults(node)

	for part in parts:
		if not node.has("children"):
			return {}
		var children: Dictionary = node["children"]
		if not children.has(part):
			return {}
		node = children[part]
		if node.get("type","") != "dir":
			return {}
		_ensure_dir_defaults(node)

	return node

func _get_parent_dir(path: String) -> Dictionary:
	var parts := _split_path(path)
	if parts.is_empty():
		return {}
	parts.pop_back()
	var parent_path := "/" + "/".join(parts) if not parts.is_empty() else "/"
	return _get_dir_node(parent_path)

func _base_name(path: String) -> String:
	var parts := _split_path(path)
	return "" if parts.is_empty() else parts[-1]

func _get_node(path: String) -> Dictionary:
	if path == "/":
		_ensure_dir_defaults(root)
		return root
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return {}
	var name := _base_name(path)
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return {}
	return children[name]


# -------------------------------------------------
# Lock / Unlock API (NEW)
# -------------------------------------------------
func is_locked(path: String) -> bool:
	var node := _get_node(path)
	if node.is_empty():
		return false
	if node.get("type","") != "dir":
		return false
	_ensure_dir_defaults(node)
	return bool(node.get("locked", false))

# Sets lock metadata. Returns false if path isn't a dir or doesn't exist.
func lock_dir(path: String, credential_id: String, hint: String = "", lock_type: String = "password") -> bool:
	var node := _get_node(path)
	if node.is_empty():
		return false
	if node.get("type","") != "dir":
		return false

	_ensure_dir_defaults(node)
	node["locked"] = true
	node["lock_type"] = lock_type
	node["credential_id"] = String(credential_id)
	node["hint"] = String(hint)

	# Write back into parent if not root
	if path != "/":
		var parent := _get_parent_dir(path)
		if parent.is_empty():
			return false
		var name := _base_name(path)
		var children: Dictionary = parent.get("children", {})
		children[name] = node
		parent["children"] = children
	else:
		root = node

	return true

# Attempts unlock with credential (for now: exact match on credential_id).
# Returns:
# { ok:bool, reason:String }
func unlock_dir(path: String, credential: String) -> Dictionary:
	var node := _get_node(path)
	if node.is_empty():
		return {"ok": false, "reason": "path not found"}
	if node.get("type","") != "dir":
		return {"ok": false, "reason": "not a directory"}

	_ensure_dir_defaults(node)

	if not bool(node.get("locked", false)):
		return {"ok": true, "reason": "already unlocked"}

	var expected := String(node.get("credential_id", ""))
	if expected == "":
		return {"ok": false, "reason": "locked but missing credential id"}

	if String(credential).strip_edges().to_upper() != expected.strip_edges().to_upper():
		return {"ok": false, "reason": "invalid credential"}


	# Unlock
	node["locked"] = false

	# Write back
	if path != "/":
		var parent := _get_parent_dir(path)
		if parent.is_empty():
			return {"ok": false, "reason": "missing parent dir"}
		var name := _base_name(path)
		var children: Dictionary = parent.get("children", {})
		children[name] = node
		parent["children"] = children
	else:
		root = node

	return {"ok": true, "reason": "unlocked"}


# ---------- Query ----------
func exists(path: String) -> bool:
	if path == "/":
		return true
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	return children.has(name)

func is_dir(path: String) -> bool:
	if path == "/":
		return true
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	return children.has(name) and children[name].get("type","") == "dir"

func list_dir(path: String) -> Array[String]:
	var dir := _get_dir_node(path)
	if dir.is_empty():
		return []
	# Do NOT enforce locks here (command can decide). Keeping FS generic.
	var children: Dictionary = dir["children"]
	var names: Array[String] = []
	for k in children.keys():
		names.append(String(k))
	names.sort()
	return names

func read_file(path: String) -> String:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return ""
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	if not children.has(name):
		return ""
	var node: Dictionary = children[name]
	if node.get("type","") != "file":
		return ""
	return String(node.get("content",""))


# ---------- Mutations ----------
func mkdir(path: String) -> bool:
	path = path.strip_edges()
	if path == "" or path == "/":
		return true
	if not path.begins_with("/"):
		return false

	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root

	_ensure_dir_defaults(parent)

	if not parent.has("children") or typeof(parent["children"]) != TYPE_DICTIONARY:
		return false

	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	if children.has(name):
		return children[name].get("type", "") == "dir"

	# NEW: include lock defaults as unlocked
	children[name] = {
		"type": "dir",
		"children": {},
		"locked": false,
		"lock_type": "",
		"credential_id": "",
		"hint": ""
	}
	parent["children"] = children
	return true

func touch(path: String) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root
	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	if children.has(name):
		return children[name].get("type","") == "file"

	children[name] = {"type":"file", "content": ""}
	parent["children"] = children
	return true

func write_file(path: String, content: String) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root
	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	children[name] = {"type":"file", "content": content}
	parent["children"] = children
	return true


# ---------- Data-file support ----------
func is_data_file(path: String) -> bool:
	var node := _get_node(path)
	return (not node.is_empty()) and node.get("type","") == "data"

func write_data_file(path: String, data: Dictionary, protected: bool = false, meta: Dictionary = {}) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root
	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	children[name] = {
		"type": "data",
		"data": data,
		"protected": protected,
		"meta": meta
	}
	parent["children"] = children
	return true

func read_data_file(path: String) -> Dictionary:
	var node := _get_node(path)
	if node.is_empty():
		return {}
	if node.get("type","") != "data":
		return {}
	return node.get("data", {})

func set_data_file(path: String, new_data: Dictionary) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root

	var name := _base_name(path)
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return false

	var node: Dictionary = children[name]
	if node.get("type","") != "data":
		return false

	if bool(node.get("protected", false)):
		return false

	node["data"] = new_data
	children[name] = node
	parent["children"] = children
	return true

func remove(path: String) -> bool:
	if path == "/" or path.strip_edges() == "":
		return false
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	if not children.has(name):
		return false
	children.erase(name)
	parent["children"] = children
	return true

func remove_file(path: String) -> bool:
	if path == "/" or path.strip_edges() == "":
		return false
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	if not children.has(name):
		return false
	if children[name].get("type", "") != "file":
		return false
	children.erase(name)
	parent["children"] = children
	return true

func remove_dir_recursive(path: String) -> bool:
	if path == "/" or path.strip_edges() == "":
		return false
	if not is_dir(path):
		return false
	return remove(path)

func remove_dir(path: String) -> bool:
	if path == "/" or path.strip_edges() == "":
		return false
	if not is_dir(path):
		return false

	var dir := _get_dir_node(path)
	if dir.is_empty():
		return false

	var children: Dictionary = dir["children"]
	if not children.is_empty():
		return false

	return remove(path)

func is_file(path: String) -> bool:
	if path == "/":
		return false
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	return children.has(name) and children[name].get("type","") == "file"

func copy_file(src: String, dest: String) -> bool:
	if not is_file(src):
		return false

	var parent := _get_parent_dir(dest)
	if parent.is_empty() and dest != "/":
		parent = root

	var dest_parent_path := "/"
	var parts := _split_path(dest)
	if parts.size() > 1:
		parts.pop_back()
		dest_parent_path = "/" + "/".join(parts)
		if dest_parent_path == "":
			dest_parent_path = "/"

	if not is_dir(dest_parent_path):
		return false

	var content := read_file(src)
	return write_file(dest, content)

func move_file(src: String, dest: String) -> bool:
	if not is_file(src):
		return false

	var parts := _split_path(dest)
	var parent_path := "/"
	if parts.size() > 1:
		parts.pop_back()
		parent_path = "/" + "/".join(parts)
		if parent_path == "":
			parent_path = "/"

	if not is_dir(parent_path):
		return false

	var content := read_file(src)
	if not write_file(dest, content):
		return false

	return remove_file(src)


# ---------- Save / Load ----------
func to_data() -> Dictionary:
	return root

func from_data(data: Dictionary) -> void:
	# Replace entire tree with saved snapshot
	root = data
	# Normalize root so missing fields don't break lock logic
	_ensure_dir_defaults(root)


# --- Money helpers for data files (single-currency files) ---
func get_money_amount(path: String) -> float:
	var data := read_data_file(path)
	if data.is_empty():
		return 0.0
	return float(data.get("amount", 0.0))

func get_money_currency(path: String) -> String:
	var data := read_data_file(path)
	return String(data.get("currency", ""))

# Returns:
# { ok:bool, taken:float, remaining:float, currency:String, reason:String }
func withdraw_money(path: String, requested: float) -> Dictionary:
	if requested <= 0.0:
		return {"ok": false, "taken": 0.0, "remaining": 0.0, "currency": "", "reason": "amount must be > 0"}

	if not is_data_file(path):
		return {"ok": false, "taken": 0.0, "remaining": 0.0, "currency": "", "reason": "not a data file"}

	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return {"ok": false, "taken": 0.0, "remaining": 0.0, "currency": "", "reason": "missing parent dir"}

	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	if not children.has(name):
		return {"ok": false, "taken": 0.0, "remaining": 0.0, "currency": "", "reason": "file not found"}

	var node: Dictionary = children[name]
	if node.get("type","") != "data":
		return {"ok": false, "taken": 0.0, "remaining": 0.0, "currency": "", "reason": "not a data node"}

	var data: Dictionary = node.get("data", {})
	var currency := String(data.get("currency", ""))
	var available := float(data.get("amount", 0.0))

	if available <= 0.0:
		return {"ok": false, "taken": 0.0, "remaining": max(available, 0.0), "currency": currency, "reason": "empty"}

	var taken: float = min(requested, available)
	var remaining: float = available - taken

	data["amount"] = remaining
	node["data"] = data
	children[name] = node
	parent["children"] = children

	return {"ok": true, "taken": taken, "remaining": remaining, "currency": currency, "reason": "ok"}


func get_lock_credential_id(path: String) -> String:
	var node := _get_node(path)
	if node.is_empty():
		return ""
	if node.get("type","") != "dir":
		return ""
	_ensure_dir_defaults(node)
	return String(node.get("credential_id", ""))

# Adds a forensic transfer trace inside the DATA dictionary.
# This intentionally bypasses "protected" because it's a server-side audit artifact.
func append_data_transfer_trace(path: String, dest_ip: String) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false

	var name := _base_name(path)
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return false

	var node: Dictionary = children[name]
	if node.get("type","") != "data":
		return false

	var data: Dictionary = node.get("data", {})
	var transfers: Array = data.get("transfers", [])

	# Normalize in case older files had transfers as something else
	if typeof(transfers) != TYPE_ARRAY:
		transfers = []

	# Don’t duplicate the same IP repeatedly (optional)
	if not transfers.has(dest_ip):
		transfers.append(dest_ip)

	data["transfers"] = transfers
	node["data"] = data

	# Write back into filesystem tree
	children[name] = node
	parent["children"] = children
	return true

# Force-update a DATA file (bypasses "protected"). Useful for server-side state changes.
func force_set_data_file(path: String, new_data: Dictionary) -> bool:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false

	var name := _base_name(path)
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return false

	var node: Dictionary = children[name]
	if node.get("type","") != "data":
		return false

	node["data"] = new_data
	children[name] = node
	parent["children"] = children
	return true
