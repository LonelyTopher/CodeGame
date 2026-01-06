extends Device
class_name PlayerHomeComputer

func _init() -> void:
	super._init() # ensures Device._init() runs, so fs exists + "/home" exists (per our updated Device.gd)

	hostname = "New-Laptop"
	
	# ARP IDENDTITY #
	
	hwtype = "wifi"
	iface = "wlan0"
	netmask = "255.255.255.0"
	arp_state = "REACHABLE"
	arp_flags = "C"


# --- FILESYSTEM --- #
# --- DIRSFIRST --- #

	fs.mkdir("/system")
	fs.mkdir("/home/downloads")
	fs.mkdir("/home/local")

# --- FILES --- #

	fs.write_file("/home/readme.txt", "welcome home\n")
