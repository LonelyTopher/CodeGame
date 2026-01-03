extends Device
class_name CafeRouter

func _init():
	super._init()  # ✅ creates fs, network fields, etc.

	# --- Identity ---
	hostname = "CafeRouter"
	mac = _generate_mac()
	online = true

	# --- Filesystem ---
	fs.mkdir("/etc")
	fs.mkdir("/var")
	fs.mkdir("/var/log")
	fs.mkdir("/config")

	fs.write_file(
		"/config/network.conf",
		"subnet=10.42.7.0/24\n" +
		"gateway=10.42.7.1\n" +
		"dhcp=enabled\n"
	)

	fs.write_file("/etc/router.info",
		"model=NetGear XR500\n" +
		"firmware=1.3.7\n" +
		"admin=admin\n"
	)

	# Logs (great hacking targets later)
	fs.write_file("/var/log/dhcp.log",
		"DHCP lease granted: 10.42.7.2\n" +
		"DHCP lease granted: 10.42.7.3\n"
	)

	fs.write_file("/var/log/firewall.log",
		"[ALLOW] 10.42.7.3 -> 8.8.8.8\n"
	)
