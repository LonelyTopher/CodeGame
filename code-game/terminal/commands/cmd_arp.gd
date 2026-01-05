extends CommandBase
class_name CmdArp

const MAX_TABLE_W: int = 125

# Minimum column start positions (in characters)
const MIN_ADDR_POS  := 0
const MIN_TYPE_POS  := 20
const MIN_HW_POS    := 28
const MIN_STATE_POS := 52
const MIN_FLAGS_POS := 70
const MIN_MASK_POS  := 80
const MIN_IFACE_POS := 110

func get_name() -> String: return "arp"
func get_aliases() -> Array[String]: return []
func get_help() -> String: return "Display the ARP/neighbor table for the current network interface."
func get_usage() -> String: return "arp [-a]"
func get_examples() -> Array[String]: return ["arp", "arp -a"]
func get_options() -> Array[Dictionary]:
	return [{"flag":"-a", "long":"--all", "desc":"Display all known ARP entries."}]
func get_category() -> String: return "NETWORK"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var device: Device = World.current_device
	if device == null or device.network == null:
		return ["arp: no active network interface"]

	var show_all := false
	for a in args:
		if a == "-a" or a == "--all":
			show_all = true

	# We are hard-setting the ARP table width to 150 chars.
	var total_w: int = MAX_TABLE_W

	# ---- async "probing" animation (pure presentation) ----
	if terminal != null and terminal.screen != null:
		await _animate_probe(terminal, total_w)

	# ---- Dynamic column positions (ratio-based, with minimums) ----
	var addr_pos  := MIN_ADDR_POS
	var type_pos  := maxi(MIN_TYPE_POS,  int(total_w * 0.20))
	var hw_pos    := maxi(MIN_HW_POS,    int(total_w * 0.30))
	var state_pos := maxi(MIN_STATE_POS, int(total_w * 0.52))
	var flags_pos := maxi(MIN_FLAGS_POS, int(total_w * 0.66))
	var mask_pos  := maxi(MIN_MASK_POS,  int(total_w * 0.74))
	var iface_pos := maxi(MIN_IFACE_POS, int(total_w * 0.88))

	# Ensure ordering so nothing collides
	type_pos  = maxi(type_pos,  addr_pos + 10)
	hw_pos    = maxi(hw_pos,    type_pos + 6)
	state_pos = maxi(state_pos, hw_pos + 14)
	flags_pos = maxi(flags_pos, state_pos + 8)
	mask_pos  = maxi(mask_pos,  flags_pos + 6)
	iface_pos = maxi(iface_pos, mask_pos + 8)

	var lines: Array[String] = []

	# Header
	lines.append(_compose_line(total_w, {
		addr_pos:  "Address",
		type_pos:  "HWtype",
		hw_pos:    "HWaddress",
		state_pos: "State",
		flags_pos: "Flags",
		mask_pos:  "Mask",
		iface_pos: "Iface",
	}))

	# Rows
	var net: Network = device.network
	for d in net.devices:
		if d.ip_address == "":
			continue

		# If you later add these fields to Device, they’ll show automatically:
		var hwtype := "ether"
		var mac := d.mac.to_lower() if d.mac != "" else "--"

		var state := "--"
		if "neighbor_state" in d and str(d.neighbor_state) != "":
			state = str(d.neighbor_state)

		var flags := "C" if mac != "--" else "--"
		if "arp_flags" in d and str(d.arp_flags) != "":
			flags = str(d.arp_flags)

		var mask := "--"
		if "netmask" in d and str(d.netmask) != "":
			mask = str(d.netmask)

		var iface := "eth0"
		if "iface" in d and str(d.iface) != "":
			iface = str(d.iface)
		elif "iface" in device and str(device.iface) != "":
			iface = str(device.iface)

		lines.append(_compose_line(total_w, {
			addr_pos:  d.ip_address,
			type_pos:  hwtype,
			hw_pos:    mac,
			state_pos: state,
			flags_pos: flags,
			mask_pos:  mask,
			iface_pos: iface,
		}))

	return lines


# -----------------------------
# Async animation helper
# -----------------------------
func _animate_probe(terminal: Terminal, width: int) -> void:
	var screen = terminal.screen

	var frames := [
		"[          ]", "[=         ]", "[==        ]", "[===       ]",
		"[====      ]", "[=====     ]", "[======    ]", "[=======   ]",
		"[========  ]", "[========= ]", "[==========]"
	]

	var base := "[color=lime]arp:[/color] scanning neighbor cache..."

	# Append one line, then keep overwriting it
	var idx: int = screen.append_line(_pad_bbcode_to_width(base, width))

	for f in frames:
		var line := "%s  %s" % [base, f]
		screen.replace_line(idx, _pad_bbcode_to_width(line, width))
		await screen.get_tree().create_timer(0.05).timeout

	screen.replace_line(idx, _pad_bbcode_to_width("[color=lime]arp:[/color] done.", width))


# -----------------------------
# Formatting helpers (your working system)
# -----------------------------
func _compose_line(width: int, placements: Dictionary) -> String:
	var buf := " ".repeat(width)

	var keys := placements.keys()
	keys.sort()

	for k in keys:
		var pos := int(k)
		var text := str(placements[k])
		buf = _write_at(buf, pos, text)

	return buf


func _write_at(line: String, pos: int, text: String) -> String:
	if pos < 0:
		return line
	if pos >= line.length():
		return line

	var max_len := line.length() - pos
	var t := text
	if t.length() > max_len:
		t = t.substr(0, max_len)

	return line.substr(0, pos) + t + line.substr(pos + t.length())


# Pads a BBCode string to a fixed VISIBLE width (so [color] tags don't mess up spacing)
func _pad_bbcode_to_width(bb: String, width: int) -> String:
	var visible := _bbcode_visible_len(bb)
	if visible >= width:
		return bb
	return bb + " ".repeat(width - visible)


func _bbcode_visible_len(bb: String) -> int:
	# Strip just the BBCode tags we’re using so the visible length is accurate
	# This keeps the animation padding stable.
	var re := RegEx.new()
	re.compile("\\[/?color[^\\]]*\\]")
	var stripped := re.sub(bb, "", true)
	return stripped.length()
