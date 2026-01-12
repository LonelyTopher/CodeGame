extends RefCounted
class_name Network

var subnet: String
var devices: Array[Device] = []
var assigned_ips: Dictionary = {}       # device -> ip
var prefix: String = "192.168.1."
var gateway_host: int = 1

var name: String = "Network"
var security: String = "WPA2-PSK"
var channel: int = 6
var bssid: String = ""
var difficulty: int = 1

var network_password: String = ""
var was_hacked: bool = false
var hack_xp: int = 5

var neighbor_id: int = 0

var vendor: String = ""
var notes: String = ""
var visibility: String = "public"

var scan_signal_placeholder: String = "--"
var device_signal_dbm: Dictionary = {}

func _init(subnet_cidr := "192.168.1.0/24", ssid := "Network", sec := "WPA2-PSK", ch := 6, ap_bssid := "") -> void:
	subnet = subnet_cidr
	prefix = _prefix_from_cidr(subnet_cidr)

	name = ssid
	security = sec
	channel = ch
	bssid = ap_bssid

func register_device(device: Device) -> void:
	var ip := _assign_ip()
	assigned_ips[device] = ip
	device.ip_address = ip
	device.network = self
	devices.append(device)

func unregister_device(device: Device) -> void:
	if device in devices:
		devices.erase(device)

	if assigned_ips.has(device):
		assigned_ips.erase(device)

	device.ip_address = ""
	device.network = null

func _assign_ip() -> String:
	for host in range(1, 255):
		if host == gateway_host:
			continue

		var ip := prefix + str(host)
		if not assigned_ips.values().has(ip):
			return ip

	return prefix + "254"

func _prefix_from_cidr(cidr: String) -> String:
	var ip_part := cidr.split("/")[0]
	var parts := ip_part.split(".")
	if parts.size() != 4:
		return "192.168.1."
	return "%s.%s.%s." % [parts[0], parts[1], parts[2]]

func get_scan_row() -> Dictionary:
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
	var rows: Array[Dictionary] = []
	for dev in devices:
		var ip := ""
		if assigned_ips.has(dev):
			ip = String(assigned_ips[dev])
		else:
			ip = String(dev.ip_address)

		rows.append({
			"ip": ip,
			"mac": String(dev.mac),
			"hostname": String(dev.hostname),
			"signal": get_device_signal_string(String(dev.mac))
		})
	return rows

func set_device_signal_dbm(mac: String, dbm: int) -> void:
	device_signal_dbm[mac] = dbm

func get_device_signal_string(mac: String) -> String:
	if mac == "" or not device_signal_dbm.has(mac):
		return "--"
	return "%ddBm" % int(device_signal_dbm[mac])

func attach_router(router: Device) -> void:
	var ip := prefix + str(gateway_host)
	router.ip_address = ip
	router.network = self
	router.online = true

	devices.append(router)
	# NOTE: you had assigned_ips[router.mac] here; we keep it compatible by also storing device->ip
	assigned_ips[router] = ip

# -------------------------------------------------
# Save / Load helpers (NEW)
# -------------------------------------------------

func to_data() -> Dictionary:
	return {
		"subnet": subnet,
		"prefix": prefix,
		"gateway_host": gateway_host,

		# scan identity
		"name": name,
		"security": security,
		"channel": channel,
		"bssid": bssid,
		"difficulty": difficulty,

		# hack state
		"was_hacked": was_hacked,

		# optional extra fields (safe)
		"vendor": vendor,
		"notes": notes,
		"visibility": visibility,
		"neighbor_id": neighbor_id
	}

func from_data(state: Dictionary) -> void:
	if state.is_empty():
		return

	subnet = String(state.get("subnet", subnet))
	prefix = String(state.get("prefix", prefix))
	gateway_host = int(state.get("gateway_host", gateway_host))

	name = String(state.get("name", name))
	security = String(state.get("security", security))
	channel = int(state.get("channel", channel))
	bssid = String(state.get("bssid", bssid))
	difficulty = int(state.get("difficulty", difficulty))

	was_hacked = bool(state.get("was_hacked", was_hacked))

	vendor = String(state.get("vendor", vendor))
	notes = String(state.get("notes", notes))
	visibility = String(state.get("visibility", visibility))
	neighbor_id = int(state.get("neighbor_id", neighbor_id))

# After loading device.ip_address from save, rebuild assigned_ips so ARP tables match.
func rebuild_assigned_ips_from_devices() -> void:
	var new_map: Dictionary = {}
	for dev in devices:
		if dev == null:
			continue
		if String(dev.ip_address) != "":
			new_map[dev] = String(dev.ip_address)
	assigned_ips = new_map
