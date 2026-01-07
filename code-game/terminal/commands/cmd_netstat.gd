extends CommandBase
class_name CmdNetstat

const MAX_W: int = 125

func get_name() -> String: return "netstat"
func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Print network status, routes, and neighbor cache summary (simulated)."

func get_usage() -> String:
	return "netstat [-i] [-r] [-n] [-s]"

func get_examples() -> Array[String]:
	return [
		"netstat",
		"netstat -i",
		"netstat -r",
		"netstat -n",
		"netstat -i -r -n -s"
	]

func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-i", "long":"--interfaces", "desc":"Show interface status."},
		{"flag":"-r", "long":"--route", "desc":"Show routing table."},
		{"flag":"-n", "long":"--neighbors", "desc":"Show neighbor/ARP cache summary."},
		{"flag":"-s", "long":"--stats", "desc":"Show protocol/stat counters (simulated)."},
	]

func get_category() -> String: return "NETWORK"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var me: Device = World.current_device
	if me == null or me.network == null:
		return ["netstat: no active network interface"]

	# Presentation-only animation (does NOT change any state)
	await _animate_netstat(terminal, MAX_W)

	var net: Network = me.network

	# Default: show everything (nice overview)
	var show_i := false
	var show_r := false
	var show_n := false
	var show_s := false
	var any := false

	for a in args:
		if a == "-i" or a == "--interfaces":
			show_i = true; any = true
		elif a == "-r" or a == "--route":
			show_r = true; any = true
		elif a == "-n" or a == "--neighbors":
			show_n = true; any = true
		elif a == "-s" or a == "--stats":
			show_s = true; any = true

	if not any:
		show_i = true
		show_r = true
		show_n = true
		show_s = true

	var lines: Array[String] = []
	lines.append(_pad("Kernel IP routing table / network status (simulated)", MAX_W))
	lines.append(_pad("-".repeat(MAX_W), MAX_W))

	# Gather basics
	var iface := _get_dev_field_str(me, "iface", "wlan0")
	var my_ip := _get_dev_field_str(me, "ip_address", "--")
	var cidr := str(_get_net_field(net, "subnet", ""))
	var mask := _get_dev_field_str(me, "netmask", _mask_from_cidr(cidr))
	var gw_ip := _gateway_ip_from_net(net)

	# Heartbeat timing (root meta; autoload name doesn't matter)
	var hb := _get_heartbeat_meta()

	# Device online/offline counts
	var counts := _count_devices(net)

	# Section: Interfaces
	if show_i:
		lines.append(_pad("", MAX_W))
		lines.append(_pad("Interface table", MAX_W))
		lines.append(_pad("Iface          Address           Netmask           Status    RX-OK  TX-OK", MAX_W))
		lines.append(_pad(_mini_sep(), MAX_W))

		var status := "UP"
		if "online" in me and bool(me.online) == false:
			status = "DOWN"

		# fake counters (stable-ish per session)
		var rx_ok := _fake_counter("rx_ok", 1200, 9800)
		var tx_ok := _fake_counter("tx_ok", 800,  7600)

		lines.append(_pad(_fmt_cols([
			_iface_col(iface, 14),
			_iface_col(my_ip, 17),
			_iface_col(mask, 17),
			_iface_col(status, 9),
			_iface_col(str(rx_ok), 6),
			_iface_col(str(tx_ok), 6),
		]), MAX_W))

		# Extra context row
		lines.append(_pad("Network: %-24s  Subnet: %-18s  Gateway: %s" % [
			_get_net_field(net, "name", "LAN"),
			(cidr if cidr != "" else "--"),
			(gw_ip if gw_ip != "" else "--")
		], MAX_W))

		# Heartbeat summary row
		lines.append(_pad("Heartbeat: interval=%ss  last=%s  next=%s" % [
			hb["interval_s"],
			hb["last_str"],
			hb["next_str"]
		], MAX_W))

		# Device totals row
		lines.append(_pad("Devices: total=%d  online=%d  offline=%d  locked=%d" % [
			counts["total"], counts["online"], counts["offline"], counts["locked"]
		], MAX_W))

	# Section: Route table
	if show_r:
		lines.append(_pad("", MAX_W))
		lines.append(_pad("Routing table", MAX_W))
		lines.append(_pad("Destination       Gateway           Genmask           Iface   Flags", MAX_W))
		lines.append(_pad(_mini_sep(), MAX_W))

		# Default route (via gateway if present)
		var route_gw := (gw_ip if gw_ip != "" else "0.0.0.0")
		var route_mask := "0.0.0.0"
		var flags := "UG" if gw_ip != "" else "U"
		lines.append(_pad(_fmt_cols([
			_iface_col("0.0.0.0", 17),
			_iface_col(route_gw, 17),
			_iface_col(route_mask, 17),
			_iface_col(iface, 7),
			_iface_col(flags, 5),
		]), MAX_W))

		# Local subnet route
		var subnet_base := _cidr_base(cidr)
		var subnet_mask := _mask_from_cidr(cidr)
		if subnet_base == "":
			subnet_base = "--"
		if subnet_mask == "":
			subnet_mask = "--"

		lines.append(_pad(_fmt_cols([
			_iface_col(subnet_base, 17),
			_iface_col("0.0.0.0", 17),
			_iface_col(subnet_mask, 17),
			_iface_col(iface, 7),
			_iface_col("U", 5),
		]), MAX_W))

	# Section: Neighbor cache summary (ARP cache)
	if show_n:
		lines.append(_pad("", MAX_W))
		lines.append(_pad("Neighbor cache (ARP) summary", MAX_W))
		lines.append(_pad("State       Count   Notes", MAX_W))
		lines.append(_pad(_mini_sep(), MAX_W))

		var arp := _summarize_arp_cache(me, net)
		lines.append(_pad(_kv_row("LOCAL",      arp["LOCAL"],      "this host"), MAX_W))
		lines.append(_pad(_kv_row("PERMANENT",  arp["PERMANENT"],  "gateway/static"), MAX_W))
		lines.append(_pad(_kv_row("REACHABLE",  arp["REACHABLE"],  "recently seen"), MAX_W))
		lines.append(_pad(_kv_row("STALE",      arp["STALE"],      "needs refresh"), MAX_W))
		lines.append(_pad(_kv_row("INCOMPLETE", arp["INCOMPLETE"], "unresolved"), MAX_W))
		lines.append(_pad(_kv_row("FAILED",     arp["FAILED"],     "no response / offline"), MAX_W))

		lines.append(_pad("", MAX_W))
		lines.append(_pad("Cache entries: %d  (arp -a shows all; arp shows active-ish)" % arp["TOTAL"], MAX_W))

	# Section: Stats (simulated)
	if show_s:
		lines.append(_pad("", MAX_W))
		lines.append(_pad("Protocol statistics (simulated)", MAX_W))
		lines.append(_pad(_mini_sep(), MAX_W))

		var icmp_tx: int = _fake_counter("icmp_tx", 10, 240)
		var icmp_rx: int = _fake_counter("icmp_rx",  8, 220)
		var icmp_to: int = maxi(0, icmp_tx - icmp_rx)

		var arp_req := _fake_counter("arp_req",  5, 120)
		var arp_rep := _fake_counter("arp_rep",  3, 110)

		lines.append(_pad("ICMP: echo requests sent=%d  replies received=%d  timeouts=%d" % [icmp_tx, icmp_rx, icmp_to], MAX_W))
		lines.append(_pad("ARP:  who-has sent=%d       is-at received=%d" % [arp_req, arp_rep], MAX_W))
		lines.append(_pad("TCP:  (not implemented)     UDP: (not implemented)", MAX_W))

	lines.append(_pad("", MAX_W))
	return lines


