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
	bos.fs.mkdir("/home/bos/Documents")
	bos.fs.mkdir("/home/bos/Exports")
	bos.fs.mkdir("/home/bos/Notes")
	bos.fs.mkdir("/home/bos/.ssh")

# Ops / internal users (juicier)
	bos.fs.mkdir("/home/ops")
	bos.fs.mkdir("/home/ops/Documents")
	bos.fs.mkdir("/home/ops/Exports")
	bos.fs.mkdir("/home/ops/Notes")
	bos.fs.mkdir("/home/ops/.ssh")

# System-ish dirs (good for realism + logs)
	bos.fs.mkdir("/etc")
	bos.fs.mkdir("/etc/bank")
	bos.fs.mkdir("/etc/ssh")
	bos.fs.mkdir("/var")
	bos.fs.mkdir("/var/log")
	bos.fs.mkdir("/var/log/bank")
	bos.fs.mkdir("/var/log/auth")
	bos.fs.mkdir("/srv")
	bos.fs.mkdir("/srv/bank")
	bos.fs.mkdir("/srv/bank/core")
	bos.fs.mkdir("/srv/bank/core/config")
	bos.fs.mkdir("/srv/bank/core/db")
	bos.fs.mkdir("/srv/bank/core/exports")
	bos.fs.mkdir("/srv/bank/core/tmp")

# --- “Realistic” files / breadcrumbs --- #

# A welcome / hint file
	bos.fs.write_file("/home/bos/Notes/README.txt",
	"Back Office Server (bos-core01)\n" +
	"Role: internal ops + nightly exports + customer records\n" +
	"Reminder: do NOT email raw exports. Use /srv/bank/core/exports/\n" +
	"Support: ops@brokebank.local\n"
	)

# SSH-ish artifacts (for atmosphere)
	bos.fs.write_file("/etc/ssh/sshd_config",
	"# OpenSSH Server Configuration (trimmed)\n" +
	"Port 22\n" +
	"PermitRootLogin no\n" +
	"PasswordAuthentication yes\n" +
	"AllowUsers ops bos\n"
	)

	bos.fs.write_file("/home/ops/.ssh/authorized_keys",
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForOpsUser ops@bos-core01\n"
	)

# Internal app config (contains “targets” for later gameplay)
	bos.fs.write_file("/etc/bank/core.conf",
	"# BrokeBank Core - internal config\n" +
	"env=prod\n" +
	"region=us-east\n" +
	"core_host=core-gw.brokebank.local\n" +
	"settlement_host=ach-svc.brokebank.local\n" +
	"db_path=/srv/bank/core/db/core.sqlite\n" +
	"export_dir=/srv/bank/core/exports\n"
)

# The “juicy” stuff (customer/account data) — fictional

# Lightweight DB placeholder (text-based for now; you can later make .sqlite a real “binary” feel)
	bos.fs.write_file("/srv/bank/core/db/core.sqlite",
	"[SQLite DB placeholder]\n" +
	"tables:\n" +
	" - customers\n" +
	" - accounts\n" +
	" - cards\n" +
	" - transfers\n" +
	"note: use exports in /srv/bank/core/exports for quick access\n"
	)

# Customer dump export (what your player might scp)
	bos.fs.write_file("/srv/bank/core/exports/customers_export_2026-01-10.csv",
	"customer_id,full_name,email,phone,risk_flag\n" +
	"C-10021,Harper Lane,harper.lane@examplemail.test,555-0142,LOW\n" +
	"C-10022,Mateo Brooks,mateo.brooks@examplemail.test,555-0188,LOW\n" +
	"C-10023,Riley Chen,riley.chen@examplemail.test,555-0194,MED\n" +
	"C-10024,Jordan Price,jordan.price@examplemail.test,555-0127,LOW\n"
	)

# Accounts export (contains fake account numbers + balances)
	bos.fs.write_file("/srv/bank/core/exports/accounts_export_2026-01-10.csv",
	"account_id,customer_id,account_number,type,balance_usd,status\n" +
	"A-90001,C-10021,041702993144,checking,1824.55,ACTIVE\n" +
	"A-90002,C-10022,041702993211,savings,920.10,ACTIVE\n" +
	"A-90003,C-10023,041702993377,checking,143.02,ACTIVE\n" +
	"A-90004,C-10024,041702993402,business,12250.00,ACTIVE\n"
	)

# “Transfer queue” export (good for mission hooks)
	bos.fs.write_file("/srv/bank/core/exports/transfers_queue_2026-01-10.csv",
	"transfer_id,from_account,to_account,amount_usd,created_utc,status\n" +
	"T-77101,041702993402,041702993144,250.00,2026-01-10T02:14:22Z,PENDING\n" +
	"T-77102,041702993211,041702993377,50.00,2026-01-10T03:01:09Z,PENDING\n"
	)

# Card vault export (still fictional; useful as “loot”)
	bos.fs.write_file("/srv/bank/core/exports/cards_vault_2026-01-10.csv",
	"customer_id,card_last4,card_type,expiry,tokenized\n" +
	"C-10021,1139,debit,08/28,true\n" +
	"C-10022,0442,debit,01/27,true\n" +
	"C-10023,9001,credit,11/29,true\n"
	)

# “Weak human” mistakes (plausible, game-friendly)

# Ops note with an internal credential breadcrumb (not real-world usable; purely game)
	bos.fs.write_file("/home/ops/Notes/password_reset_ticket.txt",
	"Ticket #4182\n" +
	"Subject: Core gateway login reset\n" +
	"User: ach_runner\n" +
	"Temp pass issued: Winter2026!\n" +
	"Reminder: force change after first login.\n"
	)

# A “shortcut script” somebody shouldn’t have saved
	bos.fs.write_file("/home/ops/Documents/run_exports.sh",
	"#!/bin/sh\n" +
	"echo \"Running nightly exports...\"\n" +
	"core-cli --export customers --out /srv/bank/core/exports/customers_export_2026-01-10.csv\n" +
	"core-cli --export accounts  --out /srv/bank/core/exports/accounts_export_2026-01-10.csv\n" +
	"core-cli --export transfers --out /srv/bank/core/exports/transfers_queue_2026-01-10.csv\n" +
	"echo \"Done.\"\n"
	)
	
# Logs (atmosphere + hints)

	bos.fs.write_file("/var/log/auth/auth.log",
	"2026-01-10T01:12:08Z sshd[1182]: Accepted password for ops from 201.6.99.42 port 51422\n" +
	"2026-01-10T01:18:55Z sshd[1210]: Failed password for bos from 201.6.99.17 port 51103\n" +
	"2026-01-10T02:00:01Z sshd[1301]: Accepted password for ach_runner from 201.6.99.80 port 51992\n"
	)

	bos.fs.write_file("/var/log/bank/core.log",
	"2026-01-10T02:14:22Z core: queued transfer T-77101 status=PENDING\n" +
	"2026-01-10T03:01:09Z core: queued transfer T-77102 status=PENDING\n" +
	"2026-01-10T03:30:00Z exports: customers_export completed\n" +
	"2026-01-10T03:30:01Z exports: accounts_export completed\n"
	)

# Optional: a hidden-ish stash in tmp
	bos.fs.write_file("/srv/bank/core/tmp/.staging_notes.txt",
	"staging notes:\n" +
	"- audit wants tokenization enforced on all card exports\n" +
	"- legacy files still appear in exports dir briefly during run\n"
	)

	bos.attach_to_network(bank)
