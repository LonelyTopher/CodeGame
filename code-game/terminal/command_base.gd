extends RefCounted
class_name CommandBase

func get_name() -> String:
	return ""
	
func get_aliases() -> Array[String]:
	return []
	
func get_help() -> String:
	return ""

func get_usage() -> String:
	return ""

# Returns lines to print #
func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	return ["Not implemented"]
