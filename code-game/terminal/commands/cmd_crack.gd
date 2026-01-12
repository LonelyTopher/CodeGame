extends CommandBase
class_name CmdCrack

func get_name() -> String:
	return "crack"

func get_help() -> String:
	return "Attempt to crack a password-locked directory."

func get_usage() -> String:
	return "crack <path>"

func get_examples() -> Array[String]:
	return [
		"crack /system",
		"crack secret",
		"crack /home/.vault"
	]

func get_category() -> String:
	return "SECURITY"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["usage: " + get_usage()]

	if terminal == null or terminal.fs == null:
		return ["crack: filesystem not available"]

	var target_path := terminal.resolve_path(args[0])

	if not terminal.fs.is_dir(target_path):
		return ["crack: not a directory: " + args[0]]

	if not terminal.fs.has_method("is_locked") or not terminal.fs.has_method("unlock_dir"):
		return ["crack: this build does not support locked directories"]

	if not terminal.fs.is_locked(target_path):
		return ["crack: directory is not locked: " + target_path]

	# Launch minigame (same object used for SSH/WiFi, but target is a dir-lock dictionary)
	var mg := PswdCrackingMinigame.new()

	# source device is optional; keep null-safe
	var src: Device = null
	if "get_player_device" in World:
		src = World.get_player_device

	# "target" is a dictionary that tells the minigame we are cracking a directory lock
	var crack_target := {"kind": "dir_lock", "path": target_path}

	# hack chance controls tier; pick something decent (you can tune later)
	mg.setup_and_generate(terminal, crack_target, 0.60, src, 10)

	return [
		"> initializing crack session...",
		"> target: %s" % target_path,
		"> mode: directory lock"
	]
