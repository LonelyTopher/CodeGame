extends CommandBase
class_name CmdScan

func get_name() -> String:
	return "scan"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "List detectable wireless networks."

func get_usage() -> String:
	return "scan"

func get_examples() -> Array[String]:
	return ["scan"]

func get_options() -> Array[Dictionary]:
	return []


func run(_args: Array[String], terminal: Terminal) -> Array[String]:
	var lines: Array[String] = []

	var d: Device = terminal.current_device
	if d == null:
		return ["scan: no active device"]

	var nets: Array = World.get_networks()
	if nets.is_empty():
		return ["scan: no networks found"]

	lines.append("Interface: wlan0")
	lines.append("Scanning...")
	lines.append("")

	# Header
	lines.append("%-20s %4s  %-16s %s" % ["BSSID", "CH", "SECURITY", "SSID"])
	lines.append("--------------------------------------------------------------")

	# Rows
	for n in nets:
		var is_current: bool = (d.network == n)
		var marker: String = "* " if is_current else "  "

		var bssid: String = n.bssid if n.bssid != "" else "??:??:??:??:??:??"
		var ch: int = n.channel
		var sec: String = n.security
		var ssid: String = n.name

		lines.append(
			"%s%-18s %4d  %-16s %s"
			% [marker, bssid, ch, sec, ssid]
		)

	lines.append("")
	lines.append("* = currently connected")

	return lines
