extends CommandBase
class_name CmdConnect

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
	# If the network has a password, launch the minigame.
	# If no password, connect immediately.
	# -------------------------------------------------
	var pw := _get_network_password(target)
	var needs_auth := _has_password(pw)

	if needs_auth:
		# Cosmetic progress bar (optional but nice)
		var bar_index: int = screen.append_line("[----------]")
		var total := 10
		for i in range(total):
			await tree.create_timer(0.25).timeout
			var filled := "|".repeat(i + 1)
			var empty := "-".repeat(total - i - 1)
			screen.replace_line(bar_index, "[%s%s]" % [filled, empty])

		# Launch minigame (it will read password from the target object)
		var mg := PswdCrackingMinigame.new()

		# If your Network has hack_chance, tier can reflect it (optional)
		var hack_chance: float = 0.99
		if "hack_chance" in target:
			hack_chance = float(target.hack_chance)
		hack_chance = clamp(hack_chance, 0.0, 1.0)

		# IMPORTANT: pass the Network as p_target so minigame pulls its password
		mg.setup_and_generate(terminal, target, hack_chance, d, 10)

		var outcome := await _await_minigame_result(mg, tree)

		# Treat close as failure so players can't bypass auth by canceling
		if outcome != "success":
			return [
				"connect: access denied (authentication failed)",
				""
			]

	# -------------------------------------------------
	# SUCCESS PATH (either no password OR minigame success)
	# -------------------------------------------------
	# Disconnect from current network (if any)
	if d.network != null:
		d.detach_from_network()

	# Attach to new network (this assigns IP)
	d.attach_to_network(target)

	var lines: Array[String] = []
	lines.append("Network: %s" % target.subnet)
	lines.append("Assigned IP address: %s" % d.ip_address)
	lines.append("")
	lines.append("Hint: run 'arp' to discover devices on this network.")

	return lines


# -------------------------------------------------
# Minigame wait helper: returns "success" | "failed" | "closed"
# -------------------------------------------------
func _await_minigame_result(mg: Object, tree: SceneTree) -> String:
	var done := false
	var result := "closed"

	# Godot 4: lambdas can close over locals fine
	mg.connect("crack_success", func():
		done = true
		result = "success"
	)
	mg.connect("crack_failed", func():
		done = true
		result = "failed"
	)
	mg.connect("crack_closed", func():
		done = true
		result = "closed"
	)

	while not done:
		await tree.process_frame

	return result


# -------------------------------------------------
# Password discovery for Network objects
# (kept flexible because your Network class may vary)
# -------------------------------------------------
func _get_network_password(n: Object) -> String:
	if n == null:
		return ""

	# Common property names
	if "network_password" in n:
		return str(n.get("network_password"))
	if "password" in n:
		return str(n.get("password"))
	if "passphrase" in n:
		return str(n.get("passphrase"))

	# Metadata fallback
	if n.has_meta("network_password"):
		return str(n.get_meta("network_password"))
	if n.has_meta("password"):
		return str(n.get_meta("password"))

	return ""


func _has_password(pw: String) -> bool:
	return pw != null and pw.strip_edges() != ""
