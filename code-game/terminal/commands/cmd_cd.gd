extends CommandBase
class_name CmdCd

func get_name() -> String:
	return "cd"

func get_help() -> String:
	return "Change the current directory."

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		terminal.cwd = "/home"
		return []

	var target := args[0]
	if target == "..":
		if terminal.cwd == "/":
			return []
		var parts: Array[String] = Array(terminal.cwd.split("/", false))
		parts.pop_back()
		terminal.cwd = "/" if parts.is_empty() else "/" + "/".join(parts)
		return []

	var path := terminal.resolve_path(target)
	if not terminal.fs.is_dir(path):
		return ["cd: no such directory: " + target]

	terminal.cwd = path
	return []
