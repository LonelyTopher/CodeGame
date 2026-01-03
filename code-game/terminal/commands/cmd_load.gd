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

	var data := ss.load_slot(slot)
	if data.is_empty():
		return ["load: failed"]

	# Restore terminal filesystem/cwd
	ss.apply_terminal_state(terminal, data)

	# Restore player device identity (MAC/IP/hostname)
	var dev_state: Variant = data.get("player_device", {})
	if typeof(dev_state) == TYPE_DICTIONARY:
		World.apply_player_device_state(dev_state as Dictionary)

	return ["Loaded: " + slot]