# ------------------------------------------------------------
# Animation (presentation only)
# ------------------------------------------------------------
func _animate_netstat(terminal: Terminal, width: int) -> void:
	if terminal == null or terminal.screen == null:
		return

	var screen = terminal.screen
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var frames := ["|", "/", "-", "\\"]

	# One line that we rewrite in-place
	var base := "[color=lime]netstat:[/color] collecting interface/route/neighbor stats"
	var idx : int = screen.append_line(_pad_bbcode_to_width(base + " ...", width))

	# quick spinner + “sweep” bar
	var steps := 18
	for i in range(steps):
		var spin : String = str(frames[i % frames.size()])
		var fill := int(round(float(i + 1) / float(steps) * 20.0))
		var bar := "[" + "=".repeat(fill) + " ".repeat(20 - fill) + "]"
		var line := "%s  %s  %s" % [base, bar, spin]
		screen.replace_line(idx, _pad_bbcode_to_width(line, width))
		await tree.create_timer(0.06).timeout

	screen.replace_line(idx, _pad_bbcode_to_width("[color=lime]netstat:[/color] done.", width))


# ------------------------------------------------------------
# Heartbeat meta readers
# ------------------------------------------------------------
func _get_heartbeat_meta() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.get_root() if tree != null else null

	var interval_ms := 0
	var last_ms := 0
	var next_ms := 0

	if root != null:
		if root.has_meta("net_hb_interval_ms"):
			interval_ms = int(root.get_meta("net_hb_interval_ms"))
		if root.has_meta("net_hb_last_ms"):
			last_ms = int(root.get_meta("net_hb_last_ms"))
		if root.has_meta("net_hb_next_ms"):
			next_ms = int(root.get_meta("net_hb_next_ms"))

	var now := Time.get_ticks_msec()
	var interval_s := (("%.0f" % (float(interval_ms) / 1000.0)) if interval_ms > 0 else "--")

	# If no heartbeat yet (first ~2 minutes), keep last/next as "--"
	var last_str := "--"
	var next_str := "--"

	if last_ms > 0:
		last_str = _age_str(now - last_ms)

	# If next_ms was never written by heartbeat yet, keep "--"
	if next_ms > 0:
		var until := next_ms - now
		if until < 0:
			until = 0
		next_str = "%ss" % int(ceil(float(until) / 1000.0))

	return {
		"interval_s": interval_s,
		"last_str": last_str,
		"next_str": next_str
	}

