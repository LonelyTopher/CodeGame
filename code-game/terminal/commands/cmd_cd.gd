extends CommandBase
class_name CmdCd

func get_name() -> String:
	return "cd"

func get_help() -> String:
	return "Change the current directory. ('cd ..' to go back 1 directory)"

func get_usage() -> String:
	return "cd [path]"

func get_options() -> Array[Dictionary]:
	return []

func get_category() -> String:
	return "FILESYSTEM"

func get_examples() -> Array[String]:
	return [
		"cd             # go to /home",
		"cd ..          # go up one directory",
		"cd projects    # enter a folder in the current directory",
		"cd /home       # go to an absolute path"
	]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if terminal == null or terminal.fs == null:
		return ["cd: no filesystem available"]

	# cd → go home
	if args.is_empty():
		terminal.cwd = "/home"
		return []

	var target := args[0]

	# cd ..
	if target == "..":
		if terminal.cwd == "/home":
			return []

		var parts: Array[String] = []
		for p in terminal.cwd.split("/", false):
			parts.append(String(p))

		parts.pop_back()
		terminal.cwd = "/" if parts.is_empty() else "/" + "/".join(parts)
		return []

	# cd <path>
	var path := terminal.resolve_path(target)

	if not terminal.fs.is_dir(path):
		return ["cd: no such file or directory: " + target]

	# 🔒 Locked directory check
	if terminal.fs.has_method("is_locked") and terminal.fs.is_locked(path):
		# If your FS stores extra metadata, we can surface a hint
		var hint := ""
		if terminal.fs.has_method("_get_node"):
			var node := terminal.fs._get_node(path)
			if typeof(node) == TYPE_DICTIONARY and not (node as Dictionary).is_empty():
				hint = String((node as Dictionary).get("hint", ""))

		if hint != "":
			return ["cd: access denied: directory is locked (%s)" % hint]

		return ["cd: access denied: directory is locked (password required)"]

	terminal.cwd = path
	return []
