extends CommandBase
class_name CmdExit

func get_name() -> String:
	return "exit"

func get_help() -> String:
	return "Exit the current session."

func get_usage() -> String:
	return "exit"

func get_examples() -> Array[String]:
	return [
		"exit"
	]

func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	var stack: Array[Device] = _terminal.device_stack

	if stack.size() <= 1:
		return ["exit: not connected to a remote session"]

	# Remove current device
	stack.pop_back()

	# Restore previous device
	var new_device: Device = stack.back()
	_terminal.current_device = new_device
	_terminal.fs = new_device.fs
	_terminal.cwd = "/home"

	return [
		"Connection closed.",
		"Returned to %s (%s)" % [new_device.hostname, new_device.ip_address]
	]
