extends CommandBase
class_name CmdPwd

func get_name() -> String:
	return "pwd"
	
func get_help() -> String:
	return "Print the current working directory."
	
func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	return [_terminal.cwd]
