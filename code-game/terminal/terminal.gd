extends RefCounted
class_name Terminal

# For setting the length of output lines letters #
var term_width: int = 90

# Command name/alias -> CommandBase
var commands: Dictionary = {}

# Active filesystem + current working directory (always tied to current_device)
var fs: FileSystem = null
var cwd: String = "/"

# Device Stack (for ssh/exit backtracking)
var device_stack: Array[Device] = []
var current_device: Device = null
var screen: Node = null


# -------------------------------------------------
# Device Context Helpers
# -------------------------------------------------
# Set the "active" device this terminal is operating on.
# If reset_stack is true, this becomes the base device (stack = [device]).
func set_active_device(device: Device, reset_stack: bool = false) -> void:
	current_device = device

	if reset_stack:
		device_stack.clear()
		if device != null:
			device_stack.append(device)

	# Keep filesystem pointer synced to the active device
	if device != null:
		fs = device.fs
		# If device has no filesystem (shouldn't happen if Device.super() runs),
		# create one as a safety net so commands don't crash.
		if fs == null:
			fs = FileSystem.new()
			fs.mkdir("/home")
			device.fs = fs

		# Ensure cwd is sane for this device
		if cwd == "" or cwd == "/" or not fs.is_dir(cwd):
			cwd = "/home"
	else:
		# No device means no fs
		fs = null
		cwd = "/"


# Optional: push a new device onto the stack (for ssh)
func push_device(device: Device) -> void:
	if device == null:
		return
	if current_device != null:
		device_stack.append(device)
	set_active_device(device, false)

# Optional: pop back to previous device (for exit)
func pop_device() -> Device:
	if device_stack.size() <= 1:
		return null

	# Remove current
	device_stack.pop_back()

	# Switch to new top
	var back: Device = device_stack.back()
	set_active_device(back, false)
	return back


# -------------------------------------------------
# Command Registration / Execution
# -------------------------------------------------
func register_command(cmd: CommandBase) -> void:
	commands[cmd.get_name()] = cmd
	for a in cmd.get_aliases():
		commands[a] = cmd


func execute(line: String) -> Array[String]:
	var text := line.strip_edges()
	if text.is_empty():
		return []

	var parts := text.split(" ", false)
	var name := parts[0].to_lower()

	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	if not commands.has(name):
		return ["Unknown command: " + parts[0]]

	# Safety: keep fs synced (in case something changed current_device directly)
	if current_device != null:
		if fs == null or fs != current_device.fs:
			fs = current_device.fs

		# Safety net to prevent nil crashes
		if fs == null:
			fs = FileSystem.new()
			fs.mkdir("/home")
			current_device.fs = fs

		if cwd == "" or cwd == "/":
			cwd = "/home"

	var cmd: CommandBase = commands[name]

	# -------------------------------------------------
	# NEW: allow commands to be async (contain `await`)
	# If run() is normal sync, this returns immediately.
	# -------------------------------------------------
	var out = await cmd.run(args, self)

	# Safety: guarantee we always return Array[String]
	if out is Array:
		return out
	return [str(out)]



func load_commands_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Terminal: Could not open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		# Skip folders and non-gd files
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var full_path := dir_path.rstrip("/") + "/" + file_name
			var script := load(full_path)

			if script is Script:
				var obj = script.new()
				if obj is CommandBase:
					register_command(obj)

		file_name = dir.get_next()

	dir.list_dir_end()


# -------------------------------------------------
# Path Helpers
# -------------------------------------------------
func resolve_path(input_path: String) -> String:
	var p := input_path.strip_edges()
	if p == "" or p == ".":
		return cwd
	if p.begins_with("/"):
		return p
	# relative
	if cwd == "/":
		return "/" + p
	return cwd.rstrip("/") + "/" + p


func get_unique_command_names() -> Array[String]:
	var unique := {} # name -> true
	for key in commands.keys():
		var cmd: CommandBase = commands[key]
		unique[cmd.get_name()] = true

	var names: Array[String] = []
	for k in unique.keys():
		names.append(String(k))
	return names


# -------------------------------------------------
# Save / Load (Terminal State)
# NOTE: This saves terminal view state only (cwd + filesystem root).
# Devices/network identity saving is separate.
# -------------------------------------------------
func get_state() -> Dictionary:
	return {
		"version": 1,
		"cwd": cwd,
		"fs": (fs.root if fs != null else {})
	}


func set_state(data: Dictionary) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("fs"):
		return false

	var fs_data = data["fs"]
	if typeof(fs_data) != TYPE_DICTIONARY:
		return false

	# You must already have a filesystem instance to restore into
	if fs == null:
		fs = FileSystem.new()
		if current_device != null:
			current_device.fs = fs

	fs.root = fs_data
	cwd = str(data.get("cwd", "/home"))

	# Keep cwd valid
	if fs != null and not fs.is_dir(cwd):
		cwd = "/home"

	return true
