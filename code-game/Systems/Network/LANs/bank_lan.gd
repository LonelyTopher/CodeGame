extends RefCounted
class_name BankLAN

func build(world: WorldNetwork) -> void:

	var bank := Network.new(
		"201.6.99.0/24", # --- IP
		"BrokeBankEBOS", #--- SSID
		"WPA2-PSK",
		9,
		"A9:22:F0:CC:01:99"   # router MAC
	)

	bank.name = "bank_core_LAN"
	bank.vendor = "DeimosNine-Security"
	bank.notes = "Internal operations network (legacy access points detected)"
	bank.visibility = "private"
	bank.scan_signal_placeholder = "--"

	# Gameplay Difficulty 
	bank.difficulty = 3
	bank.network_password = "Ledger2022"
	bank.was_hacked = false
	bank.hack_xp = 12

# Infrastructure
	bank.gateway_host = 1
	bank.neighbor_id = 2

	world.register_network(bank, "bank")
	
	# ------------------------------------------------------------
	# --- ROUTER --- #
	# ------------------------------------------------------------
	var gateway: Device = Device.new()
	gateway.hostname = "DeimosNine-Security E500 Router"
	gateway.hack_chance = 0.65
	gateway.mac = "K1:33:01:7Y:D1:12"
	gateway.hwtype = "ether"
	gateway.iface = "eth0"
	gateway.arp_flags = "R"
	gateway.arp_state = "PERMANENT"
	gateway.netmask = "255.0.255.0"
	gateway.online = true
	gateway.network_password = "Ledger2022"

	bank.attach_router(gateway)

	# ------------------------------------------------------------
	# --- BACK OFFICE SERVER --- #
	# ------------------------------------------------------------
	var bos: Device = Device.new()
	bos.hostname = "bos-core01"
	bos.hack_chance = 0.50
	bos.hwtype = "ether"
	bos.iface = "eth0"
	bos.network_password = "20Deimos22"  # (minigame password)
	bos.hack_xp_first = 25
	bos.hack_xp_repeat = 3
	bos.was_hacked = false


# --- Filesystem layout --- #

	# Home + staff areas
	bos.fs.mkdir("/home")
	bos.fs.mkdir("/home/bos")

# Ops / internal users (juicier)
	bos.fs.mkdir("/home/accounts")

# System-ish dirs (good for realism + logs)
	bos.fs.mkdir("/system")
	bos.fs.mkdir("/server")


	bos.attach_to_network(bank)
