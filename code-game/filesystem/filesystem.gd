extends RefCounted
class_name FileSystem

# ---- Data model: nested dictionaries ----
# A directory is: { "type":"dir", "children": { name: node, ... } }
# A file is:      { "type":"file", "content":"..." }

var root := {
	"type": "dir",
	"children": {}
}

func _init() -> void:
	# Start with /home + readme.txt
	mkdir("/home")
	write_file("/home/readme.txt",
		"Welcome!\n\nType 'help' to see commands.\nTry: ls, cd home, cat readme.txt\n"
	)

# ---------- Path helpers ----------
func _split_path(path: String) -> Array[String]:
	var p := path.strip_edges()
	if p == "" or p == "/":
		return []

	p = p.trim_prefix("/").trim_suffix("/")

	var packed := p.split("/", false) # PackedStringArray
	var parts: Array[String] = []
	parts.assign(packed) # copies into typed Array[String]
	return parts

func _get_dir_node(path: String) -> Dictionary:
	# Returns directory node dictionary or {} if missing
	var parts := _split_path(path)
	var node: Dictionary = root
	for part in parts:
		if not node.has("children"):
			return {}
		var children: Dictionary = node["children"]
		if not children.has(part):
			return {}
		node = children[part]
		if node.get("type","") != "dir":
			return {}
	return node

func _get_parent_dir(path: String) -> Dictionary:
	# For "/home/readme.txt" -> returns node for "/home"
	var parts := _split_path(path)
	if parts.is_empty():
		return {} # root has no parent for creation ops
	parts.pop_back()
	var parent_path := "/" + "/".join(parts) if not parts.is_empty() else "/"
	return _get_dir_node(parent_path)

func _base_name(path: String) -> String:
	var parts := _split_path(path)
	return "" if parts.is_empty() else parts[-1]

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
	if path == "/" or path.strip_edges() == "":
		return true

	var parent := _get_parent_dir(path)
	if parent.is_empty() and path != "/":
		# If creating "/home" and root has no children, parent is root:
		# _get_parent_dir("/home") returns "/" which is valid; so this should not happen often.
		parent = root

	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	if children.has(name):
		return children[name].get("type","") == "dir"

	children[name] = {"type":"dir", "children": {}}
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
	return true

func write_file(path: String, content: String) -> bool:
	# auto-create parent dir? we’ll keep it strict for now:
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root
	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	children[name] = {"type":"file", "content": content}
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
	return true

# ---------- Persistence ----------
func to_data() -> Dictionary:
	return root

func from_data(data: Dictionary) -> void:
	# minimal safety
	if data.get("type","") == "dir" and data.has("children"):
		root = data
	else:
		root = {"type":"dir","children": {}}

func save_to_user(path: String = "user://fs.json") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_data()))
	return true

func load_from_user(path: String = "user://fs.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		from_data(parsed)
		return true
	return false
