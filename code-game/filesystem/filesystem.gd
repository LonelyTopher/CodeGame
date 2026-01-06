extends RefCounted
class_name FileSystem

# ---- Data model: nested dictionaries ----
# A directory is: { "type":"dir", "children": { name: node, ... } }
# A file is:      { "type":"file", "content":"..." }

var root: Dictionary = {
	"type": "dir",
	"children": {}
}

func _init() -> void:
	# Default seed: /home + readme.txt only
	mkdir("/home")
	write_file(
		"/home/readme.txt",
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
	parts.assign(packed)
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
		return {}
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
	path = path.strip_edges()
	if path == "" or path == "/":
		return true

	# Always require absolute paths
	if not path.begins_with("/"):
		return false

	var parent := _get_parent_dir(path)

	# IMPORTANT:
	# If parent lookup failed, root is the fallback for top-level dirs like "/etc"
	if parent.is_empty():
		parent = root


	# Parent must be a directory node with children
	if not parent.has("children") or typeof(parent["children"]) != TYPE_DICTIONARY:
		return false

	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]

	# If it already exists, mkdir succeeds only if it's a dir
	if children.has(name):
		return children[name].get("type", "") == "dir"

	# Create
	children[name] = {"type": "dir", "children": {}}
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
	# Strict would require parent exists; keeping your current behavior (fallback to root)
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		parent = root
	var name := _base_name(path)
	if name == "":
		return false

	var children: Dictionary = parent["children"]
	children[name] = {"type":"file", "content": content}
	return true

# Removes a file OR directory entry from its parent (subtree disappears if it's a dir).
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

# Only deletes if the target is a file.
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
	return true

# Deletes a directory and everything inside it (recursive).
# With this tree model, removing the directory entry removes the whole subtree.
func remove_dir_recursive(path: String) -> bool:
	if path == "/" or path.strip_edges() == "":
		return false
	if not is_dir(path):
		return false
	return remove(path)

# Only remove directory if empty (strict)
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

# Reads files and tells you if path is a file or directory #
func is_file(path: String) -> bool:
	if path == "/":
		return false
	var parent := _get_parent_dir(path)
	if parent.is_empty():
		return false
	var name := _base_name(path)
	var children: Dictionary = parent["children"]
	return children.has(name) and children[name].get("type","") == "file"

# Copy helper function #
func copy_file(src: String, dest: String) -> bool:
	if not is_file(src):
		return false

	# dest parent must exist and be a dir
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

# Move command helper function #
func move_file(src: String, dest: String) -> bool:
	# src must be a file
	if not is_file(src):
		return false

	# dest parent must exist as a directory
	var parts := _split_path(dest)
	var parent_path := "/"
	if parts.size() > 1:
		parts.pop_back()
		parent_path = "/" + "/".join(parts)
		if parent_path == "":
			parent_path = "/"

	if not is_dir(parent_path):
		return false

	# move = write new copy then delete original
	var content := read_file(src)
	if not write_file(dest, content):
		return false

	return remove_file(src)

func to_data() -> Dictionary:
	return root

func from_data(data: Dictionary) -> void:
	root = data
