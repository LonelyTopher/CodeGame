extends CommandBase
class_name CmdArp

func get_name() -> String:
	return "arp"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Display the ARP table for the current network."

func get_usage() -> String:
	return "arp [-a]"

func get_examples() -> Array[String]:
	return [
		"arp",
		"arp -a"
	]

func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-a", "long":"--all", "desc":"Display all known ARP entries."}
	]

func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	var device: Device = World.current_device
	if device == null or device.network == null:
		return ["arp: no active network interface"]

	var net: Network = device.network
	var lines: Array[String] = []

	lines.append("Address              HWtype  HWaddress           Flags Mask            Iface")

	for d in net.devices:
		if d.ip_address == "":
			continue

		lines.append("%-20s ether   %-18s C                     eth0" % [
			d.ip_address,
			d.mac.to_lower()
		])

	return lines
