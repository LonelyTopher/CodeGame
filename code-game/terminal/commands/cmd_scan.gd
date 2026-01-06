extends CommandBase
class_name CmdScan

const MAX_TABLE_W: int = 125
const IFACE_DEFAULT: String = "wlan0"

# Minimum column start positions (char offsets) - tuned for 125 width
const MIN_INUSE_POS  := 0
const MIN_SSID_POS   := 8
const MIN_MODE_POS   := 36
const MIN_CHAN_POS   := 48
const MIN_RATE_POS   := 55
const MIN_SIGNAL_POS := 69
const MIN_BARS_POS   := 78
const MIN_SEC_POS    := 86
const MIN_BSSID_POS  := 104

func get_name() -> String: return "scan"
func get_aliases() -> Array[String]: return []
func get_help() -> String: return "Scan for nearby Wi-Fi networks (nmcli-style)."
func get_usage() -> String: return "scan [-a] [-i <iface>]"
func get_examples() -> Array[String]: return ["scan", "scan -a", "scan -i wlan0"]
func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-a", "long":"--all", "desc":"Show all visible networks (including hidden)."},
		{"flag":"-i", "long":"--iface", "desc":"Interface to scan with (default: wlan0)."},
	]
func get_category() -> String: return "NETWORK"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var d: Device = terminal.current_device
	if d == null:
		return ["scan: no active device"]

	# Flags
	var show_all := false
	var iface := IFACE_DEFAULT
	var i := 0
	while i < args.size():
		var a := args[i]
		if a == "-a" or a == "--all":
			show_all = true
		elif a == "-i" or a == "--iface":
			if i + 1 < args.size():
				iface = args[i + 1]
				i += 1
		i += 1

	# Hard-set table width like your ARP command
	var total_w: int = MAX_TABLE_W

	# ---- async scan animation ----
	if terminal != null and terminal.screen != null:
		await _animate_scan(terminal, iface, total_w)

	# Get networks
	var nets: Array = World.get_networks()
	if nets.is_empty():
		return ["scan: no networks found"]

	# -------------------------------------------------
	# Neighbor window:
	#   show only: (current_id - 3) .. (current_id + 1)
	#   never more than +1 above current
	# -------------------------------------------------
	var has_current_neighbor := false
	var current_neighbor_id: int = 0

	if d.network != null and ("neighbor_id" in d.network):
		current_neighbor_id = int(d.network.neighbor_id)
		has_current_neighbor = true

	# ---- Dynamic column positions (ratio-based, with minimums) ----
	# These ratios are tuned so BSSID still fits inside 125.
	var inuse_pos  := MIN_INUSE_POS
	var ssid_pos   := maxi(MIN_SSID_POS,   int(total_w * 0.07))
	var mode_pos   := maxi(MIN_MODE_POS,   int(total_w * 0.29))
	var chan_pos   := maxi(MIN_CHAN_POS,   int(total_w * 0.39))
	var rate_pos   := maxi(MIN_RATE_POS,   int(total_w * 0.45))
	var signal_pos := maxi(MIN_SIGNAL_POS, int(total_w * 0.56))
	var bars_pos   := maxi(MIN_BARS_POS,   int(total_w * 0.63))
	var sec_pos    := maxi(MIN_SEC_POS,    int(total_w * 0.69))
	var bssid_pos  := maxi(MIN_BSSID_POS,  int(total_w * 0.83))

	# Ensure ordering so nothing collides (like ARP)
	ssid_pos   = maxi(ssid_pos,   inuse_pos + 8)
	mode_pos   = maxi(mode_pos,   ssid_pos + 10)
	chan_pos   = maxi(chan_pos,   mode_pos + 6)
	rate_pos   = maxi(rate_pos,   chan_pos + 5)
	signal_pos = maxi(signal_pos, rate_pos + 6)
	bars_pos   = maxi(bars_pos,   signal_pos + 7)
	sec_pos    = maxi(sec_pos,    bars_pos + 6)
	bssid_pos  = maxi(bssid_pos,  sec_pos + 10)

	var bssid_header := "BSSID"
	var min_bssid_space: Variant = max(bssid_header.length(), 17)
	if bssid_pos > total_w - min_bssid_space:
		bssid_pos = total_w - min_bssid_space
		bssid_pos = maxi(bssid_pos, sec_pos + 10)

	var lines: Array[String] = []

	# Header
	var header_plain := _compose_line(total_w, {
		inuse_pos:  "IN-USE",
		ssid_pos:   "SSID",
		mode_pos:   "MODE",
		chan_pos:   "CHAN",
		rate_pos:   "RATE",
		signal_pos: "SIGNAL",
		bars_pos:   "BARS",
		sec_pos:    "SECURITY",
		bssid_pos:  "BSSID",
	})
	lines.append("[color=lime]%s[/color]" % header_plain)
	var sep_w := total_w - 4
	lines.append("[color=lime]%s[/color]" % "-".repeat(sep_w))

	# Rows
	for n in nets:
		# Neighbor filtering (only if we actually have a current network neighbor_id)
		if has_current_neighbor and ("neighbor_id" in n):
			var nid := int(n.neighbor_id)

			# Only allow: current-3 .. current+1
			if nid > current_neighbor_id + 1:
				continue
			if nid < current_neighbor_id - 3:
				continue

		var ssid := _safe_field(n, "name", "--")
		if ssid == "":
			ssid = "--"

		# Hide "hidden" networks unless -a
		if not show_all:
			var low := ssid.to_lower()
			if low == "hidden" or ssid == "--":
				continue

		var in_use := " "
		if d.network == n:
			in_use = "*"

		var bssid := _safe_field(n, "bssid", "--:--:--:--:--:--")
		var ch := _safe_field(n, "channel", "--")
		var security := _safe_field(n, "security", "--")

		var mode := _safe_field(n, "mode", "--")
		var rate := _safe_field(n, "rate", "--")

		# -------------------------------------------------
		# NEW: signal/bars based on neighbor distance
		# -------------------------------------------------
		var signal_str := "--"
		var bars := "--"

		if has_current_neighbor and ("neighbor_id" in n):
			var nid2 := int(n.neighbor_id)

			var bars_count := _bars_for_neighbor(current_neighbor_id, nid2, d.network == n)
			bars = _bars_glyph(bars_count)
			signal_str = "%d%%" % _percent_for_bars(bars_count)

		lines.append(_compose_line(total_w, {
			inuse_pos:  in_use,
			ssid_pos:   ssid,
			mode_pos:   mode,
			chan_pos:   ch,
			rate_pos:   rate,
			signal_pos: signal_str,
			bars_pos:   bars,
			sec_pos:    security,
			bssid_pos:  bssid,
		}))

	lines.append("")
	lines.append("[color=lime]*[/color] = currently connected")

	return lines


