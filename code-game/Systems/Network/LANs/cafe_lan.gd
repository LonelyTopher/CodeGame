extends RefCounted
class_name CafeLAN

func build(world: WorldNetwork) -> void:
	# -----------------------------
	# Create the cafe network
	# -----------------------------
	var cafe := Network.new(
		"12.146.72.0/24",     # subnet
		"CoffeeShopWiFi",     # SSID
		"OPEN",               # security
		6,                    # channel
		"3C:52:82:9B:14:E6"   # router MAC
	)

	cafe.vendor = "NetGear Public AP"
	cafe.notes = "Public coffee shop Wi-Fi"
	cafe.difficulty = 2
	cafe.visibility = "public"
	cafe.scan_signal_placeholder = "--"
	cafe.neighbor_id = 1
	cafe.gateway_host = 1
	world.register_network(cafe, "cafe")

# --- MINIGAME ATTRIBUTES --- #
	cafe.network_password = ""
	cafe.was_hacked = false





	# ROUTER / GATEWAY (forced .1)

	var cafe_gateway: Device = Device.new()
	cafe_gateway.hostname = "netgear-ap"
	cafe_gateway.hack_chance = 0.10

	cafe_gateway.mac = cafe.bssid

	# ARP stuff #
	cafe_gateway.hwtype = "ether"
	cafe_gateway.iface = "eth0"
	cafe_gateway.arp_flags = "R"
	cafe_gateway.arp_state = "PERMANENT"
	cafe_gateway.netmask = "255.255.255.0"
	cafe_gateway.online = true

	cafe.attach_router(cafe_gateway)



	# =================================================
	# BACK OFFICE DESKTOP (low hack chance ~20%)
	# =================================================
	var cafe_desktop := Device.new()
	cafe_desktop.mac = "00:1B:54:EF:20:01"
	cafe_desktop.hostname = "cafe-desktop"
	cafe_desktop.hack_chance = 0.20
	cafe_desktop.hwtype = "ether"
	cafe_desktop.iface = "eth0"
	cafe_desktop.network_password = "Beans1"


	# User dirs
	cafe_desktop.fs.mkdir("/home")

	cafe_desktop.attach_to_network(cafe)
