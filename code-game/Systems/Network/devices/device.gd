extends RefCounted
class_name Device

# Identity (owned by the device itself)
var hostname: String = "new-device"
var mac: String
var hack_chance: float = 0.35
var hwtype: String = "ether"
# hw type can be: { "ether", "wifi", "cell", "bt" } that's it #


# ARP BEHAVIOR #
enum NeighborState { INCOMPLETE, REACHABLE, STALE, DELAY, PROBE, FAILED, PERMANENT }
var neighbor_state_override: int = -1 # -1 = no override; otherwise NeighborState.*
var arp_last_seen_ms: int = -1        # When we last confirmed the mapping
var arp_ever_seen: bool = false       # did we ever resolve this device?
var is_router: bool = false           # mark routers
var arp_state: String = "INCOMPLETE"
var iface: String = ""
var netmask: String = ""
var arp_flags: String = ""

# Experience system
var hack_xp_first: int = 25
var hack_xp_repeat: int = 3
var was_hacked: bool = false

# Network state (assigned by Network)
var ip_address: String = ""
var network: Network = null
var online: bool = true

# Filesystem on devices
var fs: FileSystem

func _init() -> void:
	# Ensure MAC exists
	if mac == "" or mac == null:
		mac = _generate_mac()

	# Ensure filesystem exists (IMPORTANT: always initialize)
	if fs == null:
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
	var bytes: Array[int] = []
	for i in range(6):
		bytes.append(randi_range(0, 255))

	# Locally administered + unicast (more realistic-ish)
	bytes[0] = (bytes[0] & 0xFE) | 0x02

	return "%02X:%02X:%02X:%02X:%02X:%02X" % bytes


# --- ARP HELPERS --- #

func get_arp_state(now_ms: int) -> int:
	# Hard override (rare, but useful)
	if neighbor_state_override != -1:
		return neighbor_state_override

	if is_router:
		return NeighborState.PERMANENT

	# Never resolved yet
	if not arp_ever_seen:
		return NeighborState.INCOMPLETE

	# Was resolved before, but currently offline
	if not online:
		return NeighborState.FAILED

	# Resolved and online: decide freshness
	var age := now_ms - arp_last_seen_ms
	if age <= 30_000:
		return NeighborState.REACHABLE

	return NeighborState.STALE
