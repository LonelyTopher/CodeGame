extends RefCounted
class_name Device

# Identity (owned by the device itself)
var hostname: String = "new-device"
var mac: String
var hack_chance: float = 0.35
# Hack chance is determined by a float between 0.00 and 1.00 #

# Experience system #

var hack_xp_first: int = 25
var hack_xp_repeat: int = 3
var was_hacked: bool = false

# Network state (assigned by Network)
var ip_address: String = ""
var network: Network = null
var online: bool = true

# Filesystem on devices #
var fs: FileSystem

# Lifecycle
func _init() -> void:
	if mac == "" or mac == null:
		mac = _generate_mac()
		fs = FileSystem.new()
		fs.mkdir("/home")

# Identity accessors
func get_ip() -> String:
	return ip_address

func get_mac() -> String:
	return mac

func get_hostname() -> String:
	return hostname

# Network attachment
func attach_to_network(net: Network) -> void:
	network = net
	net.register_device(self)

func detach_from_network() -> void:
	if network:
		network.unregister_device(self)
	network = null
	ip_address = ""

# -------------------------------------------------
# Internal helpers
# -------------------------------------------------
func _generate_mac() -> String:
	var bytes := []
	for i in range(6):
		bytes.append(randi_range(0, 255))
	return "%02X:%02X:%02X:%02X:%02X:%02X" % bytes
