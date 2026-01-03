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
	var state := ss.build_terminal_state(terminal)

	# Add player device network identity
	state["player_device"] = World.get_player_device_state()

	if ss.save(slot, state):
		return ["Saved: " + slot]

	return ["save: failed"]
