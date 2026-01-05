extends CommandBase
class_name CmdLs

func get_name() -> String:
	return "ls"

func get_help() -> String:
	return "List files and folders in the current, or specified directory."

func get_usage() -> String:
	return "ls [path]"

func get_options() -> Array[Dictionary]:
	return []  # no flags implemented yet

func get_examples() -> Array[String]:
	return [
		"ls",
		"ls /home",
		"ls local"
	]

func get_category() -> String:
	return "FILESYSTEM"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var path := terminal.cwd
	if args.size() >= 1:
		path = terminal.resolve_path(args[0])

	if not terminal.fs.is_dir(path):
		return ["ls: not a directory: " + path]

	var items := terminal.fs.list_dir(path)
	if items.is_empty():
		return []
	return [String("  ").join(items)]
