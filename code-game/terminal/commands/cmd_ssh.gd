extends CommandBase
class_name CmdSSH

func get_name() -> String:
	return "ssh"

func get_help() -> String:
	return "Connect to a remote device via SSH."

func get_usage() -> String:
	return "ssh <ip>"

func get_examples() -> Array[String]:
	return [
		"ssh 10.42.7.2"
	]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["ssh: missing ip address"]

	var ip := args[0]

	var current: Device = terminal.current_device
	if current == null:
		return ["ssh: no active device"]

	if current.network == null:
		return ["ssh: not connected to a network"]

	# Find target device on the same network
	var target: Device = null
	for d in current.network.devices:
		if d.ip_address == ip:
			target = d
			break

	if target == null:
		return ["ssh: could not resolve host " + ip]

	if target == current:
		return ["ssh: already connected to this device"]

	# Push new SSH session
	terminal.current_device = target
	terminal.device_stack.append(target)
	terminal.fs = target.fs
	terminal.cwd = "/home"


	return [
		"Connecting to %s..." % ip,
		"Connected to %s (%s)" % [target.hostname, target.ip_address],
		""
	]
