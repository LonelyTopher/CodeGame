extends CommandBase
class_name CmdLoad

func get_name() -> String:
	return "load"

func get_help() -> String:
	return "Load a saved slot."

func get_usage() -> String:
	return "load <slot>"

func get_examples() -> Array[String]:
	return ["load autosave", "load save1"]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["load: missing slot name"]

	var slot := args[0]
	var ss := SaveSystem.new()

	if not ss.exists(slot):
		return ["load: slot not found: " + slot]

	if ss.load_terminal(slot, terminal):
		return ["Loaded: " + slot]
	return ["load: failed"]
