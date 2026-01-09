extends CommandBase
class_name CmdMinigame

# Debug/test launcher for the password cracking minigame.
#
# Usage:
#   minigame
#   minigame <ip>
#   minigame <ip> <hack_chance>
#
# Default behavior (when ONLY "minigame" is typed):
# - target IP becomes "<current_network_base>.1" (router)
# - hack_chance forced to 0.99 (easy)

func get_name() -> String:
	return "minigame"

func get_aliases() -> Array[String]:
	return ["mg"]

func get_help() -> String:
	return "Launch the password cracking minigame (debug/test)."

func get_usage() -> String:
	return "minigame [ip] [hack_chance]"

func get_examples() -> Array[String]:
	return [
		"minigame",
		"minigame 12.146.72.7",
		"minigame 12.146.72.7 0.55"
	]

func get_category() -> String:
	return "DEBUG"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var me: Device = terminal.current_device
	if me == null or me.network == null:
		return ["minigame: no active device/network"]

	var net: Network = me.network

	# ------------------------------------------------------------
	# Resolve IP + difficulty
	# ------------------------------------------------------------
	var ip := ""
	var hack_chance: float = 0.99

	if args.size() == 0:
		ip = _router_ip_from_me_or_net(me, net)
		hack_chance = 0.99
	else:
		ip = args[0]
		if args.size() >= 2:
			hack_chance = clamp(float(args[1]), 0.01, 0.99)

	# ------------------------------------------------------------
	# Find target device on this LAN by IP
	# ------------------------------------------------------------
	var target: Device = null
	for d in net.devices:
		if d != null and str(d.ip_address) == ip:
			target = d
			break

	if target == null:
		return ["minigame: could not resolve host " + ip]

	# Optional: store override meta for debugging
	target.set_meta("minigame_hack_chance_override", hack_chance)

	# ------------------------------------------------------------
	# Find minigame manager/autoload
	# ------------------------------------------------------------
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["minigame: internal error (no SceneTree)"]

	var root := tree.get_root()
	if root == null:
		return ["minigame: internal error (no root)"]

	var mgr: Node = _find_minigame_manager(root)
	if mgr == null:
		return [
			"minigame: could not find minigame manager/autoload.",
			"Tip: add an Autoload named 'HackingMinigame' pointing to:",
			"  res://Systems/HackingMinigame/pswd_cracking_minigame.gd"
		]

	# ------------------------------------------------------------
	# Launch the minigame UI
	# We support two patterns:
	#  A) mgr.open_minigame(terminal, target, hack_chance, me) -> Node (preferred)
	#  B) mgr.setup_and_generate(...) on a Control already in the tree
	# ------------------------------------------------------------
	var src: Device = me
	var instance: Node = null

	if mgr.has_method("open_minigame"):
		# Preferred: manager spawns/returns the actual Control instance
		instance = mgr.call("open_minigame", terminal, target, hack_chance, src)
	elif mgr.has_method("setup_and_generate"):
		# Fallback: manager itself is the Control
		mgr.call("setup_and_generate", terminal, target, hack_chance, src)
		instance = mgr
	elif mgr.has_method("start"):
		mgr.call("start", terminal, target, hack_chance, src)
		instance = mgr
	else:
		return ["minigame: manager has no open_minigame()/setup_and_generate()/start() method"]

	# If we got an instance, tell TerminalScreen to route input to it
	if terminal != null and terminal.screen != null and instance != null and is_instance_valid(instance):
		if terminal.screen.has_method("set_active_minigame"):
			terminal.screen.call("set_active_minigame", instance)

	return [
		"Launching minigame against %s (%s)..." % [
			_get_dev_field_str(target, "hostname", "target"),
			_get_dev_field_str(target, "ip_address", "--")
		],
		"Difficulty override: hack_chance=%.2f (higher = easier)" % hack_chance,
		"Target: %s  Source: %s" % [
			str(ip),
			_get_dev_field_str(me, "ip_address", "--")
		],
		"(debug) Use mouse OR type commands in the input line (once wired).",
		""
	]


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

func _find_minigame_manager(root: Node) -> Node:
	# Fast path: common autoload names
	var by_name := [
		"HackingMinigame",
		"PasswordCracker",
		"PswdCrackingMinigame",
		"Minigame",
		"MiniGame"
	]
	for n in by_name:
		var node := root.get_node_or_null(n)
		if node != null:
			return node

	# Fallback: scan root children
	for child in root.get_children():
		if child == null:
			continue
		if child.has_method("open_minigame") or child.has_method("setup_and_generate") or child.has_method("start"):
			return child

	return null


func _router_ip_from_me_or_net(me: Device, net: Network) -> String:
	var my_ip := _get_dev_field_str(me, "ip_address", "")
	if my_ip != "":
		var parts := my_ip.split(".")
		if parts.size() == 4:
			return "%s.%s.%s.1" % [parts[0], parts[1], parts[2]]

	var cidr := str(_get_net_field(net, "subnet", ""))
	if cidr.find("/") != -1:
		var base := cidr.split("/")[0]
		var p := base.split(".")
		if p.size() == 4:
			return "%s.%s.%s.1" % [p[0], p[1], p[2]]

	return "0.0.0.1"


func _get_dev_field_str(d: Object, field: String, fallback: String) -> String:
	if d == null:
		return fallback
	if field in d:
		var v = d.get(field)
		if v == null:
			return fallback
		var s := str(v)
		return fallback if s == "" else s
	if d.has_meta(field):
		var mv = d.get_meta(field)
		if mv == null:
			return fallback
		var ms := str(mv)
		return fallback if ms == "" else ms
	return fallback


func _get_net_field(net: Object, field: String, fallback):
	if net == null:
		return fallback
	if field in net:
		var v = net.get(field)
		return fallback if v == null else v
	if net.has_meta(field):
		var mv = net.get_meta(field)
		return fallback if mv == null else mv
	return fallback
