extends CommandBase
class_name CmdList

func get_name() -> String:
	return "list"

func get_help() -> String:
	return "List things (e.g. saves)."

func get_usage() -> String:
	return "list saves"

func get_examples() -> Array[String]:
	return ["list saves"]

func run(args: Array[String], _terminal: Terminal) -> Array[String]:
	if args.is_empty() or args[0] != "saves":
		return ["list: usage: list saves"]

	var ss := SaveSystem.new()
	var slots := ss.list_slots()
	if slots.is_empty():
		return ["(no saves found)"]
	return ["Saves: " + ", ".join(slots)]
