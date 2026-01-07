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

# Aging (ms)
const STALE_AFTER_MS := 25_000
const FAIL_AFTER_MS  := 70_000

func get_name() -> String: return "arp"
func get_aliases() -> Array[String]: return []
func get_help() -> String: return "Display the ARP/neighbor table for the current network interface."
func get_usage() -> String: return "arp [-a] [--scan|-scan]"
func get_examples() -> Array[String]:
	return ["arp", "arp -a", "arp --scan", "arp --scan -a"]

func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-a", "long":"--all", "desc":"Display all known ARP entries (including STALE/FAILED/INCOMPLETE)."},
		{"flag":"--scan", "long":"-scan", "desc":"Probe devices on the LAN to populate/refresh ARP entries."},
	]

func get_category() -> String: return "NETWORK"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var me: Device = World.current_device
	if me == null or me.network == null:
		return ["arp: no active network interface"]

	var net: Network = me.network

	var show_all := false
	var do_scan := false
	for a in args:
		if a == "-a" or a == "--all":
			show_all = true
		elif a == "--scan" or a == "-scan" or a == "-s":
			do_scan = true

	var total_w: int = MAX_TABLE_W

	# Presentation-only "reading" animation
	if terminal != null and terminal.screen != null:
		await _animate_probe(terminal, total_w)

	# Load persistent neighbor cache (THIS is what ping updates)
	var cache: Dictionary = _get_arp_cache(me, net)

	# Ensure local + gateway exist in cache
	var cidr: String = str(_get_net_field(net, "subnet", ""))
	var default_mask: String = _mask_from_cidr(cidr)
	var local_iface: String = _get_dev_field_str(me, "iface", "wlan0")

	_add_or_refresh_local(cache, me, default_mask, local_iface)
	_add_or_refresh_gateway(cache, me, net, default_mask, local_iface)

	# Age entries over time (REACHABLE -> STALE -> FAILED)
	_age_cache(cache, me, net)

	# Optional scan: "touch" devices and update cache
	if do_scan:
		await _probe_lan(cache, me, net, default_mask, local_iface)

	# Save after modifications/aging/scan
	_save_arp_cache(me, net, cache)

	# ---- Dynamic column positions ----
	var addr_pos  := MIN_ADDR_POS
	var type_pos  := maxi(MIN_TYPE_POS,  int(total_w * 0.20))
	var hw_pos    := maxi(MIN_HW_POS,    int(total_w * 0.30))
	var state_pos := maxi(MIN_STATE_POS, int(total_w * 0.52))
	var flags_pos := maxi(MIN_FLAGS_POS, int(total_w * 0.66))
	var mask_pos  := maxi(MIN_MASK_POS,  int(total_w * 0.74))
	var iface_pos := maxi(MIN_IFACE_POS, int(total_w * 0.88))

	type_pos  = maxi(type_pos,  addr_pos + 10)
	hw_pos    = maxi(hw_pos,    type_pos + 6)
	state_pos = maxi(state_pos, hw_pos + 14)
	flags_pos = maxi(flags_pos, state_pos + 8)
	mask_pos  = maxi(mask_pos,  flags_pos + 6)
	iface_pos = maxi(iface_pos, mask_pos + 8)

	var lines: Array[String] = []

	lines.append(_compose_line(total_w, {
		addr_pos:  "Address",
		type_pos:  "HWtype",
		hw_pos:    "HWaddress",
		state_pos: "State",
		flags_pos: "Flags",
		mask_pos:  "Mask",
		iface_pos: "Iface",
	}))

	# Sort keys by IP
	var ips: Array = cache.keys()
	ips.sort_custom(func(a, b) -> bool:
		return _ip_to_int(str(a)) < _ip_to_int(str(b))
	)

	for ip_v in ips:
		var ip := str(ip_v)
		var e: Dictionary = cache.get(ip, {})

		var st := str(e.get("state", "--"))
		var mac := str(e.get("mac", "--"))

		if not show_all:
			# Default view: show active-ish entries only
			# Include STALE too if you want it visible by default — up to you.
			if st != "LOCAL" and st != "PERMANENT" and st != "REACHABLE":
				continue
			if st == "--" and mac == "--":
				continue

		lines.append(_compose_line(total_w, {
			addr_pos:  ip,
			type_pos:  str(e.get("hwtype", "--")),
			hw_pos:    str(e.get("mac", "--")).to_lower(),
			state_pos: st,
			flags_pos: str(e.get("flags", "--")),
			mask_pos:  str(e.get("mask", "--")),
			iface_pos: str(e.get("iface", "--")),
		}))

	return lines


