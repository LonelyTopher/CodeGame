extends CommandBase
class_name CmdHostname

# Optional: tune these rules however you want
const MAX_LEN := 32

func get_name() -> String:
	return "hostname"

func get_help() -> String:
	return "Print or set the name of the current host."

func get_usage() -> String:
	return "hostname [--set <name> | <name>] [--reset]"

func get_examples() -> Array[String]:
	return [
		"hostname",
		"hostname corp-node-7",
		"hostname --set corp-node-7",
		"hostname --reset"
	]

func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-s", "long":"--set",   "desc":"Set the current host name. Usage: --set <name>"},
		{"flag":"-r", "long":"--reset", "desc":"Reset hostname back to the device default (if available)."},
	]

func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	var device: Device = World.current_device
	if device == null:
		return ["hostname: unknown host"]

	# No args -> print hostname (existing behavior)
	if _args.is_empty():
		return [device.hostname]

	# Parse flags / args
	var want_reset := false
	var set_name := ""
	var i := 0

	while i < _args.size():
		var a := _args[i]

		match a:
			"-r", "--reset":
				want_reset = true

			"-s", "--set":
				# require next arg
				if i + 1 >= _args.size():
					return ["hostname: missing name after %s" % a]
				set_name = _args[i + 1]
				i += 1 # consume the value

			_:
				# If it's not a flag, treat it as a positional hostname set
				# Example: hostname my-box
				if a.begins_with("-"):
					return ["hostname: unknown option: %s" % a]
				# If multiple positional args are provided, that's likely a mistake
				if set_name != "":
					return ["hostname: too many arguments"]
				set_name = a

		i += 1

	# Handle reset (wins if provided)
	if want_reset:
		# If your Device has a "default_hostname" field, use it.
		# Otherwise fall back to a generic default.
		if device.has_method("get_default_hostname"):
			device.hostname = device.get_default_hostname()
		elif "default_hostname" in device:
			device.hostname = device.default_hostname
		else:
			device.hostname = "localhost"
		return ["hostname set to %s" % device.hostname]

	# If no set name was supplied, just print (covers cases like only flags that don't set)
	if set_name == "":
		return [device.hostname]

	# Validate the hostname before setting
	var err := _validate_hostname(set_name)
	if err != "":
		return ["hostname: %s" % err]

	device.hostname = set_name
	return ["hostname set to %s" % device.hostname]


func _validate_hostname(name: String) -> String:
	var n := name.strip_edges()
	if n.is_empty():
		return "hostname cannot be empty"
	if n.length() > MAX_LEN:
		return "hostname too long (max %d chars)" % MAX_LEN

	# Common hostname rules: letters, digits, hyphen; no spaces; can't start/end with hyphen.
	# (You can loosen/tighten this whenever.)
	if n.begins_with("-") or n.ends_with("-"):
		return "hostname cannot start or end with '-'"

	for ch in n:
		var ok := (
			(ch >= "a" and ch <= "z") or
			(ch >= "A" and ch <= "Z") or
			(ch >= "0" and ch <= "9") or
			ch == "-"
		)
		if not ok:
			return "invalid character '%s' (use letters, numbers, '-')" % ch

	return ""
