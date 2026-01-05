extends CommandBase
class_name CmdPwd

func get_name() -> String:
	return "pwd"

func get_help() -> String:
	return "Print the current working directory."

func get_usage() -> String:
	return "pwd"

func get_options() -> Array[Dictionary]:
	return []  # pwd has no flags

func get_examples() -> Array[String]:
	return [
		"pwd"
	]

func get_category() -> String:
	return "FILESYSTEM"

func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	return [_terminal.cwd]
