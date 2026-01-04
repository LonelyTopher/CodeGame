extends CommandBase
class_name CmdSSH

func get_name() -> String:
	return "ssh"

func get_help() -> String:
	return "Connect to a remote device via SSH."

func get_usage() -> String:
	return "ssh <ip>"

func get_examples() -> Array[String]:
	return [
		"ssh 10.42.7.2"
	]

# NOTE:
# Because we use `await` in here, Godot will return a GDScriptFunctionState.
# Your TerminalScreen already supports that with:
#   var res = term.execute(...)
#   if res is GDScriptFunctionState: res = await res
func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["ssh: missing ip address"]

	var ip := args[0]

	var current: Device = terminal.current_device
	if current == null:
		return ["ssh: no active device"]

	if current.network == null:
		return ["ssh: not connected to a network"]

	# Find target device on the same network
	var target: Device = null
	for d in current.network.devices:
		if d.ip_address == ip:
			target = d
			break

	if target == null:
		return ["ssh: could not resolve host " + ip]

	if target == current:
		return ["ssh: already connected to this device"]

	# -------------------------------------------------
	# Get TerminalScreen THROUGH terminal (no get_tree here)
	# -------------------------------------------------
	var screen = terminal.screen
	if screen == null:
		return ["ssh: internal error (no terminal screen)"]

	# We'll build "final output" lines here.
	# The bar itself is animated via screen.replace_line().
	var lines: Array[String] = []
	lines.append("Connecting to %s..." % ip)

	# Print the "Connecting..." line immediately
	# (So the bar appears under it)
	var _connecting_index: int = screen.append_line("Connecting to %s..." % ip)

	# Create progress bar line ONCE and animate it in-place
	var bar_index: int = screen.append_line("[----------]")

	# Timer access without get_tree()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["ssh: internal error (no SceneTree)"]

	var total := 10
	for i in range(total):
		await tree.create_timer(0.3).timeout
		var filled := "|".repeat(i + 1)
		var empty := "-".repeat(total - i - 1)
		screen.replace_line(bar_index, "[%s%s]" % [filled, empty])

	# -------------------------------------------------
	# Hack chance roll (device-driven)
	# -------------------------------------------------
	var chance: float = 0.35
	if "hack_chance" in target:
		chance = float(target.hack_chance)
	chance = clamp(chance, 0.0, 1.0)

	var success := (randf() <= chance)

	# -------------------------------------------------
	# Get StatsSystem autoload (NO get_tree)
	# -------------------------------------------------
	var root := tree.get_root()
	var stats = root.get_node_or_null("StatsSystem")
	if stats == null:
		return ["ssh: internal error (StatsSystem missing)"]

	# -------------------------------------------------
	# XP tuning (first vs repeat), safe defaults
	# -------------------------------------------------
	var first_xp: int = 25
	var repeat_xp: int = 3
	var already_hacked: bool = false

	if "hack_xp_first" in target:
		first_xp = int(target.hack_xp_first)
	if "hack_xp_repeat" in target:
		repeat_xp = int(target.hack_xp_repeat)
	if "was_hacked" in target:
		already_hacked = bool(target.was_hacked)

	# -------------------------------------------------
	# Result handling
	# -------------------------------------------------
	if not success:
		stats.award_xp("hacking", 1)
		lines.append("ssh: access denied (authentication failed)")
		lines.append("+1 Hacking XP (attempt)")
		lines.append("")
		return lines

	# Success: award XP + mark hacked (only if property exists)
	if (not already_hacked) and ("was_hacked" in target):
		target.was_hacked = true
		stats.award_xp("hacking", first_xp)
		lines.append("Access granted. Device compromised.")
		lines.append("+%d Hacking XP (first hack)" % first_xp)
	else:
		stats.award_xp("hacking", repeat_xp)
		lines.append("Access granted.")
		lines.append("+%d Hacking XP (repeat hack)" % repeat_xp)

	# Switch terminal context (your existing logic)
	terminal.current_device = target
	terminal.device_stack.append(target)
	terminal.fs = target.fs
	terminal.cwd = "/home"

	lines.append("Connected to %s (%s)" % [target.hostname, target.ip_address])
	lines.append("")
	return lines
