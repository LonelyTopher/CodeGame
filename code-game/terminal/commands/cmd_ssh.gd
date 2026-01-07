extends CommandBase
class_name CmdSSH

const LOCKOUT_FAILS: int = 3
const LOCKOUT_MS: int = 120_000

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

func get_category() -> String:
	return "NETWORK"

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

	# Timer access without get_tree()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["ssh: internal error (no SceneTree)"]

	# -------------------------------------------------
	# 3-strike lockout enforcement (2 minutes offline)
	# -------------------------------------------------
	var now_ms: int = Time.get_ticks_msec()
	var offline_until_ms: int = _get_meta_int(target, "offline_until_ms", 0)

	# If cooldown expired, restore device online + clear lockout
	if offline_until_ms > 0 and now_ms >= offline_until_ms:
		target.set_meta("offline_until_ms", 0)
		# restore online only if property exists
		if "online" in target:
			target.online = true

	# Re-read after possible clear
	offline_until_ms = _get_meta_int(target, "offline_until_ms", 0)

	# If still locked offline, refuse connection immediately
	if offline_until_ms > now_ms:
		var remain_s: int = int(ceil(float(offline_until_ms - now_ms) / 1000.0))
		return [
			"Connecting to %s..." % ip,
			"ssh: connect to host %s port 22: No route to host" % ip,
			"(device temporarily offline: %ds remaining)" % remain_s,
			""
		]

	# If device has online flag and it's false, also refuse
	if "online" in target and bool(target.online) == false:
		return [
			"Connecting to %s..." % ip,
			"ssh: connect to host %s port 22: No route to host" % ip,
			""
		]

	# We'll build "final output" lines here.
	# The bar itself is animated via screen.replace_line().
	var lines: Array[String] = []
	lines.append("Connecting to %s..." % ip)

	# Print the "Connecting..." line immediately
	# (So the bar appears under it)
	var _connecting_index: int = screen.append_line("Connecting to %s..." % ip)

	# Create progress bar line ONCE and animate it in-place
	var bar_index: int = screen.append_line("[----------]")

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
	# Result handling + 3-strike lockout
	# -------------------------------------------------
	if not success:
		# increment fail counter
		var fails: int = _get_meta_int(target, "ssh_fail_count", 0) + 1
		target.set_meta("ssh_fail_count", fails)

		stats.award_xp("hacking", 1)

		# 3rd strike => kick offline for 2 minutes
		if fails >= LOCKOUT_FAILS:
			target.set_meta("ssh_fail_count", 0)
			target.set_meta("offline_until_ms", Time.get_ticks_msec() + LOCKOUT_MS)

			# If device supports online property, set it false
			if "online" in target:
				target.online = false

			lines.append("ssh: access denied (authentication failed)")
			lines.append("+1 Hacking XP (attempt)")
			lines.append("Too many failed attempts. Host is now offline for 2 minutes.")
			lines.append("")
			return lines

		lines.append("ssh: access denied (authentication failed)")
		lines.append("+1 Hacking XP (attempt)")
		lines.append("(%d/%d failed attempts)" % [fails, LOCKOUT_FAILS])
		lines.append("")
		return lines

	# Success: clear fail counter + any lockout flags
	target.set_meta("ssh_fail_count", 0)
	target.set_meta("offline_until_ms", 0)
	if "online" in target:
		target.online = true

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


# -------------------------------------------------
# Meta helpers (avoid Variant inference warnings)
# -------------------------------------------------
func _get_meta_int(obj: Object, key: String, fallback: int) -> int:
	if obj == null or not obj.has_meta(key):
		return fallback
	var v = obj.get_meta(key)
	if typeof(v) == TYPE_INT:
		return int(v)
	# allow string/float etc without blowing up
	return int(str(v))
