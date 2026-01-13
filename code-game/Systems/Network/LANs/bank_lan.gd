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

	bank.name = "Kurosawa-Checking-WiFi"
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
# ---- DIRECTORIES ---- #
	# Home + staff areas
	bos.fs.mkdir("/home")
	bos.fs.mkdir("/home/bos")
	bos.fs.mkdir("/home/bos/employees")
	bos.fs.mkdir("/home/bos/accounts")

# --- SYSTEM DIRECTORIES --- #
	bos.fs.mkdir("/home/accounts")

# ---- SYSTEM DIRS ---- #
	bos.fs.mkdir("/system")
	bos.fs.lock_dir("/system", "Kurosawa01Admin")
	bos.fs.mkdir("/server")
	bos.fs.lock_dir("/server", "SecurityAdmin1")
	bos.fs.mkdir("/server/accounts")

# ---- FRONT END FILES ---- #
	bos.fs.write_file("/home/bos/employees/employee-list.txt",
	"Daniel Kurosawa -- age 34 -- employed since 2066 -- Founder         -- EID: Ks313953\n" +
	"Nathen Kurosawa -- age 38 -- employed since 2066 -- Co. Founder     -- EID: Ks313954\n" +
	"Emily Kurosawa  -- age 30 -- employed since 2071 -- Partner         -- EID: Ks313955\n" +
	"Adrian Volkov   -- age 28 -- employed since 2069 -- Branch Manager	-- EID: Ks386235\n" +
	"Simone Kessler  -- age 36 -- employed since 2071 -- Sr. Teller		-- EID: Ks348261\n" +
	"Marcus Liang    -- age 27 -- employed since 2076 -- Teller			-- EID: Ks394253\n" +
	"Evelyn Stratton -- age 38 -- employed since 2075 -- Receptionist	-- EID: Ks377456\n"
	)

# ---- BACK END FILES ---- #
	bos.fs.write_data_file("/server/accounts/Lina_Kovac.data",
	{
		"balances": { "DOLLARS": 500.0 },
		"owner": "Lina Kovac"
	}
)
	bos.fs.write_data_file("/server/accounts/Jax_Moreno.data",
	{
		"balances": { "DOLLARS": 1272.63 },
		"owner": "Jax Moreno"
	}
)
	bos.fs.write_data_file("/server/accounts/Marcus_Hale.data",
	{
		"balances": { "DOLLARS": 1684.81 },
		"owner": "Marcus Hale"
	}
)
	bos.fs.write_data_file("/server/accounts/Cole_Navarro.data",
	{
		"balances": { "BITCOIN": 0.006518,
					  "DOLLARS": 872.75 },
		"owner": "Cole Navarro"
	}
)
	bos.fs.write_data_file("/server/accounts/Daniel_Kurosawa.data",
	{
		"balances": { "DOLLARS": 271698.21,
					  "BITCOIN": 3.171301 },
		"owner": "Daniel Kurosawa"
	}
)
	bos.fs.write_data_file("/server/accounts/Sloane_Meyer.data",
	{
		"balances": { "DOLLARS": 12627.31 }
	}
)

	bos.attach_to_network(bank)