# ============================================================
# Cache maintenance (local + gateway)
# ============================================================
func _add_or_refresh_local(cache: Dictionary, me: Device, default_mask: String, local_iface: String) -> void:
	var ip := _get_dev_field_str(me, "ip_address", "")
	if ip == "":
		return

	var now := Time.get_ticks_msec()
	var state := "LOCAL"

	cache[ip] = {
		"hwtype": _get_dev_field_str(me, "hwtype", "--"),
		"mac": _get_dev_field_str(me, "mac", "--"),
		"state": state,
		"flags": _resolve_flags(me, state, true, false),
		"mask": _get_dev_field_str(me, "netmask", default_mask),

		# ✅ LOCAL device uses its own iface
		"iface": _get_dev_field_str(me, "iface", local_iface),

		"last_seen_ms": now,
	}


func _add_or_refresh_gateway(cache: Dictionary, me: Device, net: Network, default_mask: String, local_iface: String) -> void:
	var gw_ip := _find_gateway_ip(net)
	if gw_ip == "":
		return

	var now := Time.get_ticks_msec()
	var gw_dev := _find_device_by_ip(net, gw_ip)
	var state := "PERMANENT"

	# preserve existing iface if present (so we don't overwrite with local)
	var prev: Dictionary = {}
	if cache.has(gw_ip) and typeof(cache[gw_ip]) == TYPE_DICTIONARY:
		prev = cache[gw_ip]
		
	var gw_iface: String = str(prev.get("iface", local_iface))
	var mac: String = str(prev.get("mac", "--"))
	var hwtype: String = str(prev.get("hwtype", "ether"))

	if gw_dev != null:
		mac = _get_dev_field_str(gw_dev, "mac", mac)
		hwtype = _get_dev_field_str(gw_dev, "hwtype", hwtype)

		# ✅ GATEWAY shows its own iface if you set it
		gw_iface = _get_dev_field_str(gw_dev, "iface", gw_iface)

	cache[gw_ip] = {
		"hwtype": hwtype,
		"mac": mac,
		"state": state,
		"flags": _resolve_flags(gw_dev if gw_dev != null else me, state, false, true),
		"mask": default_mask,

		# ✅ store gateway iface
		"iface": gw_iface,

		"last_seen_ms": now,
	}


func _age_cache(cache: Dictionary, me: Device, net: Network) -> void:
	var now := Time.get_ticks_msec()
	var my_ip := _get_dev_field_str(me, "ip_address", "")

	for ip_v in cache.keys():
		var ip := str(ip_v)
		var e: Dictionary = cache.get(ip, {})
		var st := str(e.get("state", ""))

		if st == "PERMANENT" or st == "LOCAL":
			continue

		var last := int(e.get("last_seen_ms", 0))
		if last <= 0:
			continue

		var age := now - last
		if age >= FAIL_AFTER_MS:
			e["state"] = "FAILED"
		elif age >= STALE_AFTER_MS:
			if st != "INCOMPLETE":
				e["state"] = "STALE"

		var state2 := str(e.get("state", st))
		var d := _find_device_by_ip(net, ip)
		var is_gateway := _is_gateway_ip(net, ip)
		var is_local := (ip == my_ip)

		# ✅ IMPORTANT: do NOT overwrite iface during aging.
		# Keep existing iface, or best-effort refresh from device if known.
		if d != null:
			e["iface"] = _get_dev_field_str(d, "iface", str(e.get("iface", "--")))

		e["flags"] = _resolve_flags(d if d != null else me, state2, is_local, is_gateway)
		cache[ip] = e


