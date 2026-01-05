extends RefCounted
class_name CommandBase

func get_name() -> String:
	return ""
	
func get_aliases() -> Array[String]:
	return []
	
func get_help() -> String:
	return ""

func get_usage() -> String:
	return get_name()

func get_examples() -> Array[String]:
	return []

func get_options() -> Array[Dictionary]:
	# Each option { "flag": "-r", "long": "--recursive", "desc": "..." }
	return []

# Returns lines to print #
func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	return ["Command not implemented"]

func get_category() -> String:
	return "General"