func _age_str(delta_ms: int) -> String:
	var s := int(floor(float(delta_ms) / 1000.0))
	if s < 60:
		return "%ss ago" % s
	var m := int(floor(float(s) / 60.0))
	return "%dm ago" % m


# ------------------------------------------------------------
# ARP cache summary (matches your CmdArp cache_map layout)
# ------------------------------------------------------------
func _summarize_arp_cache(me: Device, net: Network) -> Dictionary:
	var iface := _get_dev_field_str(me, "iface", "wlan0")
	var key := "arp_cache|%s|%s" % [str(_get_net_field(net, "subnet", "")), iface]

	var store := {}
	if me.has_meta("arp_cache_map"):
		var v = me.get_meta("arp_cache_map")
		if typeof(v) == TYPE_DICTIONARY:
			store = v

	var cache := {}
	if store.has(key) and typeof(store[key]) == TYPE_DICTIONARY:
		cache = store[key]

	var out := {
		"TOTAL": 0,
		"LOCAL": 0,
		"PERMANENT": 0,
		"REACHABLE": 0,
		"STALE": 0,
		"INCOMPLETE": 0,
		"FAILED": 0,
	}

	for ip in cache.keys():
		var e: Dictionary = cache[ip]
		var st := str(e.get("state", ""))
		out["TOTAL"] += 1
		if out.has(st):
			out[st] += 1

	return out


# ------------------------------------------------------------
# Device counting / lockout awareness
# ------------------------------------------------------------
func _count_devices(net: Network) -> Dictionary:
	var total := 0
	var online := 0
	var offline := 0
	var locked := 0
	var now := Time.get_ticks_msec()

	for d in net.devices:
		if d == null:
			continue
		total += 1

		var is_on := _get_dev_field_bool(d, "online", true)
		if is_on:
			online += 1
		else:
			offline += 1

			# locked if offline_until_ms still in future
			var until := 0
			if d.has_meta("offline_until_ms"):
				until = int(d.get_meta("offline_until_ms"))
			if until > now:
				locked += 1

	return {"total": total, "online": online, "offline": offline, "locked": locked}