# ============================================================
# Probe / scan simulation (fills cache)
# ============================================================
func _probe_lan(cache: Dictionary, me: Device, net: Network, default_mask: String, local_iface: String) -> void:
	var my_ip := _get_dev_field_str(me, "ip_address", "")

	for d in net.devices:
		if d == null:
			continue

		var ip := _get_dev_field_str(d, "ip_address", "")
		if ip == "" or ip == my_ip:
			continue

		var is_gateway := _is_gateway_ip(net, ip)

		# ✅ show TARGET device iface (not me.iface)
		var target_iface := _get_dev_field_str(d, "iface", local_iface)

		# New entry starts as INCOMPLETE
		if not cache.has(ip):
			var init_state := "INCOMPLETE"
			cache[ip] = {
				"hwtype": _get_dev_field_str(d, "hwtype", "--"),
				"mac": "--",
				"state": init_state,
				"flags": _resolve_flags(d, init_state, false, is_gateway),
				"mask": _get_dev_field_str(d, "netmask", default_mask),

				# ✅ store target iface
				"iface": target_iface,

				"last_seen_ms": Time.get_ticks_msec(),
			}

		await _sleep(0.03 + randf() * 0.06)

		var online := _get_dev_field_bool(d, "online", true)
		if online:
			var new_state := "PERMANENT" if is_gateway else "REACHABLE"
			var now := Time.get_ticks_msec()

			var e: Dictionary = cache.get(ip, {})
			e["mac"] = _get_dev_field_str(d, "mac", "--")
			e["hwtype"] = _get_dev_field_str(d, "hwtype", "--")
			e["state"] = new_state
			e["flags"] = _resolve_flags(d, new_state, false, is_gateway)
			e["mask"] = _get_dev_field_str(d, "netmask", default_mask)

			# ✅ keep target iface
			e["iface"] = target_iface

			e["last_seen_ms"] = now
			cache[ip] = e
		else:
			var e2: Dictionary = cache.get(ip, {})
			e2["state"] = "INCOMPLETE"
			e2["flags"] = _resolve_flags(d, "INCOMPLETE", false, is_gateway)
			e2["last_seen_ms"] = Time.get_ticks_msec()

			# ✅ keep target iface even if offline
			e2["iface"] = target_iface

			cache[ip] = e2


# ============================================================
# Gateway helpers
# ============================================================
func _find_gateway_ip(net: Network) -> String:
	var gw_host := int(_get_net_field(net, "gateway_host", 1))
	for d in net.devices:
		if d == null:
			continue
		var ip := _get_dev_field_str(d, "ip_address", "")
		if ip != "" and _ip_host(ip) == gw_host:
			return ip
	return ""

func _is_gateway_ip(net: Network, ip: String) -> bool:
	var gw_host := int(_get_net_field(net, "gateway_host", 1))
	return _ip_host(ip) == gw_host

func _find_device_by_ip(net: Network, ip: String) -> Device:
	for d in net.devices:
		if d == null:
			continue
		if _get_dev_field_str(d, "ip_address", "") == ip:
			return d
	return null


# ============================================================
# Persistent cache I/O (stored on current Device)
# ============================================================
func _arp_cache_key(net: Network, iface: String) -> String:
	var subnet := str(_get_net_field(net, "subnet", ""))
	return "arp_cache|%s|%s" % [subnet, iface]

func _get_arp_cache(me: Device, net: Network) -> Dictionary:
	var iface := _get_dev_field_str(me, "iface", "wlan0")
	var key := _arp_cache_key(net, iface)
	var meta_key := "arp_cache_map"

	var store := {}
	if me.has_meta(meta_key):
		var v = me.get_meta(meta_key)
		if typeof(v) == TYPE_DICTIONARY:
			store = v

	if store.has(key) and typeof(store[key]) == TYPE_DICTIONARY:
		return store[key]

	var fresh: Dictionary = {}
	store[key] = fresh
	me.set_meta(meta_key, store)
	return fresh

func _save_arp_cache(me: Device, net: Network, cache: Dictionary) -> void:
	var iface := _get_dev_field_str(me, "iface", "wlan0")
	var key := _arp_cache_key(net, iface)
	var meta_key := "arp_cache_map"

	var store := {}
	if me.has_meta(meta_key):
		var v = me.get_meta(meta_key)
		if typeof(v) == TYPE_DICTIONARY:
			store = v

	store[key] = cache
	me.set_meta(meta_key, store)


