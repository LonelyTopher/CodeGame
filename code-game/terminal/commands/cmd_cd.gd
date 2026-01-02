extends CommandBase
class_name CmdCd

func get_name() -> String:
	return "cd"

func get_help() -> String:
	return "Change the current directory. ('cd ..' to go back 1 directory)"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
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
		return ["cd: no such directory: " + target]

	terminal.cwd = path
	return []
