extends CommandBase
class_name CmdIfconfig

func get_name() -> String:
	return "ifconfig"

func get_aliases() -> Array[String]:
	return ["ipconfig"]

func get_help() -> String:
	return "Display IP configuration."

func get_usage() -> String:
	return "ifconfig"

func run(_args: Array[String], terminal: Terminal) -> Array[String]:
	var d: Device = terminal.current_device
	if d == null or not d.online:
		return ["No network interface found."]

	return [
		"Hostname: %s" % d.hostname,
		"IPv4 Address: %s" % d.ip_address,
		"MAC Address: %s" % d.mac
	]