# ============================================================
# Flags resolver (explicit -> derived)
# ============================================================
func _resolve_flags(d: Object, state: String, is_local: bool, is_gateway: bool) -> String:
	var explicit := _get_dev_field_str(d, "arp_flags", "")
	if explicit != "" and explicit != "--":
		return explicit

	var has_c := false
	var has_p := false
	var has_l := false
	var has_i := false
	var has_s := false
	var has_f := false

	if state == "INCOMPLETE":
		has_i = true
	elif state == "STALE":
		has_s = true
		has_c = true
	elif state == "FAILED":
		has_f = true
	else:
		has_c = true

	if state == "PERMANENT" or is_gateway:
		has_p = true
		has_c = true

	if is_local:
		has_l = true

	var out := ""
	if has_c: out += "C"
	if has_p: out += "P"
	if has_l: out += "L"
	if has_s: out += "S"
	if has_i: out += "I"
	if has_f: out += "F"
	return out


# ============================================================
# Animation / timing
# ============================================================
func _animate_probe(terminal: Terminal, width: int) -> void:
	var screen = terminal.screen
	var frames := [
		"[          ]", "[=         ]", "[==        ]", "[===       ]",
		"[====      ]", "[=====     ]", "[======    ]", "[=======   ]",
		"[========  ]", "[========= ]", "[==========]"
	]
	var base := "[color=lime]arp:[/color] reading neighbor cache..."
	var idx: int = screen.append_line(_pad_bbcode_to_width(base, width))
	for f in frames:
		var line := "%s  %s" % [base, f]
		screen.replace_line(idx, _pad_bbcode_to_width(line, width))
		await screen.get_tree().create_timer(0.05).timeout
	screen.replace_line(idx, _pad_bbcode_to_width("[color=lime]arp:[/color] done.", width))

func _sleep(sec: float) -> void:
	await Engine.get_main_loop().create_timer(sec).timeout


# ============================================================
# Formatting helpers
# ============================================================
func _compose_line(width: int, placements: Dictionary) -> String:
	var buf := " ".repeat(width)
	var keys := placements.keys()
	keys.sort()
	for k in keys:
		buf = _write_at(buf, int(k), str(placements[k]))
	return buf

func _write_at(line: String, pos: int, text: String) -> String:
	if pos < 0 or pos >= line.length():
		return line
	var max_len := line.length() - pos
	var t := text
	if t.length() > max_len:
		t = t.substr(0, max_len)
	return line.substr(0, pos) + t + line.substr(pos + t.length())

func _pad_bbcode_to_width(bb: String, width: int) -> String:
	var visible := _bbcode_visible_len(bb)
	if visible >= width:
		return bb
	return bb + " ".repeat(width - visible)

func _bbcode_visible_len(bb: String) -> int:
	var re := RegEx.new()
	re.compile("\\[/?color[^\\]]*\\]")
	return re.sub(bb, "", true).length()


# ============================================================
# Safe field readers
# ============================================================
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
		if s == "true":
			return true
		if s == "false":
			return false
	if d.has_meta(field):
		var mv = d.get_meta(field)
		if typeof(mv) == TYPE_BOOL:
			return bool(mv)
		var ms := str(mv).to_lower()
		if ms == "true":
			return true
		if ms == "false":
			return false
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


# ============================================================
# IP helpers
# ============================================================
func _ip_to_int(ip: String) -> int:
	var parts := ip.split(".")
	if parts.size() != 4:
		return 0
	return int(parts[0]) * 16777216 + int(parts[1]) * 65536 + int(parts[2]) * 256 + int(parts[3])

func _ip_host(ip: String) -> int:
	var parts := ip.split(".")
	if parts.size() != 4:
		return -1
	return int(parts[3])

func _mask_from_cidr(cidr: String) -> String:
	if cidr.find("/") == -1:
		return "--"
	var bits := int(cidr.split("/")[1])
	if bits == 24:
		return "255.255.255.0"
	if bits == 16:
		return "255.255.0.0"
	if bits == 8:
		return "255.0.0.0"
	return "--"
