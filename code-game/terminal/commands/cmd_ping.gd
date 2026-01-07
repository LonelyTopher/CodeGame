extends CommandBase
class_name CmdPing

# Aging rules (ms)
const REACHABLE_TO_STALE_MS := 60_000

func get_name() -> String: return "ping"
func get_aliases() -> Array[String]: return []
func get_help() -> String: return "Send ICMP ECHO_REQUEST to network hosts (simulated)."
func get_usage() -> String: return "ping [-c count] <ip|hostname|gateway|router>"
func get_examples() -> Array[String]:
	return [
		"ping 192.168.77.1",
		"ping -c 4 12.146.72.6",
		"ping gateway",
		"ping router"
	]
func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-c", "long":"--count", "desc":"Number of echo requests to send (default: 4)."}
	]
func get_category() -> String: return "NETWORK"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var me: Device = World.current_device
	if me == null or me.network == null:
		return ["ping: no active network interface"]

	# -----------------------------
	# Parse args
	# -----------------------------
	var count := 4
	var target_str := ""

	var i := 0
	while i < args.size():
		var a := str(args[i])
		if a == "-c" or a == "--count":
			if i + 1 >= args.size():
				return ["ping: option requires an argument -- c", get_usage()]
			count = int(args[i + 1])
			i += 2
			continue
		if target_str == "":
			target_str = a
		i += 1

	if target_str == "":
		return ["ping: missing target", get_usage()]
	if count <= 0:
		count = 1

	var net: Network = me.network

	# -----------------------------
	# Resolve aliases
	# -----------------------------
	var token := target_str.strip_edges()
	var token_l := token.to_lower()
	if token_l == "gateway" or token_l == "router":
		var gw_ip := _gateway_ip_from_net(net)
		if gw_ip != "":
			token = gw_ip

	# -----------------------------
	# Resolve target (ip or hostname)
	# -----------------------------
	var target_dev: Device = _find_device_by_ip_or_hostname(net, token)
	var target_ip := ""
	if target_dev != null:
		target_ip = _get_dev_field_str(target_dev, "ip_address", "")
	else:
		# allow raw IP even if not known
		target_ip = token

	if target_ip == "":
		return ["ping: unknown host: %s" % target_str]

	# -----------------------------
	# Load the SAME ARP cache that CmdArp reads
	# -----------------------------
	var cache := _get_arp_cache(me, net)
	_apply_aging(cache, me, net)
	_save_arp_cache(me, net, cache)

	# -----------------------------
	# Output mode
	# -----------------------------
	var live := (terminal != null and terminal.screen != null)
	var out: Array[String] = []

	var header := "PING %s (%s): 56 data bytes" % [target_str, target_ip]
	if live:
		terminal.screen.append_line(header)
	else:
		out.append(header)

	# Like real systems: create/mark INCOMPLETE before first attempt
	_mark_incomplete(cache, me, net, target_ip, target_dev)
	_save_arp_cache(me, net, cache)

	# -----------------------------
	# Ping loop
	# -----------------------------
	var sent := 0
	var received := 0
	var times: Array[float] = []

	var seq := 1
	while seq <= count:
		sent += 1
		if live:
			await _sleep(0.18 + randf() * 0.12)

		var ok := false
		var rtt_ms := 0.0

		if target_dev != null:
			ok = _get_dev_field_bool(target_dev, "online", true)
		else:
			# Unknown device -> treat as unreachable for now
			ok = false

		if ok:
			rtt_ms = _fake_latency_ms(me, target_dev)
			times.append(rtt_ms)
			received += 1

			_mark_reachable(cache, me, net, target_ip, target_dev)
			_save_arp_cache(me, net, cache)

			var line_ok := "64 bytes from %s: icmp_seq=%d ttl=64 time=%.1f ms" % [target_ip, seq, rtt_ms]
			if live:
				terminal.screen.append_line(line_ok)
			else:
				out.append(line_ok)
		else:
			_touch_seen(cache, target_ip)
			_save_arp_cache(me, net, cache)

			var line_to := "Request timeout for icmp_seq %d" % seq
			if live:
				terminal.screen.append_line(line_to)
			else:
				out.append(line_to)

		seq += 1

	# -----------------------------
	# Summary
	# -----------------------------
	var loss := 0
	if sent > 0:
		loss = int(round((1.0 - float(received) / float(sent)) * 100.0))

	var summary1 := "\n--- %s ping statistics ---" % target_str
	var summary2 := "%d packets transmitted, %d received, %d%% packet loss" % [sent, received, loss]

	var summary3 := ""
	if times.size() > 0:
		var minv := times[0]
		var maxv := times[0]
		var sum := 0.0
		for t in times:
			minv = min(minv, t)
			maxv = max(maxv, t)
			sum += t
		var avgv := sum / float(times.size())
		summary3 = "round-trip min/avg/max = %.1f/%.1f/%.1f ms" % [minv, avgv, maxv]

	if live:
		terminal.screen.append_line(summary1)
		terminal.screen.append_line(summary2)
		if summary3 != "":
			terminal.screen.append_line(summary3)
		return []
	else:
		out.append(summary1)
		out.append(summary2)
		if summary3 != "":
			out.append(summary3)
		return out


