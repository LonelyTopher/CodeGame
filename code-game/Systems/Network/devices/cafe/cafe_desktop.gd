extends Device
class_name CafeDesktop

func _init():
	super._init()  # ✅ creates fs, ip_address, network hooks, etc.

	# --- Identity ---
	
	hostname = "cafe-desktop"
	mac = _generate_mac()
	online = true
	hack_chance = 0.65 # 65% chance to hack
	hack_xp_first = 25
	hack_xp_repeat = 3
	was_hacked = false

	# --- Filesystem layout ---

	# Standard user directories
	fs.mkdir("/home")
	fs.mkdir("/home/barista")
	fs.mkdir("/home/barista/Documents")
	fs.mkdir("/home/barista/Downloads")

	# System directories
	fs.mkdir("/etc")
	fs.mkdir("/var")
	fs.mkdir("/var/log")

	# --- User files (loot 👀) ---
	fs.write_file(
		"/home/barista/Documents/passwords.txt",
		"""
facebook: barista1989
email: latte_love!
bank: savings123
"""
	)

	fs.write_file(
		"/home/barista/Documents/notes.txt",
		"Remember to change the WiFi password next week."
	)
