extends CommandBase
class_name CmdConnect

func get_name() -> String:
	return "connect"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Connect to a wireless network (SSID)."

func get_usage() -> String:
	return "connect <ssid>"

func get_examples() -> Array[String]:
	return [
		"connect HomeNet",
		"connect CoffeeShopWiFi"
	]

func get_options() -> Array[Dictionary]:
	return []

func get_category() -> String:
	return "NETWORK"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var d: Device = terminal.current_device
	if d == null:
		return ["connect: no active device"]

	if args.size() != 1:
		return ["usage: " + get_usage()]

	var ssid := args[0]

	# Get all known networks in the world
	var nets: Array = World.get_networks()
	if nets == null or nets.is_empty():
		return ["connect: no networks available"]

	var target: Network = null
	for n in nets:
		if String(n.name) == ssid:
			target = n
			break

	if target == null:
		return ["connect: network not found: " + ssid]

	if d.network == target:
		return ["connect: already connected to " + ssid]

	# Disconnect from current network (if any)
	if d.network != null:
		d.detach_from_network()

	# Attach to new network (this assigns IP)
	d.attach_to_network(target)

	var lines: Array[String] = []
	lines.append("Connecting to '%s'..." % ssid)
	lines.append("Network: %s" % target.subnet)
	lines.append("Assigned IP address: %s" % d.ip_address)
	lines.append("")
	lines.append("Hint: run 'arp' to discover devices on this network.")

	return lines