# ============================================================
# Cache storage (MATCH CmdArp: arp_cache_map + subnet/iface key)
# ============================================================
func _arp_cache_key(net: Network, iface: String) -> String:
	var subnet := str(_get_net_field(net, "subnet", ""))
	return "arp_cache|%s|%s" % [subnet, iface]

func _get_arp_cache(me: Object, net: Network) -> Dictionary:
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

func _save_arp_cache(me: Object, net: Network, cache: Dictionary) -> void:
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
# Aging / degradation
# ============================================================
func _apply_aging(cache: Dictionary, me: Device, net: Network) -> void:
	var now := Time.get_ticks_msec()
	var my_ip := _get_dev_field_str(me, "ip_address", "")

	for ip_v in cache.keys():
		var ip := str(ip_v)
		var e: Dictionary = cache[ip]
		var state := str(e.get("state", ""))

		if state == "PERMANENT" or state == "LOCAL":
			continue

		var last_seen := int(e.get("last_seen_ms", 0))
		if last_seen <= 0:
			continue

		var age := now - last_seen

		if state == "REACHABLE" and age >= REACHABLE_TO_STALE_MS:
			e["state"] = "STALE"
			var is_gw := _is_gateway_ip(net, ip)
			var is_local := (ip == my_ip)
			e["flags"] = _resolve_flags_from_state(e, is_local, is_gw)

		cache[ip] = e


# ============================================================
# ARP entry transitions caused by ping
# ============================================================
func _touch_seen(cache: Dictionary, ip: String) -> void:
	if not cache.has(ip):
		cache[ip] = {}
	cache[ip]["last_seen_ms"] = Time.get_ticks_msec()

func _mark_incomplete(cache: Dictionary, me: Device, net: Network, ip: String, target_dev: Device) -> void:
	var now := Time.get_ticks_msec()
	if not cache.has(ip):
		cache[ip] = {}

	var e: Dictionary = cache[ip]

	# Keep known hwtype/mac if already known
	if str(e.get("hwtype", "")) == "":
		e["hwtype"] = _get_dev_field_str(target_dev, "hwtype", "--") if target_dev != null else "--"
	if str(e.get("mac", "")) == "":
		e["mac"] = "--"

	e["iface"] = _get_dev_field_str(me, "iface", "wlan0")
	e["mask"] = _mask_from_cidr(str(_get_net_field(net, "subnet", "")))
	e["last_seen_ms"] = now

	var is_gw := _is_gateway_ip(net, ip)
	e["state"] = "PERMANENT" if is_gw else "INCOMPLETE"
	e["flags"] = _resolve_flags(target_dev, str(e.get("state", "")), false, is_gw)

	cache[ip] = e