# ------------------------------------------------------------
# Route/gateway helpers
# ------------------------------------------------------------
func _gateway_ip_from_net(net: Network) -> String:
	var gw_host := int(_get_net_field(net, "gateway_host", 1))
	for d in net.devices:
		if d == null:
			continue
		var ip := _get_dev_field_str(d, "ip_address", "")
		if ip != "" and _ip_host(ip) == gw_host:
			return ip
	return ""

func _cidr_base(cidr: String) -> String:
	if cidr.find("/") == -1:
		return ""
	return cidr.split("/")[0]


# ------------------------------------------------------------
# Formatting helpers
# ------------------------------------------------------------
func _mini_sep() -> String:
	return "-".repeat(60)

func _kv_row(state: String, count: int, notes: String) -> String:
	return "%-10s  %-5d  %s" % [state, count, notes]

func _fmt_cols(cols: Array[String]) -> String:
	var s := ""
	for c in cols:
		s += c
	return s

func _iface_col(txt: String, w: int) -> String:
	var t := txt
	if t.length() > w:
		t = t.substr(0, w)
	return t + " ".repeat(max(0, w - t.length()))

func _pad(s: String, w: int) -> String:
	if s.length() >= w:
		return s.substr(0, w)
	return s + " ".repeat(w - s.length())


# BBCode width padding (for the animated line)
func _pad_bbcode_to_width(bb: String, width: int) -> String:
	var visible := _bbcode_visible_len(bb)
	if visible >= width:
		return bb
	return bb + " ".repeat(width - visible)

func _bbcode_visible_len(bb: String) -> int:
	var re := RegEx.new()
	re.compile("\\[/?color[^\\]]*\\]")
	return re.sub(bb, "", true).length()


# ------------------------------------------------------------
# Tiny deterministic-ish counters
# ------------------------------------------------------------
func _fake_counter(tag: String, a: int, b: int) -> int:
	var h := 0
	for i in tag.length():
		h += int(tag.unicode_at(i))
	var r := int((Time.get_ticks_msec() / 1000) % 997)
	var v := (h * 31 + r * 17) % (b - a + 1)
	return a + v


# ------------------------------------------------------------
# Safe field readers
# ------------------------------------------------------------
func _get_dev_field_str(d: Object, field: String, fallback: String) -> String:
	if d == null:
		return fallback
	if field in d:
		var v = d.get(field)
		if v == null:
			return fallback
		var s := str(v)
		return fallback if s == "" else s
	if d.has_meta(field):
		var mv = d.get_meta(field)
		if mv == null:
			return fallback
		var ms := str(mv)
		return fallback if ms == "" else ms
	return fallback

func _get_dev_field_bool(d: Object, field: String, fallback: bool) -> bool:
	if d == null:
		return fallback
	if field in d:
		var v = d.get(field)
		if typeof(v) == TYPE_BOOL:
			return bool(v)
		var s := str(v).to_lower()
		if s == "true": return true
		if s == "false": return false
	if d.has_meta(field):
		var mv = d.get_meta(field)
		if typeof(mv) == TYPE_BOOL:
			return bool(mv)
		var ms := str(mv).to_lower()
		if ms == "true": return true
		if ms == "false": return false
	return fallback

func _get_net_field(net: Object, field: String, fallback):
	if net == null:
		return fallback
	if field in net:
		var v = net.get(field)
		return fallback if v == null else v
	if net.has_meta(field):
		var mv = net.get_meta(field)
		return fallback if mv == null else mv
	return fallback


# ------------------------------------------------------------
# IP + mask helpers
# ------------------------------------------------------------
func _ip_host(ip: String) -> int:
	var parts := ip.split(".")
	if parts.size() != 4:
		return -1
	return int(parts[3])

func _mask_from_cidr(cidr: String) -> String:
	if cidr.find("/") == -1:
		return "255.255.255.0"
	var bits := int(cidr.split("/")[1])
	if bits == 24:
		return "255.255.255.0"
	if bits == 16:
		return "255.255.0.0"
	if bits == 8:
		return "255.0.0.0"
	return "255.255.255.0"
