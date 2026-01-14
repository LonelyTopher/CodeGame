extends CommandBase
class_name CmdConnect

const MAX_NEIGHBOR_DISTANCE := 2
const INVALID_NEIGHBOR_ID := -1

func get_name() -> String:
	return "connect"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Connect to a wireless network (SSID)."

func get_usage() -> String:
	return "connect <ssid>"

func get_examples() -> Array[String]:
	return [
		"connect HomeNet",
		"connect CoffeeShopWiFi"
	]

func get_options() -> Array[Dictionary]:
	return []

func get_category() -> String:
	return "NETWORK"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var d: Device = terminal.current_device
	if d == null:
		return ["connect: no active device"]

	if args.size() != 1:
		return ["usage: " + get_usage()]

	var ssid := args[0]

	# Get all known networks in the world
	var nets: Array = World.get_networks()
	if nets == null or nets.is_empty():
		return ["connect: no networks available"]

	var target: Network = null
	for n in nets:
		if String(n.name) == ssid:
			target = n
			break

	if target == null:
		return ["connect: network not found: " + ssid]

	if d.network == target:
		return ["connect: already connected to " + ssid]

	# -------------------------------------------------
	# RANGE / PROGRESSION GATE (neighbor_id distance)
	# -------------------------------------------------
	var target_neighbor_id: int = _get_neighbor_id_int(target, INVALID_NEIGHBOR_ID)
	if target_neighbor_id == INVALID_NEIGHBOR_ID:
		return ["connect: network '%s' is missing neighbor_id (cannot validate range)" % ssid]

	var anchor_neighbor_id: int = INVALID_NEIGHBOR_ID
	if d.network != null:
		anchor_neighbor_id = _get_neighbor_id_int(d.network, INVALID_NEIGHBOR_ID)
	else:
		anchor_neighbor_id = _get_device_start_neighbor_id_int(d, 0) # starting anchor

	# If somehow current network is missing neighbor_id, fall back to start anchor
	if anchor_neighbor_id == INVALID_NEIGHBOR_ID:
		anchor_neighbor_id = _get_device_start_neighbor_id_int(d, 0)

	var dist: int = abs(target_neighbor_id - anchor_neighbor_id)
	if dist > MAX_NEIGHBOR_DISTANCE:
		return [
			"connect: out of range for current access tier",
			"hint: discover closer networks first (scan), or progress deeper into the network map."
		]

	# TerminalScreen access (no get_tree here)
	var screen = terminal.screen
	if screen == null:
		return ["connect: internal error (no terminal screen)"]

	# SceneTree access without get_tree()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["connect: internal error (no SceneTree)"]

	# Always print the "Connecting..." header up front (feels real)
	screen.append_line("Connecting to '%s'..." % ssid)

	# -------------------------------------------------
	# If the network has a password, launch the minigame
	# ONLY if we haven't already hacked this network.
	# -------------------------------------------------
	var pw := _get_network_password(target)
	var needs_auth := _has_password(pw)

	# Read was_hacked safely (works even if property doesn't exist yet)
	var was_hacked := false
	if "was_hacked" in target:
		was_hacked = bool(target.get("was_hacked"))
	elif target.has_meta("was_hacked"):
		was_hacked = bool(target.get_meta("was_hacked"))

	# Only prompt for auth if passworded AND not already hacked
	if needs_auth and not was_hacked:
		# Cosmetic progress bar (optional but nice)
		var bar_index: int = screen.append_line("[----------]")
		var total := 10
		for i in range(total):
			await tree.create_timer(0.25).timeout
			var filled := "|".repeat(i + 1)
			var empty := "-".repeat(total - i - 1)
			screen.replace_line(bar_index, "[%s%s]" % [filled, empty])

		# Launch minigame
		var mg := PswdCrackingMinigame.new()

		var hack_chance: float = 0.99
		if "hack_chance" in target:
			hack_chance = float(target.hack_chance)
		hack_chance = clamp(hack_chance, 0.0, 1.0)

		mg.setup_and_generate(terminal, target, hack_chance, d, 10)

		var outcome: String = await _await_minigame_result(mg, tree)

		if outcome != "success":
			return [
				"connect: access denied (authentication failed)",
				""
			]

		# Mark hacked
		if "was_hacked" in target:
			target.set("was_hacked", true)
		else:
			target.set_meta("was_hacked", true)

	# -------------------------------------------------
	# SUCCESS PATH
	# -------------------------------------------------
	if d.network != null:
		d.detach_from_network()

	d.attach_to_network(target)

	var lines: Array[String] = []
	lines.append("Network: %s" % target.subnet)
	lines.append("Assigned IP address: %s" % d.ip_address)
	lines.append("")
	lines.append("Hint: run 'arp' to discover devices on this network.")

	return lines


