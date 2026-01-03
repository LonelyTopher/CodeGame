extends RefCounted
class_name Network

var subnet: String
var devices: Array[Device] = []
var assigned_ips: Dictionary = {}
var prefix: String = "192.168.1."  # first 3 octets + trailing dot
var gateway_host: int = 1          # reserve .1 for router/gateway

#Scan cmd fields#
var name: String = "Network"
var security: String = "WPA2-PSK"   # or "OPEN", "WPA3-SAE"
var channel: int = 6
var bssid: String = ""             # MAC of the AP/router for this network
var difficulty: int = 1            # placeholder for hacking later (optional)


func _init(subnet_cidr := "192.168.1.0/24", ssid := "Network", sec := "WPA2-PSK", ch := 6, ap_bssid := "") -> void:
	subnet = subnet_cidr
	prefix = _prefix_from_cidr(subnet_cidr)

# Scan cmd info #
	name = ssid
	security = sec
	channel = ch
	bssid = ap_bssid

func register_device(device: Device) -> void:
	var ip := _assign_ip()
	assigned_ips[device] = ip
	device.ip_address = ip
	devices.append(device)

func unregister_device(device: Device) -> void:
	if device in devices:
		devices.erase(device)
	device.ip_address = ""

func _assign_ip() -> String:
	# Allocate first available host in 2..254 (skip gateway_host=1)
	for host in range(2, 255):
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