func _mark_reachable(cache: Dictionary, me: Device, net: Network, ip: String, target_dev: Device) -> void:
	var now := Time.get_ticks_msec()
	if not cache.has(ip):
		cache[ip] = {}

	var e: Dictionary = cache[ip]

	if target_dev != null:
		e["hwtype"] = _get_dev_field_str(target_dev, "hwtype", "--")
		e["mac"] = _get_dev_field_str(target_dev, "mac", "--")

	e["iface"] = _get_dev_field_str(me, "iface", "wlan0")
	e["mask"] = _mask_from_cidr(str(_get_net_field(net, "subnet", "")))
	e["last_seen_ms"] = now
	e["resolved_ms"] = now

	var is_gw := _is_gateway_ip(net, ip)
	e["state"] = "PERMANENT" if is_gw else "REACHABLE"
	e["flags"] = _resolve_flags(target_dev, str(e.get("state", "")), false, is_gw)

	cache[ip] = e


# ============================================================
# Flag resolution
# ============================================================
func _resolve_flags(d: Device, state: String, is_local: bool, is_gateway: bool) -> String:
	if d != null:
		var explicit := _get_dev_field_str(d, "arp_flags", "")
		if explicit != "" and explicit != "--":
			return explicit

	var flags := ""
	if state == "INCOMPLETE":
		flags = "I"
	elif state == "STALE":
		flags = "CS"
	else:
		flags = "C"

	if state == "PERMANENT" or is_gateway:
		if flags.find("C") == -1: flags += "C"
		if flags.find("P") == -1: flags += "P"

	if is_local:
		if flags.find("L") == -1: flags += "L"

	return flags

func _resolve_flags_from_state(e: Dictionary, is_local: bool, is_gateway: bool) -> String:
	var state := str(e.get("state", ""))
	var flags := ""
	if state == "INCOMPLETE":
		flags = "I"
	elif state == "STALE":
		flags = "CS"
	else:
		flags = "C"

	if state == "PERMANENT" or is_gateway:
		if flags.find("C") == -1: flags += "C"
		if flags.find("P") == -1: flags += "P"

	if is_local:
		if flags.find("L") == -1: flags += "L"

	return flags


# ============================================================
# Resolution + latency simulation
# ============================================================
func _find_device_by_ip_or_hostname(net: Network, token: String) -> Device:
	var t := token.strip_edges()

	for d in net.devices:
		if d == null:
			continue
		var ip := _get_dev_field_str(d, "ip_address", "")
		if ip != "" and ip == t:
			return d

	for d2 in net.devices:
		if d2 == null:
			continue
		var hn := _get_dev_field_str(d2, "hostname", "")
		if hn != "" and hn.to_lower() == t.to_lower():
			return d2

	return null

func _fake_latency_ms(me: Device, target: Device) -> float:
	var base := 6.0 + randf() * 10.0
	var my_hw := _get_dev_field_str(me, "hwtype", "")
	var t_hw := _get_dev_field_str(target, "hwtype", "") if target != null else ""

	if my_hw == "wifi" or t_hw == "wifi":
		base += 6.0 + randf() * 12.0
	if my_hw == "cell" or t_hw == "cell":
		base += 18.0 + randf() * 30.0

	return base


# ============================================================
# Net/gateway helpers
# ============================================================
func _gateway_ip_from_net(net: Network) -> String:
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

func _ip_host(ip: String) -> int:
	var parts := ip.split(".")
	if parts.size() != 4:
		return -1
	return int(parts[3])

func _mask_from_cidr(cidr: String) -> String:
	if cidr.find("/") == -1:
		return "255.255.255.0"
	var bits := int(cidr.split("/")[1])
	if bits == 24: return "255.255.255.0"
	if bits == 16: return "255.255.0.0"
	if bits == 8:  return "255.0.0.0"
	return "255.255.255.0"


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


# ============================================================
# Async helper
# ============================================================
func _sleep(sec: float) -> void:
	await Engine.get_main_loop().create_timer(sec).timeout
