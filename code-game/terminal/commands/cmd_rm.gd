extends CommandBase
class_name CmdRm

func get_name() -> String:
	return "rm"

func get_help() -> String:
	return "Remove a file, or a directory with -r."

func get_usage() -> String:
	return "rm [-r] <path>"

func get_examples() -> Array[String]:
	return [
		"rm notes.txt",
		"rm -r projects",
	]

func get_options() -> Array[Dictionary]:
	return [
		{ "flag": "-r", "long": "--recursive", "desc": "Remove directories and their contents recursively." },
	]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["rm: missing operand"]

	var recursive := false
	var target := ""

	# parse args (supports: rm file, rm -r folder, rm -rf folder)
	for a in args:
		if a.begins_with("-") and a.find("r") != -1:
			recursive = true
		elif target == "":
			target = a

	if target == "":
		return ["rm: missing operand"]

	var path := terminal.resolve_path(target)

	# Safety: never allow deleting the jail root (or above it)
	if path == "/home" or path == "/":
		return ["rm: permission denied: " + target]

	if not terminal.fs.exists(path):
		return ["rm: cannot remove '" + target + "': No such file or directory"]

	# If it's a directory, require -r
	if terminal.fs.is_dir(path):
		if not recursive:
			return ["rm: cannot remove '" + target + "': Is a directory (use -r)"]

		var ok_dir: bool = terminal.fs.remove_dir_recursive(path)
		if ok_dir:
			var out: Array[String] = []
			return out
		return ["rm: failed to remove directory: " + target]

	# Otherwise it's a file
	var ok_file: bool = terminal.fs.remove_file(path)
	if ok_file:
		var out2: Array[String] = []
		return out2
	return ["rm: failed to remove file: " + target]
