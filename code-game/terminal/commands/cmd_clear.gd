extends CommandBase
class_name CmdClear

func get_name() -> String:
	return "clear"
	
func get_help() -> String:
	return "Clear the terminal output window"
	
func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	return ["__CLEAR__"]
