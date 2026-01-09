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

	cafe.network_password = ""





	# =================================================
	# ROUTER / GATEWAY (forced .1)
	# =================================================

	var cafe_gateway: Device = Device.new()
	cafe_gateway.hostname = "netgear-ap"
	cafe_gateway.hack_chance = 0.10

	# Make the router MAC match the BSSID you already assigned to the network (nice realism)
	# (Only do this if your Device.mac is writable and not auto-generated/locked.)
	cafe_gateway.mac = cafe.bssid

	# ARP identity fields
	cafe_gateway.hwtype = "ether"
	cafe_gateway.iface = "eth0"
	cafe_gateway.arp_flags = "R"
	cafe_gateway.arp_state = "PERMANENT"
	cafe_gateway.netmask = "255.255.255.0"
	cafe_gateway.online = true

	# IMPORTANT: This is what forces .1 (DO NOT use attach_to_network for the router)
	cafe.attach_router(cafe_gateway)



	# =================================================
	# BACK OFFICE DESKTOP (low hack chance ~20%)
	# =================================================
	var cafe_desktop := Device.new()
	cafe_desktop.hostname = "cafe-desktop"
	cafe_desktop.hack_chance = 0.20
	cafe_desktop.hwtype = "ether"
	cafe_desktop.iface = "eth0"
	cafe_desktop.network_password = "Beans1"


	# User dirs
	cafe_desktop.fs.mkdir("/home")
	cafe_desktop.fs.mkdir("/home/cafe")
	cafe_desktop.fs.mkdir("/home/cafe/Documents")
	cafe_desktop.fs.mkdir("/home/cafe/Exports")
	cafe_desktop.fs.mkdir("/home/cafe/Staff")
	cafe_desktop.fs.mkdir("/home/cafe/Staff/Timesheets")

	cafe_desktop.fs.write_file("/home/cafe/Documents/inventory.txt",
		"Inventory:\n- beans (dark)\n- beans (light)\n- milk\n- cups\n- lids\n"
	)
	cafe_desktop.fs.write_file("/home/cafe/Staff/Timesheets/week_03.csv",
		"name,hours\nbarista1,32\nbarista2,28\nmanager,40\n"
	)

	# System-ish dirs (hidden unless tree -a /)
	cafe_desktop.fs.mkdir("/var")
	cafe_desktop.fs.mkdir("/var/log")
	cafe_desktop.fs.mkdir("/var/lib")
	cafe_desktop.fs.mkdir("/var/lib/.cache")
	cafe_desktop.fs.mkdir("/var/lib/.cache/.billing")
		# More realistic clutter
	cafe_desktop.fs.mkdir("/home/cafe/Desktop")
	cafe_desktop.fs.mkdir("/home/cafe/Documents/Policies")
	cafe_desktop.fs.mkdir("/home/cafe/Documents/Reports")
	cafe_desktop.fs.mkdir("/home/cafe/Downloads")
	cafe_desktop.fs.mkdir("/home/cafe/Exports/2026-01")
	cafe_desktop.fs.mkdir("/home/cafe/Exports/2026-01/pos")
	cafe_desktop.fs.mkdir("/home/cafe/Exports/2026-01/inventory")

	cafe_desktop.fs.write_file("/home/cafe/Desktop/DO_NOT_DELETE.txt",
		"STOP deleting shortcuts.\nPOS sync runs at close.\nIf it breaks call manager.\n"
	)

	cafe_desktop.fs.write_file("/home/cafe/Documents/Policies/wifi_policy.txt",
		"CoffeeShopWiFi is OPEN.\nStaffNet is WPA2.\nDo not share StaffNet password.\n"
	)

	cafe_desktop.fs.write_file("/home/cafe/Documents/Reports/daily_close_0105.txt",
		"Daily Close Report\n- Drawer balanced: YES\n- Batch settle: OK\n- Voids: 2\n"
	)

	cafe_desktop.fs.write_file("/home/cafe/Downloads/router_manual.txt",
		"NetGear Public AP Manual\nDefault gateway: 12.146.72.1\nAdmin panel: http://12.146.72.1\n"
	)

	# More logs (makes tree/find feel rewarding)
	cafe_desktop.fs.write_file("/var/log/dhcp.log",
		"DHCP leases issued today:\n12.146.72.2\n12.146.72.3\n12.146.72.4\n...\n"
	)

	cafe_desktop.fs.write_file("/var/log/pos-sync.log",
		"pos-sync started\npos-sync uploading receipts -> server\npos-sync complete\n"
	)

	# Hidden breadcrumb to server stash
	cafe_desktop.fs.write_file("/var/lib/.cache/.billing/.hint",
		"if you need exports: check server path /var/lib/mysql/.cache/.billing/exports\n"
	)

	cafe_desktop.fs.write_file("/var/log/syslog",
		"Jan 05 09:13:22 net: dhcp lease renewed\nJan 05 10:02:01 pos: batch settle ok\n"
	)

	# A hint pointing to the “good stuff”
	cafe_desktop.fs.mkdir("/home/cafe/Documents/.sync")
	cafe_desktop.fs.write_file("/home/cafe/Documents/.sync/notes.txt",
		"backup job writes to /var/lib/.cache/.billing (restricted)\n"
	)

	cafe_desktop.attach_to_network(cafe)







	# =================================================
	# LOCAL SERVER (hardest ~10%) — gold mine lives here
	# =================================================
	var cafe_server := Device.new()
	cafe_server.hostname = "cafe-BOS"
	cafe_server.hack_chance = 0.10
	cafe_server.hwtype = "ether"
	cafe_server.iface = "eth0"
	
	cafe_server.fs.mkdir("/home")
	cafe_server.fs.mkdir("/home/server")
	cafe_server.fs.mkdir("/etc")
	cafe_server.fs.mkdir("/etc/ssh")
	cafe_server.fs.mkdir("/var")
	cafe_server.fs.mkdir("/var/log")
	cafe_server.fs.mkdir("/var/lib")
	cafe_server.fs.mkdir("/var/lib/mysql")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing/last30days")
		# Make it feel like an actual server
	cafe_server.fs.mkdir("/home/server/bin")
	cafe_server.fs.mkdir("/home/server/backups")
	cafe_server.fs.mkdir("/home/server/backups/daily")
	cafe_server.fs.mkdir("/home/server/backups/weekly")
	cafe_server.fs.mkdir("/home/server/scripts")
	cafe_server.fs.mkdir("/etc/nginx")
	cafe_server.fs.mkdir("/etc/systemd")
	cafe_server.fs.mkdir("/etc/systemd/system")
	cafe_server.fs.mkdir("/var/www")
	cafe_server.fs.mkdir("/var/www/html")
	cafe_server.fs.mkdir("/var/tmp")

	cafe_server.fs.write_file("/home/server/README.txt",
		"cafe-server\n- hosts billing exports\n- POS terminals upload nightly\n- do not expose to public internet\n"
	)

	cafe_server.fs.write_file("/etc/nginx/nginx.conf",
		"worker_processes auto;\nhttp { server { listen 8080; root /var/www/html; } }\n"
	)

	cafe_server.fs.write_file("/var/www/html/status.json",
		"{\"ok\":true,\"pos_upload\":\"nightly\",\"last_sync\":\"2026-01-05T22:03:11\"}\n"
	)

	# MORE hidden billing structure
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing/exports")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing/exports/.archive")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing/exports/.archive/2026-01")
	cafe_server.fs.mkdir("/var/lib/mysql/.cache/.billing/exports/.archive/2025-12")

	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/exports/README_SECURITY.txt",
		"Billing exports (tokenized)\n" +
		"- card numbers: **** **** **** LAST4 only\n" +
		"- CVV: ***REDACTED*** (never stored)\n" +
		"- PIN: ***REDACTED*** (not applicable)\n" +
		"- tokens used for settlement reconciliation\n"
	)

	# “TONS” of juicy-looking records, but redacted/masked
	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/exports/.archive/2026-01/customer_records_01.csv",
		"customer_name,customer_id,card_masked,exp,cvv,pin,token,last_seen,notes\n" +
		"Jules Carter,cust_101,**** **** **** 1234,03/28,***REDACTED***,***REDACTED***,pm_REDACTED_101,2026-01-05,\"tips heavy\"\n" +
		"Sam Nguyen,cust_102,**** **** **** 9920,11/27,***REDACTED***,***REDACTED***,pm_REDACTED_102,2026-01-05,\"no tip\"\n" +
		"Kai Rivera,cust_103,**** **** **** 0773,06/29,***REDACTED***,***REDACTED***,pm_REDACTED_103,2026-01-04,\"frequent\"\n" +
		"Nina Patel,cust_104,**** **** **** 4311,12/26,***REDACTED***,***REDACTED***,pm_REDACTED_104,2026-01-04,\"coupon used\"\n" +
		"Lee Morgan,cust_105,**** **** **** 1842,01/30,***REDACTED***,***REDACTED***,pm_REDACTED_105,2026-01-03,\"receipt emailed\"\n" +
		"Taylor Brooks,cust_106,**** **** **** 6409,09/28,***REDACTED***,***REDACTED***,pm_REDACTED_106,2026-01-03,\"refund requested\"\n" +
		"Riley Stone,cust_107,**** **** **** 5518,02/27,***REDACTED***,***REDACTED***,pm_REDACTED_107,2026-01-02,\"cash alt\"\n" +
		"Morgan Ellis,cust_108,**** **** **** 3392,08/26,***REDACTED***,***REDACTED***,pm_REDACTED_108,2026-01-02,\"invoice\"\n" +
		"Alex Harper,cust_109,**** **** **** 6001,05/29,***REDACTED***,***REDACTED***,pm_REDACTED_109,2026-01-01,\"student\"\n" +
		"Casey Reed,cust_110,**** **** **** 2704,10/27,***REDACTED***,***REDACTED***,pm_REDACTED_110,2026-01-01,\"rush\"\n"
	)

	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/exports/.archive/2026-01/settlement_summary.json",
		"{\n" +
		"  \"period\": \"last30days\",\n" +
		"  \"records\": 842,\n" +
		"  \"notes\": \"tokens only; PAN/CVV not stored\",\n" +
		"  \"processor_key\": \"sk_live_***REDACTED***\",\n" +
		"  \"webhook_secret\": \"whsec_***REDACTED***\"\n" +
		"}\n"
	)

	cafe_server.fs.write_file("/home/server/scripts/pos_ingest.sh",
		"#!/bin/sh\n" +
		"echo \"ingesting receipts...\"\n" +
		"# writes exports to /var/lib/mysql/.cache/.billing/exports\n"
	)

	cafe_server.fs.write_file("/var/log/cron.log",
		"CRON[1120]: nightly pos_ingest\nCRON[1120]: backup weekly\n"
	)

	cafe_server.fs.write_file("/home/server/backups/daily/billing_2026-01-05.tar",
		"TAR_BINARY_PLACEHOLDER"
	)

	cafe_server.fs.write_file("/etc/ssh/sshd_config",
		"# sshd_config\nPasswordAuthentication yes\nPermitRootLogin no\n"
	)
	cafe_server.fs.write_file("/var/log/auth.log",
		"sshd[112]: Accepted publickey for manager from 12.146.72.10\n"
	)

	# Tokenized/masked settlement records (SAFE but still feels illegal)
	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/last30days/settlements_01.json",
		"{\n\t\"day\": 1,\n\t\"records\": [\n\t\t{\"customer_id\":\"cust_001\",\"card_masked\":\"**** **** **** 1842\",\"payment_token\":\"pm_REDACTED_001\",\"auth_id\":\"apv_REDACTED_420001\",\"amount_usd\":6.75,\"tip_usd\":1.00,\"device\":\"POS1\"},\n\t\t{\"customer_id\":\"cust_002\",\"card_masked\":\"**** **** **** 9920\",\"payment_token\":\"pm_REDACTED_002\",\"auth_id\":\"apv_REDACTED_420002\",\"amount_usd\":4.25,\"tip_usd\":0.00,\"device\":\"POS2\"}\n\t]\n}\n"
	)
	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/last30days/settlements_02.json",
		"{\n\t\"day\": 2,\n\t\"records\": [\n\t\t{\"customer_id\":\"cust_014\",\"card_masked\":\"**** **** **** 4311\",\"payment_token\":\"pm_REDACTED_014\",\"auth_id\":\"apv_REDACTED_420014\",\"amount_usd\":8.50,\"tip_usd\":2.00,\"device\":\"POS2\"},\n\t\t{\"customer_id\":\"cust_019\",\"card_masked\":\"**** **** **** 0773\",\"payment_token\":\"pm_REDACTED_019\",\"auth_id\":\"apv_REDACTED_420019\",\"amount_usd\":3.75,\"tip_usd\":1.00,\"device\":\"POS1\"}\n\t]\n}\n"
	)

	# “Keys” file (redacted but tempting)
	cafe_server.fs.write_file("/var/lib/mysql/.cache/.billing/keys.txt",
		"processor_api_key=sk_live_REDACTED\nwebhook_secret=whsec_REDACTED\n"
	)

	cafe_server.attach_to_network(cafe)






	# =================================================
	# POS TERMINALS (50–60%)
	# =================================================
	var pos1 := Device.new()
	pos1.hostname = "pos-terminal-1"
	pos1.hack_chance = 0.55
	pos1.hwtype = "ether"
	pos1.iface = "eth0"

	pos1.fs.mkdir("/home")
	pos1.fs.mkdir("/home/pos")
	pos1.fs.mkdir("/home/pos/POS1")
	pos1.fs.mkdir("/home/pos/POS1/receipts")
	pos1.fs.mkdir("/home/pos/POS1/config")
	pos1.fs.mkdir("/home/pos/POS1/logs")

	pos1.fs.write_file("/home/pos/POS1/config/terminal.ini",
		"terminal_id=POS1\nstore=CoffeeShop\nmode=card_present\n"
	)
	pos1.fs.write_file("/home/pos/POS1/logs/shift.log",
		"[SHIFT] open=06:00 close=14:00\n[WARN] paper low\n[OK] batch settled\n"
	)
	pos1.fs.write_file("/home/pos/POS1/receipts/receipt_000421.txt",
		"LATTE  $5.75\nTIP    $1.00\nTOTAL  $6.75\nCARD   **** **** **** 1842\nAUTH   apv_REDACTED_420001\n"
	)
	
	pos1.fs.mkdir("/home/pos/POS1/updates")
	pos1.fs.mkdir("/home/pos/POS1/tmp")
	pos1.fs.write_file("/home/pos/POS1/updates/changelog.txt",
		"POS Update Notes\n- UI tweak\n- receipt formatting fix\n"
	)
	pos1.fs.write_file("/home/pos/POS1/tmp/last_error.txt",
		"ERR: printer timeout @ 13:22\nrecovered\n"
	)
	pos1.fs.write_file("/home/pos/POS1/receipts/receipt_000422.txt",
		"ESPRESSO $3.25\nTIP     $0.50\nTOTAL   $3.75\nCARD    **** **** **** 0773\nAUTH    apv_REDACTED_420019\n"
	)
	pos1.fs.write_file("/home/pos/POS1/logs/network.log",
		"eth0 up\nconnected to CoffeeShopWiFi\nupload queued\n"
	)

	
	pos1.attach_to_network(cafe)


	# POS 2 #
	var pos2 := Device.new()
	pos2.hostname = "pos-terminal-2"
	pos2.hack_chance = 0.60
	pos2.hwtype = "ether"
	pos2.iface = "eth0"

	pos2.fs.mkdir("/home")
	pos2.fs.mkdir("/home/pos")
	pos2.fs.mkdir("/home/pos/POS2")
	pos2.fs.mkdir("/home/pos/POS2/receipts")
	pos2.fs.mkdir("/home/pos/POS2/config")
	pos2.fs.mkdir("/home/pos/POS2/logs")
	pos2.fs.mkdir("/home/pos/POS2/updates")
	pos2.fs.mkdir("/home/pos/POS2/tmp")
	pos2.fs.write_file("/home/pos/POS2/updates/changelog.txt",
		"POS Update Notes\n- new tax rates\n- receipt footer update\n"
	)
	pos2.fs.write_file("/home/pos/POS2/tmp/last_error.txt",
		"WARN: drawer opened outside sale @ 16:40\n"
	)
	pos2.fs.write_file("/home/pos/POS2/receipts/receipt_000588.txt",
		"MOCHA   $6.50\nTIP     $2.00\nTOTAL   $8.50\nCARD    **** **** **** 4311\nAUTH    apv_REDACTED_420014\n"
	)
	pos2.fs.write_file("/home/pos/POS2/logs/upload.log",
		"queued: receipts\nqueued: shift.log\nuploaded: ok\n"
	)

	pos2.fs.write_file("/home/pos/POS2/config/terminal.ini",
		"terminal_id=POS2\nstore=CoffeeShop\nmode=card_present\n"
	)
	pos2.fs.write_file("/home/pos/POS2/logs/shift.log",
		"[SHIFT] open=14:00 close=22:00\n[OK] drawer balanced\n[OK] batch settled\n"
	)
	pos2.fs.write_file("/home/pos/POS2/receipts/receipt_000587.txt",
		"COLD BREW $4.25\nTOTAL    $4.25\nCARD     **** **** **** 9920\nAUTH     apv_REDACTED_420002\n"
	)

	pos2.attach_to_network(cafe)







	# =================================================
	# LAPTOPS (mid)
	# =================================================
	var study_laptop := Device.new()
	study_laptop.hostname = "study-laptop"
	study_laptop.hack_chance = 0.35
	study_laptop.hwtype = "wifi"
	study_laptop.iface = "wlan0"

	study_laptop.fs.mkdir("/home")
	study_laptop.fs.mkdir("/home/alex")
	study_laptop.fs.mkdir("/home/alex/Documents")
	study_laptop.fs.mkdir("/home/alex/Downloads")
	study_laptop.fs.mkdir("/home/alex/Pictures")
	study_laptop.fs.mkdir("/home/alex/Projects")
	study_laptop.fs.mkdir("/home/alex/Notes")
	study_laptop.fs.mkdir("/home/alex/Pictures/Memes")
	study_laptop.fs.mkdir("/home/alex/Projects/school")
	study_laptop.fs.write_file("/home/alex/Notes/passwords.txt",
		"wifi: CoffeeShopWiFi (open)\n" +
		"email: alex@***REDACTED***\n" +
		"pw hint: \"same as old one\"\n"
	)
	study_laptop.fs.write_file("/home/alex/Projects/school/networks_lab.md",
		"# Networks Lab\n- ARP table shows local devices\n- open wifi = risky\n"
	)
	study_laptop.fs.write_file("/home/alex/Pictures/Memes/funny.png", "PNG_BINARY_PLACEHOLDER")
	study_laptop.fs.write_file("/home/alex/Downloads/receipt_email.eml",
		"From: receipts@coffeeshop\nSubject: Your receipt\nTotal: $6.75\nCard: **** **** **** 1842\n"
	)

	study_laptop.fs.write_file("/home/alex/Documents/resume_draft.txt",
		"Resume Draft\n- Update skills section\n- Add internship experience\n"
	)
	study_laptop.fs.write_file("/home/alex/Projects/todo.md",
		"- [ ] finish homework\n- [ ] push repo changes\n- [ ] buy beans\n"
	)
	study_laptop.fs.write_file("/home/alex/Downloads/cafe_wifi_terms.txt",
		"CoffeeShopWiFi Terms: OPEN network. Use at your own risk.\n"
	)

	study_laptop.attach_to_network(cafe)

	var work_laptop := Device.new()
	work_laptop.hostname = "work-laptop"
	work_laptop.hack_chance = 0.30
	work_laptop.hwtype = "wifi"
	work_laptop.iface = "wlp2so"
	
	
	work_laptop.fs.mkdir("/home")
	work_laptop.fs.mkdir("/home/morgan")
	work_laptop.fs.mkdir("/home/morgan/Documents")
	work_laptop.fs.mkdir("/home/morgan/Downloads")
	work_laptop.fs.mkdir("/home/morgan/Documents/Finance")
	work_laptop.fs.mkdir("/home/morgan/Documents/Clients")
	work_laptop.fs.mkdir("/home/morgan/Desktop")
	work_laptop.fs.write_file("/home/morgan/Desktop/quick_note.txt",
		"Call bank about chargebacks\n(yes, again)\n"
	)
	work_laptop.fs.write_file("/home/morgan/Documents/Clients/client_list.txt",
		"Clients:\n- ***REDACTED***\n- ***REDACTED***\n"
	)
	work_laptop.fs.write_file("/home/morgan/Documents/Finance/expense_report_q1.txt",
		"Expense Report (Q1)\n" +
		"- CoffeeShop: $42.10\n" +
		"Card on file: **** **** **** 3392\n" +
		"Exp: 08/26\n" +
		"CVV: ***REDACTED***\n" +
		"Token: pm_REDACTED_108\n"
	)
	work_laptop.fs.write_file("/home/morgan/Downloads/budget.xlsx", "XLSX_BINARY_PLACEHOLDER")

	work_laptop.fs.write_file("/home/morgan/Documents/meeting_notes.txt",
		"Meeting Notes:\n- finalize proposal\n- send invoice\n"
	)
	work_laptop.fs.write_file("/home/morgan/Downloads/invoice_template.docx",
		"DOCX_BINARY_PLACEHOLDER"
	)

	work_laptop.attach_to_network(cafe)


	var jacks_laptop := Device.new()
	jacks_laptop.hostname = "Jack's Porn Stash"
	jacks_laptop.hack_chance = 0.01
	jacks_laptop.mac = jacks_laptop.get_mac()
	jacks_laptop.hwtype = "bt"
	jacks_laptop.iface = "wlan0"
	
	
	jacks_laptop.fs.mkdir("/home/stash")
	jacks_laptop.fs.write_file(
		"/home/stash/myeyesonly.txt",
		"I sure hope nobody finds these files...\n\n\n . . . they're hentai. . ."
	)
	jacks_laptop.fs.write_file(
		"/home/stash/CallOfBooty-BlackCocks5.vid",
		"video file"
	)
	jacks_laptop.attach_to_network(cafe)
	# =================================================
	# PHONES (high hack chance)
	# =================================================
	var phone_jules := Device.new()
	phone_jules.hostname = "phone-jules"
	phone_jules.hack_chance = 0.80
	phone_jules.hwtype = "cell"
	phone_jules.iface = "wwan0"

	phone_jules.fs.mkdir("/home")
	phone_jules.fs.mkdir("/home/jules")
	phone_jules.fs.mkdir("/home/jules/DCIM")
	phone_jules.fs.mkdir("/home/jules/DCIM/Camera")
	phone_jules.fs.mkdir("/home/jules/Downloads")
	phone_jules.fs.mkdir("/home/jules/Documents")
	phone_jules.fs.mkdir("/home/jules/Apps")
	phone_jules.fs.mkdir("/home/jules/Apps/Chat")
	phone_jules.fs.mkdir("/home/jules/Apps/Banking")
	phone_jules.fs.mkdir("/home/jules/texts")
	phone_jules.fs.write_file("/home/jules/texts/thread_001_friend.txt",
		"[thread: friend]\n" +
		"09:12 jules: omw\n" +
		"09:31 friend: don't connect to open wifi\n" +
		"09:32 jules: too late lol\n"
	)
	phone_jules.fs.write_file("/home/jules/texts/thread_002_bank.txt",
		"[thread: bank]\n" +
		"NOTICE: New login detected.\n" +
		"Card: **** **** **** 1234\n" +
		"CVV: ***REDACTED***\n"
	)
	phone_jules.fs.write_file("/home/jules/Downloads/coffee_coupon.png", "PNG_BINARY_PLACEHOLDER")
	phone_jules.fs.write_file("/home/jules/Documents/random_note.txt",
		"reminder: change password (later)\n"
	)

	phone_jules.fs.write_file("/home/jules/DCIM/Camera/IMG_1001.jpg", "JPEG_BINARY_PLACEHOLDER")
	phone_jules.fs.write_file("/home/jules/DCIM/Camera/IMG_1002.jpg", "JPEG_BINARY_PLACEHOLDER")
	phone_jules.fs.write_file("/home/jules/Apps/Chat/messages_cache.log",
		"09:12 jules: omw\n09:28 jules: grabbing coffee\n09:31 friend: bet\n"
	)
	phone_jules.fs.write_file("/home/jules/Apps/Banking/session_cache.json",
		"{\"user\":\"jules\",\"card_masked\":\"**** **** **** 1234\",\"payment_token\":\"tok_live_REDACTED\",\"pin\":\"REDACTED\",\"cvv\":\"REDACTED\",\"exp\":\"REDACTED\"}\n"
	)

	phone_jules.attach_to_network(cafe)

	var phone_sam := Device.new()
	phone_sam.hostname = "phone-sam"
	phone_sam.hack_chance = 0.75
	phone_sam.hwtype = "cell"
	phone_sam.iface = "wwan0"

	phone_sam.fs.mkdir("/home")
	phone_sam.fs.mkdir("/home/sam")
	phone_sam.fs.mkdir("/home/sam/DCIM")
	phone_sam.fs.mkdir("/home/sam/DCIM/Camera")
	phone_sam.fs.mkdir("/home/sam/Documents")
	phone_sam.fs.mkdir("/home/sam/Apps")
	phone_sam.fs.mkdir("/home/sam/Apps/Chat")
	phone_sam.fs.mkdir("/home/sam/texts")
	phone_sam.fs.write_file("/home/sam/texts/thread_001_coworker.txt",
		"[thread: coworker]\n" +
		"10:03 sam: at the cafe\n" +
		"10:05 coworker: open wifi is sketch\n" +
		"10:06 sam: i just need to send a file\n"
	)
	phone_sam.fs.write_file("/home/sam/texts/thread_002_mom.txt",
		"[thread: mom]\n" +
		"Mom: did you pay the phone bill?\n" +
		"Sam: yes (i think)\n"
	)
	phone_sam.fs.write_file("/home/sam/Downloads/screenshot_login.png", "PNG_BINARY_PLACEHOLDER")

	phone_sam.fs.write_file("/home/sam/DCIM/Camera/IMG_2044.jpg", "JPEG_BINARY_PLACEHOLDER")
	phone_sam.fs.write_file("/home/sam/Documents/notes.txt", "dont forget charger\n")
	phone_sam.fs.write_file("/home/sam/Apps/Chat/messages_cache.log",
		"10:03 sam: at the cafe\n10:05 coworker: dont use open wifi lol\n"
	)

	phone_sam.attach_to_network(cafe)

	var phone_kai := Device.new()
	phone_kai.hostname = "phone-kai"
	phone_kai.hack_chance = 0.85
	phone_kai.hwtype = "cell"
	phone_kai.iface = "cell0"

	phone_kai.fs.mkdir("/home")
	phone_kai.fs.mkdir("/home/kai")
	phone_kai.fs.mkdir("/home/kai/DCIM")
	phone_kai.fs.mkdir("/home/kai/DCIM/Camera")
	phone_kai.fs.mkdir("/home/kai/Downloads")
	phone_kai.fs.mkdir("/home/kai/Apps")
	phone_kai.fs.mkdir("/home/kai/Apps/Photos")
	phone_kai.fs.mkdir("/home/kai/texts")
	phone_kai.fs.write_file("/home/kai/texts/thread_001_roommate.txt",
		"[thread: roommate]\n" +
		"Kai: i'm at coffeeshop\n" +
		"Roommate: grab oat milk pls\n"
	)
	phone_kai.fs.write_file("/home/kai/texts/thread_002_misc.txt",
		"[thread: misc]\n" +
		"Reminder: update phone OS\n"
	)
	phone_kai.fs.write_file("/home/kai/Downloads/wifi_passwords.txt",
		"StaffNet pw: ***REDACTED***\n"
	)

	phone_kai.fs.write_file("/home/kai/DCIM/Camera/VID_3001.mp4", "MP4_BINARY_PLACEHOLDER")
	phone_kai.fs.write_file("/home/kai/Downloads/map_screenshot.png", "PNG_BINARY_PLACEHOLDER")
	phone_kai.fs.write_file("/home/kai/Apps/Photos/cache.db", "SQLITE_PLACEHOLDER")

	phone_kai.attach_to_network(cafe)

	var phone_nina := Device.new()
	phone_nina.hostname = "phone-nina"
	phone_nina.hack_chance = 0.70
	phone_nina.hwtype = "cell"
	phone_nina.iface = "wwan0"

	phone_nina.fs.mkdir("/system")
	phone_nina.fs.mkdir("/system/nina")
	phone_nina.fs.mkdir("/system/nina/Documents")
	phone_nina.fs.mkdir("/system/nina/DCIM")
	phone_nina.fs.mkdir("/system/nina/DCIM/Camera")
	phone_nina.fs.mkdir("/system/nina/texts")
	phone_nina.fs.mkdir("/system/nina/Downloads")
	phone_nina.fs.write_file("/system/nina/texts/thread_001_journalish.txt",
		"[thread: self]\n" +
		"nina: stop doomscrolling\n" +
		"nina: also stop saving passwords\n"
	)
	phone_nina.fs.write_file("/system/nina/Downloads/receipt.txt",
		"CoffeeShopWiFi\nTotal: $8.50\nCard: **** **** **** 4311\n"
	)

	phone_nina.fs.write_file("/system/nina/Documents/journal.txt",
		"journal\n- coffee was good\n- need to stop doomscrolling\n"
	)
	phone_nina.fs.write_file("/system/nina/DCIM/Camera/IMG_0402.jpg", "JPEG_BINARY_PLACEHOLDER")

	phone_nina.attach_to_network(cafe)

	var phone_lee := Device.new()
	phone_lee.hostname = "phone-lee"
	phone_lee.hack_chance = 0.78
	phone_lee.hwtype = "cell"
	phone_lee.iface = "cell0"
	

	phone_lee.fs.mkdir("/system")
	phone_lee.fs.mkdir("/system/lee")
	phone_lee.fs.mkdir("/system/lee/Downloads")
	phone_lee.fs.mkdir("/system/lee/texts")
	phone_lee.fs.mkdir("/system/lee/DCIM")
	phone_lee.fs.mkdir("/system/lee/DCIM/Camera")

	phone_lee.fs.write_file("/system/lee/texts/thread_001_friend.txt",
		"[thread: friend]\n" +
		"Lee: coffee then gym?\n" +
		"Friend: bet\n"
	)
	phone_lee.fs.write_file("/system/lee/texts/thread_002_work.txt",
		"[thread: work]\n" +
		"Reminder: submit invoice\n" +
		"Also: don't use open networks\n"
	)
	phone_lee.fs.write_file("/system/lee/DCIM/Camera/IMG_0101.jpg", "JPEG_BINARY_PLACEHOLDER")

	phone_lee.fs.write_file("/system/lee/Downloads/qr_ticket.png", "PNG_BINARY_PLACEHOLDER")
	phone_lee.fs.write_file("/system/lee/Downloads/receipt.txt",
		"CoffeeShopWiFi\nTotal: $3.75\nPaid: card **** **** **** 0773\n"
	)

	phone_lee.attach_to_network(cafe)

	var phone_taylor := Device.new()
	phone_taylor.hostname = "phone-taylor"
	phone_taylor.hack_chance = 0.82
	phone_taylor.hwtype = "cell"
	phone_taylor.iface = "cell0"

	phone_taylor.fs.mkdir("/system")
	phone_taylor.fs.mkdir("/system/taylor")
	phone_taylor.fs.mkdir("/system/taylor/DCIM")
	phone_taylor.fs.mkdir("/system/taylor/DCIM/Camera")
	phone_taylor.fs.mkdir("/system/taylor/texts")
	phone_taylor.fs.mkdir("/system/taylor/Downloads")

	phone_taylor.fs.write_file("/system/taylor/texts/thread_001_partner.txt",
		"[thread: partner]\n" +
		"Taylor: running late\n" +
		"Partner: again?? lol\n"
	)
	phone_taylor.fs.write_file("/system/taylor/texts/thread_002_bankish.txt",
		"[thread: banking]\n" +
		"Saved payment: **** **** **** 6409\n" +
		"Exp: 09/28\n" +
		"CVV: ***REDACTED***\n"
	)
	phone_taylor.fs.write_file("/system/taylor/Downloads/parking_ticket.jpg", "JPEG_BINARY_PLACEHOLDER")

	phone_taylor.fs.write_file("/system/taylor/DCIM/Camera/IMG_9001.jpg", "JPEG_BINARY_PLACEHOLDER")
	phone_taylor.fs.write_file("/system/taylor/DCIM/Camera/IMG_9002.jpg", "JPEG_BINARY_PLACEHOLDER")

	phone_taylor.attach_to_network(cafe)

	var phone_riley := Device.new()
	phone_riley.hostname = "phone-riley"
	phone_riley.hack_chance = 0.74
	phone_riley.hwtype = "cell"
	phone_riley.iface = "cell0"

	phone_riley.fs.mkdir("/home")
	phone_riley.fs.mkdir("/home/riley")
	phone_riley.fs.mkdir("/home/riley/Documents")
	phone_riley.fs.mkdir("/home/riley/texts")
	phone_riley.fs.mkdir("/home/riley/DCIM")
	phone_riley.fs.mkdir("/home/riley/DCIM/Camera")
	phone_riley.fs.mkdir("/home/riley/Downloads")

	phone_riley.fs.write_file("/home/riley/texts/thread_001_groupchat.txt",
		"[thread: groupchat]\n" +
		"riley: coffee is mid today\n" +
		"someone: stop hating lol\n"
	)
	phone_riley.fs.write_file("/home/riley/texts/thread_002_notes.txt",
		"[thread: notes]\n" +
		"todo: cancel subscription\n"
	)
	phone_riley.fs.write_file("/home/riley/DCIM/Camera/IMG_7777.jpg", "JPEG_BINARY_PLACEHOLDER")
	phone_riley.fs.write_file("/home/riley/Downloads/cafe_map.png", "PNG_BINARY_PLACEHOLDER")

	phone_riley.fs.write_file("/home/riley/Documents/todo.txt",
		"- buy beans\n- call mom\n- finish assignment\n"
	)

	phone_riley.attach_to_network(cafe)
