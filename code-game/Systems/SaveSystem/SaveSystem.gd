extends RefCounted
class_name SaveSystem

const SAVE_DIR := "user://saves"

# -------------------------------------------------
# Core save / load helpers
# -------------------------------------------------

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _path_for(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]

func save(slot: String, state: Dictionary) -> bool:
	_ensure_dir()
	var path := _path_for(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return true

func load_slot(slot: String) -> Dictionary:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var txt := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func exists(slot: String) -> bool:
	return FileAccess.file_exists(_path_for(slot))

func delete(slot: String) -> bool:
	var path := _path_for(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

func list_slots() -> Array[String]:
	_ensure_dir()
	var out: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			out.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# -------------------------------------------------
# Autoload helper (SaveSystem is RefCounted)
# IMPORTANT: Your autoload is named "World" (per screenshot)
# -------------------------------------------------

func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.get_root()
	return root.get_node_or_null("/root/%s" % name)


# -------------------------------------------------
# Terminal filesystem state (view state only)
# NOTE: We still save this for "where was I / prompt state"
# Full device filesystem persistence happens in World state.
# -------------------------------------------------

func build_terminal_state(term: Terminal) -> Dictionary:
	if term == null:
		return {}
	return {
		"cwd": term.cwd
	}

func apply_terminal_state(term: Terminal, state: Dictionary) -> bool:
	if term == null:
		return false
	if state.is_empty():
		return false

	term.cwd = String(state.get("cwd", "/home"))
	# Keep cwd valid if fs exists
	if term.fs != null and not term.fs.is_dir(term.cwd):
		term.cwd = "/home"
		if term.fs != null and not term.fs.is_dir("/home"):
			term.fs.mkdir("/home")

	return true


# -------------------------------------------------
# Device serialization helpers
# -------------------------------------------------

func _build_device_state(d) -> Dictionary:
	if d == null:
		return {}

	var fs_data: Dictionary = {}
	if d.fs != null and d.fs.has_method("to_data"):
		fs_data = d.fs.to_data()

	return {
		# Identity
		"hostname": String(d.hostname),
		"mac": String(d.mac),

		# Network state
		"ip_address": String(d.ip_address),
		"online": bool(d.online),

		# Gameplay / hacking-ish fields you already have
		"hack_chance": float(d.hack_chance),
		"hack_xp_first": int(d.hack_xp_first),
		"hack_xp_repeat": int(d.hack_xp_repeat),
		"was_hacked": bool(d.was_hacked),

		# Filesystem (THIS is where your money files / ledger changes persist)
		"fs": fs_data
	}

func _apply_device_state(d, state: Dictionary) -> bool:
	if d == null or state.is_empty():
		return false

	if state.has("hostname"):
		d.hostname = String(state.get("hostname", d.hostname))
	if state.has("mac"):
		d.mac = String(state.get("mac", d.mac))

	if state.has("ip_address"):
		d.ip_address = String(state.get("ip_address", d.ip_address))
	if state.has("online"):
		d.online = bool(state.get("online", d.online))

	if state.has("hack_chance"):
		d.hack_chance = float(state.get("hack_chance", d.hack_chance))
	if state.has("hack_xp_first"):
		d.hack_xp_first = int(state.get("hack_xp_first", d.hack_xp_first))
	if state.has("hack_xp_repeat"):
		d.hack_xp_repeat = int(state.get("hack_xp_repeat", d.hack_xp_repeat))
	if state.has("was_hacked"):
		d.was_hacked = bool(state.get("was_hacked", d.was_hacked))

	var fs_state: Variant = state.get("fs", {})
	if typeof(fs_state) == TYPE_DICTIONARY:
		if d.fs == null:
			d.fs = FileSystem.new()
		d.fs.from_data(fs_state as Dictionary)

	return true


# -------------------------------------------------
# Network serialization helpers
# -------------------------------------------------

func _build_network_state(n) -> Dictionary:
	if n == null:
		return {}

	# We intentionally do NOT save passwords.
	# We save "was_hacked" (aka known/owned) so it auto-reconnects after load.
	return {
		"ssid": String(n.name),
		"was_hacked": bool(n.was_hacked)
	}

func _apply_network_state(n, state: Dictionary) -> void:
	if n == null or state.is_empty():
		return
	if state.has("was_hacked"):
		n.was_hacked = bool(state.get("was_hacked", n.was_hacked))


# -------------------------------------------------
# World / Networks / Devices state (THE IMPORTANT PART)
# Saves ALL devices and their filesystems + network "known" state
# + reconnects the player's network by SSID.
# -------------------------------------------------

func build_world_state() -> Dictionary:
	var world = _autoload("World")
	if world == null:
		return {}

	# Networks
	var nets: Array = []
	if world.has_method("get_networks"):
		nets = world.get_networks()
	elif world.has("networks"):
		nets = world.networks

	var networks_state: Dictionary = {} # ssid -> state
	for n in nets:
		if n == null:
			continue
		networks_state[String(n.name)] = _build_network_state(n)

	# Devices
	var devices_by_mac: Dictionary = {} # mac -> device_state
	var device_net_by_mac: Dictionary = {} # mac -> ssid (best-effort)

	for n in nets:
		if n == null:
			continue
		var n_devices: Array = []
		if "devices" in n:
			n_devices = n.devices


		for d in n_devices:
			if d == null:
				continue
			var mac := String(d.mac)
			if mac == "":
				continue
			if not devices_by_mac.has(mac):
				devices_by_mac[mac] = _build_device_state(d)
				device_net_by_mac[mac] = String(n.name)

	# Player/current device pointers + network reconnect hint
	var player_mac := ""
	var current_mac := ""
	var player_connected_ssid := ""

	if "player_device" in world and world.player_device != null:
		player_mac = String(world.player_device.mac)
		if world.player_device.network != null and ("name" in world.player_device.network):
			player_connected_ssid = String(world.player_device.network.name)

	if ("current_device" in world) and world.current_device != null:
		current_mac = String(world.current_device.mac)

	return {
		"player_mac": player_mac,
		"current_mac": current_mac,
		"player_connected_ssid": player_connected_ssid,
		"networks": networks_state,
		"devices": devices_by_mac,
		"device_network_hint": device_net_by_mac
	}

func apply_world_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var world = _autoload("World")
	if world == null:
		return false

	# Get live networks
	var nets: Array = []
	if world.has_method("get_networks"):
		nets = world.get_networks()
	elif world.has("networks"):
		nets = world.networks

	# Apply network states (was_hacked, etc.)
	var saved_networks: Variant = state.get("networks", {})
	if typeof(saved_networks) == TYPE_DICTIONARY:
		for n in nets:
			if n == null:
				continue
			var ssid := String(n.name)
			if (saved_networks as Dictionary).has(ssid):
				var ns: Variant = (saved_networks as Dictionary)[ssid]
				if typeof(ns) == TYPE_DICTIONARY:
					_apply_network_state(n, ns as Dictionary)

	# Build lookup of currently-existing devices by MAC
	var live_by_mac: Dictionary = {}
	for n in nets:
		if n == null:
			continue
			
		for d in n.devices:
			if d == null:
				continue
			var mac := String(d.mac)
			if mac != "":
				live_by_mac[mac] = d

	# Apply device states
	var saved_devices: Variant = state.get("devices", {})
	if typeof(saved_devices) != TYPE_DICTIONARY:
		return false

	for mac_key in (saved_devices as Dictionary).keys():
		var mac := String(mac_key)
		if not live_by_mac.has(mac):
			continue
		var d = live_by_mac[mac]
		var d_state: Variant = (saved_devices as Dictionary)[mac_key]
		if typeof(d_state) == TYPE_DICTIONARY:
			_apply_device_state(d, d_state as Dictionary)

	# Restore player/current pointers
	var player_mac := String(state.get("player_mac", ""))
	var current_mac := String(state.get("current_mac", ""))

	if player_mac != "" and live_by_mac.has(player_mac) and world.has_method("register_player_device"):
		world.register_player_device(live_by_mac[player_mac])

	if current_mac != "" and live_by_mac.has(current_mac) and world.has_method("set_current_device"):
		world.set_current_device(live_by_mac[current_mac])

	# Auto-reconnect player to last known SSID (if network is "known"/was_hacked)
	var target_ssid := String(state.get("player_connected_ssid", ""))
	if target_ssid != "" and world.has_method("get_network_by_ssid"):
		var net = world.get_network_by_ssid(target_ssid)
		if net != null and bool(net.was_hacked):
			if world.player_device != null:
				# Attach player device back onto the network.
				# This re-assigns IP (your Device.attach_to_network handles it).
				world.player_device.attach_to_network(net)

	# Refresh assigned_ips dictionaries to match device.ip_address (avoid stale mappings)
	_refresh_network_ip_maps(nets)

	return true

func _refresh_network_ip_maps(nets: Array) -> void:
	for n in nets:
		if n == null:
			continue

		var new_map: Dictionary = {}
		for d in n.devices:
			if d == null:
				continue

			var ip := String(d.ip_address)
			if ip != "":
				new_map[d] = ip

		n.assigned_ips = new_map

# -------------------------------------------------
# Player progression state (PlayerBase)
# -------------------------------------------------

func build_player_progress_state() -> Dictionary:
	var player = _autoload("PlayerBase")
	if player == null:
		return {}

	return {
		"level": int(player.level),
		"xp": int(player.xp),
		"currencies": player.build_currency_state()
	}

func apply_player_progress_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var player = _autoload("PlayerBase")
	if player == null:
		return false

	var lv := int(state.get("level", player.level))
	var xp := int(state.get("xp", player.xp))

	lv = clamp(lv, 1, 50)
	xp = max(xp, 0)

	player.level = lv
	player.xp = xp

	var cur_state: Variant = state.get("currencies", {})
	if typeof(cur_state) == TYPE_DICTIONARY:
		player.apply_currency_state(cur_state as Dictionary)

	if player.has_signal("player_xp_changed"):
		player.emit_signal("player_xp_changed", player.xp, player.level)

	return true


# -------------------------------------------------
# Stats progression state (StatsSystem -> StatBase instances)
# -------------------------------------------------

func build_stats_progress_state() -> Dictionary:
	var stats_system = _autoload("StatsSystem")
	if stats_system == null:
		return {}

	var out: Dictionary = {}
	var stats_dict: Dictionary = stats_system.stats

	for stat_id in stats_dict.keys():
		var stat = stats_dict[stat_id]
		if stat == null:
			continue

		out[String(stat_id)] = {
			"level": int(stat.level),
			"xp": int(stat.xp)
		}

	return out

func apply_stats_progress_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var stats_system = _autoload("StatsSystem")
	if stats_system == null:
		return false

	var stats_dict: Dictionary = stats_system.stats
	if stats_dict.is_empty():
		return false

	var key_lookup: Dictionary = {}
	for k in stats_dict.keys():
		key_lookup[String(k)] = k

	for saved_id in state.keys():
		var saved_key := String(saved_id)
		if not key_lookup.has(saved_key):
			continue

		var real_key = key_lookup[saved_key]
		var stat = stats_dict[real_key]
		if stat == null:
			continue

		var s: Variant = state[saved_id]
		if typeof(s) != TYPE_DICTIONARY:
			continue

		var lv := int((s as Dictionary).get("level", stat.level))
		var xp := int((s as Dictionary).get("xp", stat.xp))

		lv = clamp(lv, 1, 50)
		xp = max(xp, 0)

		stat.level = lv
		stat.xp = xp

		if stat.has_signal("xp_changed"):
			stat.emit_signal("xp_changed", saved_key, stat.xp, stat.level)

	return true


# -------------------------------------------------
# Combined save / load (terminal + world + player + stats)
# -------------------------------------------------

func build_full_state(term: Terminal) -> Dictionary:
	var data: Dictionary = {}
	data["version"] = 3

	data["terminal"] = build_terminal_state(term)
	data["world"] = build_world_state()
	data["player"] = build_player_progress_state()
	data["stats"] = build_stats_progress_state()

	return data

func apply_full_state(term: Terminal, state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var ok_term := true
	var ok_world := true
	var ok_player := true
	var ok_stats := true

	var world_state: Variant = state.get("world", {})
	if typeof(world_state) == TYPE_DICTIONARY and not (world_state as Dictionary).is_empty():
		ok_world = apply_world_state(world_state as Dictionary)

	# After world applies, re-sync terminal active device/fs to current_device if supported
	var world = _autoload("World")
	if world != null and ("current_device" in world) and world.current_device != null:
		if term != null and term.has_method("set_active_device"):
			term.set_active_device(world.current_device, true)

	var term_state: Variant = state.get("terminal", {})
	if typeof(term_state) == TYPE_DICTIONARY and not (term_state as Dictionary).is_empty():
		ok_term = apply_terminal_state(term, term_state as Dictionary)

	var player_state: Variant = state.get("player", {})
	if typeof(player_state) == TYPE_DICTIONARY and not (player_state as Dictionary).is_empty():
		ok_player = apply_player_progress_state(player_state as Dictionary)

	var stats_state: Variant = state.get("stats", {})
	if typeof(stats_state) == TYPE_DICTIONARY and not (stats_state as Dictionary).is_empty():
		ok_stats = apply_stats_progress_state(stats_state as Dictionary)

	return ok_world or ok_player or ok_stats or ok_term


# -------------------------------------------------
# Convenience wrappers
# -------------------------------------------------

func save_game(slot: String, term: Terminal) -> bool:
	return save(slot, build_full_state(term))

func load_game(slot: String, term: Terminal) -> bool:
	var data := load_slot(slot)
	return apply_full_state(term, data)

# PUBLIC API — commands depend on this
func save_terminal(slot: String, term: Terminal) -> bool:
	return save_game(slot, term)

func load_terminal(slot: String, term: Terminal) -> bool:
	return load_game(slot, term)
