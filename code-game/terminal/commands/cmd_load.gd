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

	# Full load (same as the button): terminal + device + player + stats
	var ok := ss.load_game(slot, terminal)
	if not ok:
		return ["load: failed"]

	return ["[color=lime]Loaded: " + slot + "[/color]"]