# -------------------------------------------------
# Minigame wait helper: returns "success" | "failed" | "closed"
# FIX: avoid lambda capture reassignment warnings by mutating a shared Dictionary
# -------------------------------------------------
func _await_minigame_result(mg: Object, tree: SceneTree) -> String:
	var state: Dictionary = {
		"done": false,
		"result": "closed"
	}

	mg.connect("crack_success", func():
		state["done"] = true
		state["result"] = "success"
	)
	mg.connect("crack_failed", func():
		state["done"] = true
		state["result"] = "failed"
	)
	mg.connect("crack_closed", func():
		state["done"] = true
		state["result"] = "closed"
	)

	while not bool(state["done"]):
		await tree.process_frame

	return String(state["result"])


# -------------------------------------------------
# neighbor_id helpers that ALWAYS return int (or default)
# This avoids Variant inference warnings being treated as errors.
# -------------------------------------------------
func _get_neighbor_id_int(n: Object, default_value: int = INVALID_NEIGHBOR_ID) -> int:
	if n == null:
		return default_value

	# Properties
	if "neighbor_id" in n:
		return int(n.get("neighbor_id"))
	if "neighbor_index" in n:
		return int(n.get("neighbor_index"))
	if "tier" in n:
		return int(n.get("tier"))
	if "depth" in n:
		return int(n.get("depth"))

	# Metadata
	if n.has_meta("neighbor_id"):
		return int(n.get_meta("neighbor_id"))
	if n.has_meta("neighbor_index"):
		return int(n.get_meta("neighbor_index"))
	if n.has_meta("tier"):
		return int(n.get_meta("tier"))
	if n.has_meta("depth"):
		return int(n.get_meta("depth"))

	return default_value


func _get_device_start_neighbor_id_int(d: Object, default_value: int = 0) -> int:
	if d == null:
		return default_value

	if "start_neighbor_id" in d:
		return int(d.get("start_neighbor_id"))
	if "home_neighbor_id" in d:
		return int(d.get("home_neighbor_id"))
	if "start_tier" in d:
		return int(d.get("start_tier"))

	if d.has_meta("start_neighbor_id"):
		return int(d.get_meta("start_neighbor_id"))
	if d.has_meta("home_neighbor_id"):
		return int(d.get_meta("home_neighbor_id"))
	if d.has_meta("start_tier"):
		return int(d.get_meta("start_tier"))

	return default_value


# -------------------------------------------------
# Password discovery for Network objects
# -------------------------------------------------
func _get_network_password(n: Object) -> String:
	if n == null:
		return ""

	if "network_password" in n:
		return str(n.get("network_password"))
	if "password" in n:
		return str(n.get("password"))
	if "passphrase" in n:
		return str(n.get("passphrase"))

	if n.has_meta("network_password"):
		return str(n.get_meta("network_password"))
	if n.has_meta("password"):
		return str(n.get_meta("password"))

	return ""


func _has_password(pw: String) -> bool:
	return pw != null and pw.strip_edges() != ""
