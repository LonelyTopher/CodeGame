extends Device
class_name PlayerHomeComputer

func _init() -> void:
	super() # <-- IMPORTANT: runs Device._init() so fs is created

	hostname = "New-Laptop"

	# OPTIONAL: add a more "laptop-ish" filesystem layout
	fs.mkdir("/home/user")
	fs.mkdir("/home/user/Documents")
	fs.mkdir("/home/user/Downloads")

	# Example starter files (only if your FileSystem supports write_file)
	fs.write_file("/home/user/readme.txt", "welcome home\n")
