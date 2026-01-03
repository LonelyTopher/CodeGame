extends CommandBase
class_name CmdMkdir

func get_name() -> String:
	return "mkdir"

func get_help() -> String:
	return "Create a new directory."

func get_usage() -> String:
	return "mkdir <directory>"

func get_options() -> Array[Dictionary]:
	return []  # no flags implemented yet

func get_examples() -> Array[String]:
	return [
		"mkdir local",
		"mkdir projects",
		"mkdir data"
	]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["mkdir: missing name"]

	var path := terminal.resolve_path(args[0])
	if terminal.fs.mkdir(path):
		return []

	return ["mkdir: failed"]
