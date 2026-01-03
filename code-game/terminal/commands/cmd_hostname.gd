extends CommandBase
class_name CmdHostname

func get_name() -> String:
	return "hostname"

func get_help() -> String:
	return "Print the name of the current host."

func get_usage() -> String:
	return "hostname"

func get_examples() -> Array[String]:
	return [
		"hostname"
	]

func get_options() -> Array[Dictionary]:
	return []

func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	var device: Device = World.current_device
	if device == null:
		return ["hostname: unknown host"]
	return [device.hostname]
