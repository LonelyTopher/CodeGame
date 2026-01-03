extends Node
class_name WorldNetwork

var home_network: Network
var player_device: Device
var current_device: Device
var networks: Array[Network] = []

# This is where we create networks and attach devices to them #
func _ready() -> void:
	networks.clear()

	# -------------------------
	# Home Network
	# -------------------------
	home_network = Network.new(
		"192.173.14.0/24",
		"HomeNet",
		"WPA2-PSK",
		11,
		"AA:BB:CC:11:22:33"
	)
	networks.append(home_network)

	# Player home computer (self-configuring)
	player_device = PlayerHomeComputer.new()
	player_device.attach_to_network(home_network)

	current_device = player_device


	# -------------------------
	# Cafe Network
	# -------------------------
	var cafe_network := Network.new(
		"10.42.7.0/24",
		"CoffeeShopWiFi",
		"OPEN",
		6,
		"DE:AD:BE:EF:00:01"
	)
	networks.append(cafe_network)

	# Cafe router
	var cafe_router := CafeRouter.new()
	cafe_router.attach_to_network(cafe_network)

	# Cafe desktop
	var cafe_desktop := CafeDesktop.new()
	cafe_desktop.attach_to_network(cafe_network)

func get_current_device() -> Device:
	return current_device

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

	# If we're "on" the player device, keep current_device synced
	if current_device == player_device:
		current_device = player_device

func _generate_mac() -> String:
	var bytes: Array[int] = []
	for i in range(6):
		bytes.append(randi_range(0, 255))

	# Make it look like a locally administered unicast MAC (realistic-ish):
	bytes[0] = (bytes[0] & 0xFE) | 0x02

	return "%02X:%02X:%02X:%02X:%02X:%02X" % bytes

func get_networks() -> Array[Network]:
	return networks