# -----------------------------
# Neighbor -> bars logic
# -----------------------------
func _bars_for_neighbor(current_id: int, nid: int, is_current: bool) -> int:
	# current network is always 4 bars
	if is_current:
		return 4

	# Only one ABOVE is visible; give it 3 bars (feels realistic)
	if nid == current_id + 1:
		return 3

	# Below current: drop 1 bar per step (down to 1)
	# current-1 => 3, current-2 => 2, current-3 => 1
	if nid <= current_id:
		var diff := current_id - nid
		return clamp(4 - diff, 1, 4)

	# Fallback
	return 1

func _bars_glyph(count: int) -> String:
	# 4-bar style; reads clean in monospace terminal output
	# 4 => ▂▄▆█, 3 => ▂▄▆, 2 => ▂▄, 1 => ▂
	match clamp(count, 0, 4):
		4: return "▂▄▆█"
		3: return "▂▄▆ "
		2: return "▂▄  "
		1: return "▂   "
		_: return "--"

func _percent_for_bars(count: int) -> int:
	match clamp(count, 0, 4):
		4: return 100
		3: return 75
		2: return 50
		1: return 25
		_: return 0


# -----------------------------
# Async animation helper
# -----------------------------
func _animate_scan(terminal: Terminal, iface: String, width: int) -> void:
	var screen = terminal.screen

	var frames := [
		"[          ]", "[=         ]", "[==        ]", "[===       ]",
		"[====      ]", "[=====     ]", "[======    ]", "[=======   ]",
		"[========  ]", "[========= ]", "[==========]"
	]

	var base := "[color=lime]scan:[/color] scanning with %s..." % iface

	var idx: int = screen.append_line(_pad_bbcode_to_width(base, width))

	for f in frames:
		var line := "%s  %s" % [base, f]
		screen.replace_line(idx, _pad_bbcode_to_width(line, width))
		await screen.get_tree().create_timer(0.05).timeout

	screen.replace_line(idx, _pad_bbcode_to_width("[color=lime]scan:[/color] done.", width))


# -----------------------------
# Formatting helpers (same style as your ARP)
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


# Pads BBCode to a fixed VISIBLE width (so [color] tags don't mess up spacing)
func _pad_bbcode_to_width(bb: String, width: int) -> String:
	var visible := _bbcode_visible_len(bb)
	if visible >= width:
		return bb
	return bb + " ".repeat(width - visible)

func _bbcode_visible_len(bb: String) -> int:
	var re := RegEx.new()
	re.compile("\\[/?color[^\\]]*\\]")
	var stripped := re.sub(bb, "", true)
	return stripped.length()


# -----------------------------
# Safe field helpers
# -----------------------------
func _safe_field(obj, field: String, fallback: String) -> String:
	if obj == null:
		return fallback

	if typeof(obj) == TYPE_DICTIONARY:
		return str(obj.get(field, fallback))

	if field in obj:
		return str(obj.get(field))

	return fallback
