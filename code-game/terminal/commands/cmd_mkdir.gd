extends CommandBase
class_name CmdMkdir

func get_name() -> String:
	return "mkdir"
	
func get_help() -> String:
	return "Create a new directory."

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["mkdir: missing name"]

	var path := terminal.resolve_path(args[0])
	if terminal.fs.mkdir(path):
		terminal.fs.save_to_user()
		return []
	return ["mkdir: failed"]
