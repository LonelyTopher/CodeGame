extends CommandBase
class_name CmdTouch

func get_name() -> String:
	return "touch"

func get_help() -> String:
	return "Create an empty file."

func get_usage() -> String:
	return "touch <file>"

func get_options() -> Array[Dictionary]:
	return []  # no flags implemented yet

func get_examples() -> Array[String]:
	return [
		"touch file",
		"touch notes.txt",
		"touch script.gd"
	]

func get_category() -> String:
	return "FILESYSTEM"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["touch: missing name"]

	var path := terminal.resolve_path(args[0])
	if terminal.fs.touch(path):
		return []

	return ["touch: failed"]
