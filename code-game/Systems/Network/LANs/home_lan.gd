extends RefCounted

func build(world: WorldNetwork) -> void:
	# Hard-coded LAN metadata
	var home := Network.new(
		"192.168.77.0/24",
		"HomeNet",
		"WPA2-PSK",
		11,
		"D0:37:45:8A:6C:19"
	)
	home.vendor = "Generic Home Router"
	home.notes = "Player home base LAN"
	home.difficulty = 1
	home.visibility = "private"
	home.scan_signal_placeholder = "--"
	home.neighbor_id = 0
	home.gateway_host = 1

	world.register_network(home, "home")
	world.set_home_network(home)

	# -----------------------------
	# Home Router (forced .1)
	# -----------------------------
	var router: Device = Device.new()
	router.hostname = "Eero Device"
	router.hack_chance = 100.0
	router.hack_xp_first = 0
	router.hack_xp_repeat = 0
	
	# --- NETWORK PASSWORD FOR HACK'ING MINIGAME --- #
	router.network_password = "Net10"

	# IMPORTANT: ensure router has a MAC before attach_router uses it as the key
	if router.mac == "" or router.mac == null:
		router.mac = router.get_mac()

	# ---- ARP / link-layer identity (THIS is what arp reads) ----
	# Use whatever exact field names you added to Device.gd
	router.hwtype = "ether"          # wired device
	router.iface = "eth0"            # interface name shown in arp
	router.arp_flags = "R"           # C = "complete" (your arp cmd already uses this)
	router.arp_state = "PERMANENT"   # typical for gateway/static entry
	router.netmask = "255.255.255.0" # optional; or leave "--"
	router.online = true             # if you have it

	# Optional flavor (only if you have these fields)
	# router.vendor = "Eero"
	# router.notes = "Gateway / DHCP / NAT"

	home.attach_router(router)


	# Player laptop

	var laptop := Device.new()

	# --- Identity --- #
	laptop.mac = "3C:52:82:9A:4F:B1"
	
	# --- Dirs First --- #
	laptop.fs.mkdir("/home")
	laptop.fs.mkdir("/system")
	laptop.fs.touch("/system/should-be-hidden-data.dat")
	
	laptop.fs.lock_dir("/system", "password")
	
	# --- Files --- #
	laptop.fs.write_data_file("/home/money.dat",{
		"currency": "DOLLARS",
		"amount": 500.00,
		"owner": laptop.hostname
	})
	
	
	# --- Attach to network --- #
	laptop.attach_to_network(home)
	world.register_player_device(laptop)
	world.set_current_device(laptop)
