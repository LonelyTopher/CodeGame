extends CommandBase
class_name CmdScp

func get_name() -> String:
	return "scp"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Secure copy files between your device and a remote device by IP."

func get_usage() -> String:
	return "scp <src> <dest>\n  src/dest format: <ip>:/abs/path OR /abs/path"

func get_category() -> String:
	return "NETWORK"

func get_examples() -> Array[String]:
	return [
		"scp 10.0.0.22:/home/accounts/balances.dat /home/loot/balances.dat",
		"scp /home/tools/payload.txt 10.0.0.22:/home/inbox/payload.txt"
	]

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if terminal == null:
		return ["scp: terminal is null"]

	if args.size() < 2:
		return ["usage: " + get_usage()]

	var src_raw := String(args[0]).strip_edges()
	var dst_raw := String(args[1]).strip_edges()

	var src_is_remote := _looks_like_remote(src_raw)
	var dst_is_remote := _looks_like_remote(dst_raw)

	if src_is_remote and dst_is_remote:
		return ["scp: remote->remote not supported (yet). Copy to local first."]
	if (not src_is_remote) and (not dst_is_remote):
		return ["scp: local->local copy not supported (use cp/mv)."]

	var player_dev := _get_player_device()
	if player_dev == null:
		return ["scp: could not locate player device (WorldNetwork.player_device missing)."]

	var remote_ip := ""
	var remote_path := ""
	var local_path := ""
	var upload := false

	if src_is_remote:
		# download: remote -> local
		var parsed := _parse_remote(src_raw)
		remote_ip = parsed["ip"]
		remote_path = parsed["path"]
		local_path = dst_raw
		upload = false
	else:
		# upload: local -> remote
		var parsed2 := _parse_remote(dst_raw)
		remote_ip = parsed2["ip"]
		remote_path = parsed2["path"]
		local_path = src_raw
		upload = true

	remote_path = _force_abs(remote_path)
	local_path = _force_abs(local_path)

	var remote_dev := _find_device_by_ip(remote_ip)
	if remote_dev == null:
		return ["scp: unknown host %s (not found on current network)" % remote_ip]

	if not bool(remote_dev.online):
		return ["scp: host %s is offline" % remote_ip]

	if remote_dev.fs == null:
		return ["scp: remote filesystem missing"]

	if player_dev.fs == null:
		return ["scp: local filesystem missing"]

	# Animated / realistic header (uses TerminalScreen delayed typing if available)
	await _emit_line(terminal, ">> scp: establishing channel to %s..." % remote_ip)
	await _emit_line(terminal, ">> key exchange: ok", 0.08)
	await _emit_line(terminal, ">> cipher: chacha20-poly1305@openssh.com", 0.06)
	await _emit_line(terminal, ">> compression: zlib@openssh.com", 0.06)

	# Do the copy (FIX: must await because coroutine)
	if upload:
		var ok_up := await _copy_between_devices(
			terminal,
			player_dev, local_path,
			remote_dev, remote_path,
			"upload"
		)
		return ["scp: upload complete" if ok_up else "scp: upload failed"]
	else:
		var ok_down := await _copy_between_devices(
			terminal,
			remote_dev, remote_path,
			player_dev, local_path,
			"download"
		)
		return ["scp: download complete" if ok_down else "scp: download failed"]


# ------------------------------------------------------------
# COPY CORE (supports file + data file)
# ------------------------------------------------------------
func _copy_between_devices(
	terminal: Terminal,
	src_dev: Object, src_path: String,
	dst_dev: Object, dst_path: String,
	mode_label: String
) -> bool:
	if src_dev == null or src_dev.fs == null:
		await _emit_line(terminal, ">> scp: source filesystem missing")
		return false
	if dst_dev == null or dst_dev.fs == null:
		await _emit_line(terminal, ">> scp: destination filesystem missing")
		return false

	var src_fs : FileSystem = src_dev.fs
	var dst_fs : FileSystem = dst_dev.fs

	var src_is_file := src_fs.has_method("is_file") and bool(src_fs.call("is_file", src_path))
	var src_is_data := src_fs.has_method("is_data_file") and bool(src_fs.call("is_data_file", src_path))

	if (not src_is_file) and (not src_is_data):
		await _emit_line(terminal, ">> scp: source not found: %s" % src_path)
		return false

	# Ensure destination parent directory exists
	var dst_parent := _parent_dir(dst_path)
	if dst_parent == "":
		dst_parent = "/"

	if not (dst_fs.has_method("is_dir") and bool(dst_fs.call("is_dir", dst_parent))):
		await _emit_line(terminal, ">> scp: destination directory missing: %s" % dst_parent)
		return false

	await _emit_line(terminal, ">> scp: %s %s -> %s" % [mode_label, src_path, dst_path])
	await _emit_line(terminal, ">> transferring blocks: 0%", 0.06)
	await _emit_line(terminal, ">> transferring blocks: 33%", 0.06)
	await _emit_line(terminal, ">> transferring blocks: 66%", 0.06)
	await _emit_line(terminal, ">> transferring blocks: 100%", 0.06)

	# Data file copy
	if src_is_data:
		if not (src_fs.has_method("read_data_file") and dst_fs.has_method("write_data_file")):
			await _emit_line(terminal, ">> scp: data-file copy not supported (missing methods)")
			return false

		var data: Dictionary = src_fs.call("read_data_file", src_path)
		# Allow empty data, but still proceed

		# preserve meta/protection if your FS stores it (optional)
		var protected := false
		var meta: Dictionary = {}
		if src_fs.has_method("_get_node"):
			var node: Variant = src_fs.call("_get_node", src_path)
			if typeof(node) == TYPE_DICTIONARY:
				protected = bool((node as Dictionary).get("protected", false))
				var m: Variant = (node as Dictionary).get("meta", {})
				if typeof(m) == TYPE_DICTIONARY:
					meta = m

		var ok := bool(dst_fs.call("write_data_file", dst_path, data, protected, meta))
		await _emit_line(terminal, ">> integrity: ok (data)" if ok else ">> integrity: failed (data)")
		return ok

	# Plaintext file copy
	if not (src_fs.has_method("read_file") and dst_fs.has_method("write_file")):
		await _emit_line(terminal, ">> scp: plaintext copy not supported")
		return false

	var content := String(src_fs.call("read_file", src_path))
	var ok2 := bool(dst_fs.call("write_file", dst_path, content))
	await _emit_line(terminal, ">> integrity: ok (sha256: simulated)" if ok2 else ">> integrity: failed")
	return ok2


