extends CommandBase
class_name CmdEcho

func get_name() -> String:
	return "echo"
	
func get_help() -> String:
	return "Echo text back to the user"

func get_usage() -> String:
	return "echo <text...>"

func get_options() -> Array[Dictionary]:
	return []  # no flags implemented yet

func get_examples() -> Array[String]:
	return [
		"echo hello world",
		"echo This is a test",
		"echo one two three"
	]

func get_category() -> String:
	return "GENERAL"

func run(args: Array[String], _terminal: Terminal) -> Array[String]:
	return [String(" ").join(args)]
