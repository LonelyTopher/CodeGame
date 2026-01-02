extends CommandBase
class_name CmdTouch

func get_name() -> String:
	return "touch"

func get_help() -> String:
	return "Create an empty file."

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["touch: missing name"]

	var path := terminal.resolve_path(args[0])
	if terminal.fs.touch(path):
		terminal.fs.save_to_user()
		return []
	return ["touch: failed"]
