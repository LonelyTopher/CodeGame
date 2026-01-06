extends Node
class_name WorldNetwork

const LAN_DIR := "res://Systems/Network/LANs"

var home_network: Network
var player_device: Device
var current_device: Device
var networks: Array[Network] = []

# Optional lookups (super handy later)
var networks_by_id: Dictionary = {}      # "homenet" -> Network
var networks_by_ssid: Dictionary = {}    # "HomeNet" -> Network

func _ready() -> void:
	_reload_all_lans()

func _reload_all_lans() -> void:
	networks.clear()
	networks_by_id.clear()
	networks_by_ssid.clear()

	home_network = null
	player_device = null
	current_device = null

	var dir := DirAccess.open(LAN_DIR)
	if dir == null:
		push_error("WorldNetwork: couldn't open %s" % LAN_DIR)
		return

	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".gd"):
			var path := "%s/%s" % [LAN_DIR, f]
			var script := load(path)
			if script == null:
				push_error("WorldNetwork: failed to load %s" % path)
				f = dir.get_next()
				continue

			var inst = script.new()
			if inst == null or not inst.has_method("build"):
				push_error("WorldNetwork: %s missing build(world) method" % path)
				f = dir.get_next()
				continue

			# LAN script registers its network(s) & devices
			inst.build(self)

		f = dir.get_next()
	dir.list_dir_end()

	# If LAN scripts didn't set it, default to player
	if current_device == null and player_device != null:
		current_device = player_device

# -------------------------
# Registration API used by LAN scripts
# -------------------------
func register_network(net: Network, id: String = "") -> void:
	if net == null:
		return
	networks.append(net)
	networks_by_ssid[net.name] = net
	if id != "":
		networks_by_id[id] = net

func set_home_network(net: Network) -> void:
	home_network = net

func register_player_device(dev: Device) -> void:
	player_device = dev
	if current_device == null:
		current_device = player_device

func set_current_device(dev: Device) -> void:
	current_device = dev

# -------------------------
# Existing accessors
# -------------------------
func get_current_device() -> Device:
	return current_device

func get_networks() -> Array[Network]:
	return networks

func get_network_by_ssid(ssid: String) -> Network:
	return networks_by_ssid.get(ssid, null)

func get_network_by_id(id: String) -> Network:
	return networks_by_id.get(id, null)

# -------------------------
# Save/load: player device identity
# -------------------------
func get_player_device_state() -> Dictionary:
	if player_device == null:
		return {}
	return {
		"hostname": player_device.hostname,
		"mac": player_device.mac,
		"ip_address": player_device.ip_address
	}

func apply_player_device_state(data: Dictionary) -> void:
	if player_device == null:
		return

	if data.has("hostname"):
		player_device.hostname = String(data["hostname"])
	if data.has("mac"):
		player_device.mac = String(data["mac"])
	if data.has("ip_address"):
		player_device.ip_address = String(data["ip_address"])

	if current_device == player_device:
		current_device = player_device
