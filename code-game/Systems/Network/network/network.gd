extends RefCounted
class_name Network

# -------------------------
# Existing fields (KEEP)
# -------------------------
var subnet: String
var devices: Array[Device] = []
var assigned_ips: Dictionary = {}       # device -> ip
var prefix: String = "192.168.1."       # first 3 octets + trailing dot
var gateway_host: int = 1               # reserve .1 for router/gateway

# Scan cmd fields (KEEP)
var name: String = "Network"
var security: String = "WPA2-PSK"
var channel: int = 6
var bssid: String = ""
var difficulty: int = 1

# --- NETWORK PASSWORD FOR MINIGAME --- #
var network_password: String = ""

# HIDDEN FIELD FOR NEIGHBORING NETWORKS AND SCAN NETWORK DISCOVERY #
var neighbor_id: int = 0

# -------------------------
# New optional fields (SAFE additions)
# -------------------------
var vendor: String = ""                 # scan column (optional)
var notes: String = ""                  # internal flavor text
var visibility: String = "public"       # "public" | "private" | "hidden"

# Signal placeholders (until you implement physical position)
var scan_signal_placeholder: String = "--"     # for scan table
var device_signal_dbm: Dictionary = {}         # mac -> int (optional future)

func _init(subnet_cidr := "192.168.1.0/24", ssid := "Network", sec := "WPA2-PSK", ch := 6, ap_bssid := "") -> void:
	subnet = subnet_cidr
	prefix = _prefix_from_cidr(subnet_cidr)

	# Scan cmd info (same assignments)
	name = ssid
	security = sec
	channel = ch
	bssid = ap_bssid

func register_device(device: Device) -> void:
	# Keep behavior: assign IP, set device.ip_address, append device
	var ip := _assign_ip()
	assigned_ips[device] = ip
	device.ip_address = ip
	devices.append(device)

func unregister_device(device: Device) -> void:
	if device in devices:
		devices.erase(device)

	# (Fix) also remove from assigned_ips to avoid leaks
	if assigned_ips.has(device):
		assigned_ips.erase(device)

	device.ip_address = ""

func _assign_ip() -> String:
	# Allocate first available host in 2..254 (skip gateway_host=1)
	for host in range(1, 255):
		if host == gateway_host:
			continue

		var ip := prefix + str(host)
		if not assigned_ips.values().has(ip):
			return ip

	# Fallback
	return prefix + "254"

func _prefix_from_cidr(cidr: String) -> String:
	# "192.168.1.0/24" -> "192.168.1."
	var ip_part := cidr.split("/")[0]
	var parts := ip_part.split(".")
	if parts.size() != 4:
		return "192.168.1."
	return "%s.%s.%s." % [parts[0], parts[1], parts[2]]

# -------------------------
# Helpers for realism tables
# -------------------------
func get_scan_row() -> Dictionary:
	# For scan table rows
	return {
		"ssid": name,
		"security": security,
		"channel": channel,
		"bssid": bssid,
		"signal": (scan_signal_placeholder if scan_signal_placeholder != "" else "--"),
		"vendor": (vendor if vendor != "" else "--"),
		"difficulty": difficulty
	}

func get_arp_rows() -> Array[Dictionary]:
	# For arp table rows
	var rows: Array[Dictionary] = []
	for dev in devices:
		var ip := ""
		if assigned_ips.has(dev):
			ip = String(assigned_ips[dev])
		else:
			ip = String(dev.ip_address)

		var mac := String(dev.mac)
		var hostname := String(dev.hostname)

		rows.append({
			"ip": ip,
			"mac": mac,
			"hostname": hostname,
			"signal": get_device_signal_string(mac) # "--" until you set dbm later
		})
	return rows

func set_device_signal_dbm(mac: String, dbm: int) -> void:
	device_signal_dbm[mac] = dbm

func get_device_signal_string(mac: String) -> String:
	if mac == "" or not device_signal_dbm.has(mac):
		return "--"
	return "%ddBm" % int(device_signal_dbm[mac])

# -------------------------
# Helper for assigning gateway IPs
# -------------------------

func attach_router(router: Device) -> void:
	var ip := prefix + str(gateway_host)
	router.ip_address = ip
	router.network = self
	router.online = true

	devices.append(router)
	assigned_ips[router.mac] = ip