# ------------------------------------------------------------
# OUTPUT: Use TerminalScreen async/delayed methods if present
# ------------------------------------------------------------
func _emit_line(terminal: Terminal, line: String, fallback_delay: float = 0.10) -> void:
	var screen : Node = null
	if terminal != null and ("screen" in terminal):
		screen = terminal.screen

	# If your TerminalScreen has a typing / delayed print function, use it
	if screen != null:
		# Try a few common method names (add yours here if different)
		if screen.has_method("type_line"):
			# expected signature: type_line(text) -> awaitable
			await screen.call("type_line", line)
			return

		if screen.has_method("print_delayed"):
			# expected signature: print_delayed(text) -> awaitable
			await screen.call("print_delayed", line)
			return

		if screen.has_method("append_line_delayed"):
			# expected signature: append_line_delayed(text) -> awaitable
			await screen.call("append_line_delayed", line)
			return

		if screen.has_method("write_line_delayed"):
			await screen.call("write_line_delayed", line)
			return

		# Fallback: immediate append
		if screen.has_method("append_line"):
			screen.call("append_line", line)
			await _net_delay(fallback_delay)
			return

	# Last resort: no screen methods
	await _net_delay(fallback_delay)

func _net_delay(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(seconds).timeout


# ------------------------------------------------------------
# PARSING + LOOKUPS
# ------------------------------------------------------------
func _looks_like_remote(s: String) -> bool:
	if s.find(":/") == -1:
		return false
	var parts := s.split(":/", false, 1)
	if parts.size() != 2:
		return false
	return _looks_like_ip(parts[0])

func _parse_remote(s: String) -> Dictionary:
	var parts := s.split(":/", false, 1)
	return {
		"ip": String(parts[0]),
		"path": "/" + String(parts[1])
	}

func _looks_like_ip(s: String) -> bool:
	var t := s.strip_edges()
	var chunks := t.split(".", false)
	if chunks.size() != 4:
		return false
	for c in chunks:
		if c == "" or not c.is_valid_int():
			return false
		var n := int(c)
		if n < 0 or n > 255:
			return false
	return true

func _force_abs(path: String) -> String:
	var p := path.strip_edges()
	if p == "":
		return "/"
	if p.begins_with("/"):
		return p
	return "/home/%s" % p

func _parent_dir(path: String) -> String:
	var p := path.strip_edges()
	if p == "" or p == "/":
		return "/"

	var parts: Array[String] = []
	parts.assign(p.trim_prefix("/").split("/", false))

	if parts.size() <= 1:
		return "/"

	parts.pop_back()
	return "/" + "/".join(parts)

func _get_autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.get_root()
	return root.get_node_or_null("/root/%s" % name)

func _get_player_device() -> Object:
	var wn := _get_autoload("WorldNetwork")
	if wn != null and ("player_device" in wn) and wn.player_device != null:
		return wn.player_device
	return null

func _find_device_by_ip(ip: String) -> Object:
	var wn := _get_autoload("WorldNetwork")
	if wn == null:
		return null

	var nets: Array = []
	if wn.has_method("get_networks"):
		nets = wn.get_networks()
	elif wn.has("networks"):
		nets = wn.networks

	for n in nets:
		if n == null:
			continue
		if not n.has("devices"):
			continue
		for d in n.devices:
			if d != null and String(d.ip_address) == ip:
				return d

	return null
