extends CommandBase
class_name CmdScan

# -----------------------------
# Tweakables
# -----------------------------
const MAX_TABLE_W: int = 150 # tweak this
const IFACE_DEFAULT := "wlan0"

# Column min positions (char offsets)
const MIN_INUSE_POS  := 0
const MIN_SSID_POS   := 4
const MIN_MODE_POS   := 34
const MIN_CHAN_POS   := 44
const MIN_RATE_POS   := 51
const MIN_SIGNAL_POS := 63
const MIN_BARS_POS   := 73
const MIN_SEC_POS    := 80
const MIN_BSSID_POS  := 100

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
	for i in range(args.size()):
		var a := args[i]
		if a == "-a" or a == "--all":
			show_all = true
		elif a == "-i" or a == "--iface":
			if i + 1 < args.size():
				iface = args[i + 1]

	# Width clamp
	var w: int = MAX_TABLE_W
	if terminal != null:
		w = clampi(int(terminal.term_width), 70, MAX_TABLE_W)

	# ---- async scan animation ----
	if terminal != null and terminal.screen != null:
		await _animate_scan(terminal, iface, w)

	# Get networks
	var nets: Array = World.get_networks()
	if nets.is_empty():
		return ["scan: no networks found"]

	# Build dynamic column positions based on width
	var inuse_pos  := MIN_INUSE_POS
	var ssid_pos   := maxi(MIN_SSID_POS,   int(w * 0.03))
	var mode_pos   := maxi(MIN_MODE_POS,   int(w * 0.26))
	var chan_pos   := maxi(MIN_CHAN_POS,   int(w * 0.34))
	var rate_pos   := maxi(MIN_RATE_POS,   int(w * 0.40))
	var signal_pos := maxi(MIN_SIGNAL_POS, int(w * 0.49))
	var bars_pos   := maxi(MIN_BARS_POS,   int(w * 0.56))
	var sec_pos    := maxi(MIN_SEC_POS,    int(w * 0.62))
	var bssid_pos  := maxi(MIN_BSSID_POS,  int(w * 0.77))

	# Ensure ordering
	ssid_pos   = maxi(ssid_pos,   inuse_pos + 4)
	mode_pos   = maxi(mode_pos,   ssid_pos + 10)
	chan_pos   = maxi(chan_pos,   mode_pos + 6)
	rate_pos   = maxi(rate_pos,   chan_pos + 4)
	signal_pos = maxi(signal_pos, rate_pos + 6)
	bars_pos   = maxi(bars_pos,   signal_pos + 4)
	sec_pos    = maxi(sec_pos,    bars_pos + 4)
	bssid_pos  = maxi(bssid_pos,  sec_pos + 8)

	var lines: Array[String] = []

	# Header
	# Header
	# Header (build plain, then color the whole line so tags never get truncated)
	var header_plain := _compose_line(w, {
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

	lines.append("[color=lime]%s[/color]" % "-".repeat(w))



	# Rows
	for n in nets:
		# SSID
		var ssid := _safe_field(n, "name", "--")
		if ssid == "":
			ssid = "--"

		# Hide "hidden" networks unless -a
		if not show_all:
			var low := ssid.to_lower()
			if low == "hidden" or ssid == "--":
				continue

		# In-use marker
		var in_use := " "
		if d.network == n:
			in_use = "*"

		# Fields (fallback to dashes)
		var bssid := _safe_field(n, "bssid", "--:--:--:--:--:--")
		var ch := _safe_field(n, "channel", "--")
		var security := _safe_field(n, "security", "--")

		# These likely don’t exist yet — keep placeholders
		var mode := _safe_field(n, "mode", "--")   # e.g. Infra (later)
		var rate := _safe_field(n, "rate", "--")   # e.g. 54 Mbit/s (later)

		# SIGNAL / BARS intentionally not implemented yet
		var signal_str := "--"
		var bars := "--"

		lines.append(_compose_line(w, {
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

	# Footer
	lines.append("")
	lines.append("[color=lime]*[/color] = currently connected")

	return lines


# -----------------------------
# Async animation helper
# -----------------------------
func _animate_scan(terminal: Terminal, iface: String, width: int) -> void:
	var screen = terminal.screen

	var idx: int = screen.append_line(_pad_to_width("[color=lime]scan:[/color] initializing %s..." % iface, width))
	await screen.get_tree().create_timer(0.12).timeout

	var frames := ["[          ]", "[=         ]", "[==        ]", "[===       ]",
		"[====      ]", "[=====     ]", "[======    ]", "[=======   ]",
		"[========  ]", "[========= ]", "[==========]"]

	for f in frames:
		screen.replace_line(idx, _pad_to_width("[color=lime]scan:[/color] scanning...  %s" % f, width))
		await screen.get_tree().create_timer(0.05).timeout

	screen.replace_line(idx, _pad_to_width("[color=lime]scan:[/color] done.", width))


# -----------------------------
# Formatting helpers (fixed-width placement)
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
	if pos < 0 or pos >= line.length():
		return line

	var max_len := line.length() - pos
	var t := text
	if t.length() > max_len:
		t = t.substr(0, max_len)

	return line.substr(0, pos) + t + line.substr(pos + t.length())

func _pad_to_width(s: String, width: int) -> String:
	# Cosmetic padding for the animated status line.
	if s.length() >= width:
		return s.substr(0, width)
	return s + " ".repeat(width - s.length())


# -----------------------------
# Safe field helpers
# -----------------------------
func _safe_field(obj, field: String, fallback: String) -> String:
	if obj == null:
		return fallback

	if typeof(obj) == TYPE_DICTIONARY:
		return str(obj.get(field, fallback))

	# If it's a Godot object with properties, this pattern is safe-ish:
	if field in obj:
		return str(obj.get(field))

	return fallback
