extends CommandBase
class_name CmdDeleteSave

func get_name() -> String:
	return "delete"

func get_help() -> String:
	return "Delete a saved slot."

func get_usage() -> String:
	return "delete <slot>"

func get_examples() -> Array[String]:
	return ["delete save1"]

func get_category() -> String:
	return "SAVES"

func run(args: Array[String], _terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["delete: missing slot name"]

	var slot := args[0]
	var ss := SaveSystem.new()

	if ss.delete(slot):
		return ["Deleted: " + slot]
	return ["delete: slot not found or delete failed: " + slot]
