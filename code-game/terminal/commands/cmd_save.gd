extends CommandBase
class_name CmdSave

func get_name() -> String:
	return "save"

func get_help() -> String:
	return "Save the current state to a slot (default: save1)."

func get_usage() -> String:
	return "save [slot]"

func get_examples() -> Array[String]:
	return ["save", "save save1", "save autosave"]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var slot := "save1"
	if args.size() >= 1:
		slot = args[0]

	var ss := SaveSystem.new()

	# Full save (same as the button): terminal + device + player + stats
	if ss.save_game(slot, terminal):
		return ["[color=lime]" + slot + " saved successfully.[/color]"]

	return ["save: failed"]
