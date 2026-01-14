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
	bank.neighbor_id = 1

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
	bos.mac = "00:1B:54:N6:08:14"
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
	bos.fs.mkdir("/home/bos/managers")
	bos.fs.mkdir("/home/bos/customer-complaints")
	bos.fs.mkdir("/home/bos/corporate")
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
	bos.fs.write_file("/home/bos/customer-complaints/complaint_0147", "Dear bank manager,\n\n" +
	"This is like the third time this month that my account has been 'Temporarily restricted'\n" +
	"without any explanation beyond 'automated risk detection.'\n\n" + "I have been a customer " +
	"of Kurosawa Checking since you guys opened in 2066.\n I have never missed a payment." +
	"I do not understand why I am suddenly being treated like a criminal.\n\n" +
	"When I asked the teller for deatails, she refused to look me in the eye and said\n" +
	"she 'wasn't allowed to discuss internal flags.'\n\n" +
	"What flags?\nWhat system?\n\n" + "If this is not resolved by the end of the week, I will be " +
	"escalating this to the authorities and closing ALL associated accounts!\n\n- Daniel H. Morrison\n" +
	"Account #44388291"
	)
	bos.fs.write_file("home/bos/customer-complaints/complaint_0219", "Hello,\n\n I am writing to " +
	"formally dispute the removal of my savings account balance.\n\nOn 08/17/81, my balance showed " +
	"$18,422.19.\nOn 08/18/81, my balance showed $0.00.\n\nThere is no transaction history explaining this change.\n" +
	"No withdrawl. \nNo transfer. \nNo fee.\n\n Customer support insists the funds were 'reallocated due to internal compliance review.\n" +
	"That phrase means nothing to me.\n\nI want a full audit trail.\nI want timestamps.\nI want to know WHO authorized this.\n\n" +
	"If this is not corrected immediately, I will be contacting legal counsel.\n\n- R.S.\n(You have my account details on file)"
	)
	bos.fs.write_file("home/bos/customer-complaints/complaint_0033", "This is not a complaint.\nThis is a warning.\n\n" +
	"Someone inside your instutution is manipulating account records.\nNot stealing - they're moving.\n\nI noticed micro-adjustments " +
	"in several unrelated cusomer balances.\nAlways small.\nAlways clean.\nAlways justified by the same compliance code.\n\n" +
	"I brought this to my supervisor.\nTwo days later, my access credentials were revoked.\n\nYesterday, my employee account no " +
	"longer existed.\n\nI suggest you look into Compliance Node C-17.\nSpecifically, the overnight batch jobs.\n\n" +
	"If this file is still here, it means nobody reads these anyways.\n\n- Former Accounts Analyst"
	)
	bos.fs.write_file("home/bos/corporate/note_internal_review", 
	"INTERNAL USE ONLY\n\nDo [color=red]NOT[/color] escalate Compliance Adjustments without approval from Node C-17.\n" +
	"\nYes, customers are noticing.\nNo, you are not authorized to explain.\n\nUse the provided phrasing:\n'automated review'\n" +
	"'riisk normalization'\n'system reconciliation'\n\nDo not invent explanations.\nDo not speculate.\nDo not mention batch timing\n\n" +
	"Any deviation will be logged.\n\n- Compliance Oversight"
)
	bos.fs.write_file("home/bos/managers/draft_response_template",
	"Dear Valued Customer,\n\nThank you for contacting Kurosawa Checking.\nWe understand your concern regarding recent acount activity.\n\n" +
	"Please be assured that all adjustments are performed automatically\nand in accordance with internal compliance protocols.\n\n" +
	"At this time, no further action is required on your part.\n\nSincerely,\nAccount Services"
)
# ---- BACK END FILES ---- #
	bos.fs.write_data_file("/server/accounts/Lina_Kovac.data",
	{
		"balances": { "DOLLARS": 721.0 },
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
		"balances": { "DOLLARS": 12627.31 },
		"owner": "Sloane Meyer"
	}
)
	bos.fs.write_data_file("/server/accounts/Daniel_Morrison", 
	{
		"balances": { "Dollars": 35681.59 },
		"owner": "Sloane Meyer"
	}
)

	bos.attach_to_network(bank)
# ------------------------------------------------------------
	# --- NETWORK CLUTTER --- #
	# ------------------------------------------------------------
