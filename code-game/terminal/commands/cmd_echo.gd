extends CommandBase
class_name CmdEcho

func get_name() -> String:
	return "echo"
	
func get_help() -> String:
	return "Echo text back to the user"
	
func run(args: Array[String], _terminal: Terminal) -> Array[String]:
	return [String(" ").join(args)]
