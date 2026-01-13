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
		"scp 10.0.0.22:/home/readme.txt /home/loot/readme.txt",
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

	# ✅ FIX: your helper expects at least 1 arg
	var player_dev := _get_player_device(terminal)
	if player_dev == null:
		return ["scp: could not locate player device (WorldNetwork.player_device missing)."]

	var remote_ip := ""
	var remote_path := ""
	var local_path := ""
	var upload := false

	if src_is_remote:
		# download: remote -> local
		var parsed := _parse_remote(src_raw)
		remote_ip = String(parsed["ip"])
		remote_path = String(parsed["path"])
		local_path = dst_raw
		upload = false
	else:
		# upload: local -> remote
		var parsed2 := _parse_remote(dst_raw)
		remote_ip = String(parsed2["ip"])
		remote_path = String(parsed2["path"])
		local_path = src_raw
		upload = true

	remote_path = _force_abs(remote_path)
	local_path = _force_abs(local_path)

	# ------------------------------------------------------------
	# If we're already remoted into this host, use that device
	# ------------------------------------------------------------
	var remote_dev: Object = null

	var cur := terminal.current_device
	if cur != null:
		var cur_ip := ""
		if ("ip_address" in cur): cur_ip = String(cur.ip_address)
		elif ("ip" in cur): cur_ip = String(cur.ip)
		elif ("ipv4_address" in cur): cur_ip = String(cur.ipv4_address)
		elif ("ipv4" in cur): cur_ip = String(cur.ipv4)
		elif ("address" in cur): cur_ip = String(cur.address)

		if cur_ip == remote_ip:
			remote_dev = cur

	# Otherwise, discover via WorldNetwork
	if remote_dev == null:
		remote_dev = _find_device_by_ip(remote_ip)

	if remote_dev == null:
		return ["scp: unknown host %s (not found on current network)" % remote_ip]

	if ("online" in remote_dev) and not bool(remote_dev.online):
		return ["scp: host %s is offline" % remote_ip]

	if remote_dev.fs == null:
		return ["scp: remote filesystem missing"]

	if player_dev.fs == null:
		return ["scp: local filesystem missing"]

	await _emit_line(terminal, ">> scp: establishing channel to %s..." % remote_ip)
	await _emit_line(terminal, ">> key exchange: ok", 0.08)
	await _emit_line(terminal, ">> cipher: chacha20-poly1305@openssh.com", 0.06)
	await _emit_line(terminal, ">> compression: zlib@openssh.com", 0.06)

	if upload:
		# upload
		var ok_up := await _copy_files_only(
			terminal,
			player_dev, local_path,
			remote_dev, remote_path,
			"upload"
		)
		return ["scp: upload complete" if ok_up else "scp: upload failed"]


	else:
		# download
		var ok_down := await _copy_files_only(
			terminal,
			remote_dev, remote_path,
			player_dev, local_path,
			"download"
		)
		return ["scp: download complete" if ok_down else "scp: download failed"]

# ------------------------------------------------------------
# COPY CORE (FILES ONLY)
# ------------------------------------------------------------
func _copy_files_only(
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

	var src_fs: FileSystem = src_dev.fs
	var dst_fs: FileSystem = dst_dev.fs

	# Reject data files explicitly
	var src_is_data := src_fs.has_method("is_data_file") and bool(src_fs.call("is_data_file", src_path))
	if src_is_data:
		await _emit_line(terminal, ">> scp: error: incorrect file type (data file)")
		await _emit_line(terminal, ">> hint: use 'xferdata' to transfer .dat / data files")
		return false

	var src_is_file := src_fs.has_method("is_file") and bool(src_fs.call("is_file", src_path))
	if not src_is_file:
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

	# Plaintext file copy
	if not (src_fs.has_method("read_file") and dst_fs.has_method("write_file")):
		await _emit_line(terminal, ">> scp: plaintext copy not supported")
		return false

	var content := String(src_fs.call("read_file", src_path))
	var ok := bool(dst_fs.call("write_file", dst_path, content))
	await _emit_line(terminal, ">> integrity: ok (sha256: simulated)" if ok else ">> integrity: failed")
	return ok


# ------------------------------------------------------------
# OUTPUT
# ------------------------------------------------------------
func _emit_line(terminal: Terminal, line: String, fallback_delay: float = 0.10) -> void:
	var screen: Node = null
	if terminal != null and ("screen" in terminal):
		screen = terminal.screen

	if screen != null:
		if screen.has_method("type_line"):
			await screen.call("type_line", line)
			return
		if screen.has_method("print_delayed"):
			await screen.call("print_delayed", line)
			return
		if screen.has_method("append_line_delayed"):
			await screen.call("append_line_delayed", line)
			return
		if screen.has_method("write_line_delayed"):
			await screen.call("write_line_delayed", line)
			return
		if screen.has_method("append_line"):
			screen.call("append_line", line)
			await _net_delay(fallback_delay)
			return

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

# FIXED: use device_stack bottom first (local device), then fallback to World / WorldNetwork
func _get_player_device(terminal: Terminal) -> Object:
	# 1) Best: terminal.device_stack[0]
	if terminal != null and ("device_stack" in terminal):
		var st = terminal.get("device_stack")
		if st is Array and st.size() >= 1 and st[0] != null:
			return st[0]

	# 2) Next: World.get_player_device (if you have it)
	var w := _get_autoload("World")
	if w != null:
		if w.has_method("get_player_device"):
			var pd = w.call("get_player_device")
			if pd != null:
				return pd
		# some projects store it as a property
		if ("player_device" in w) and w.player_device != null:
			return w.player_device

	# 3) Fallback: WorldNetwork.player_device
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
		nets = wn.call("get_networks")
	elif ("networks" in wn):
		nets = wn.networks

	for n in nets:
		if n == null:
			continue

		var devs: Array = []
		if n.has_method("get_devices"):
			devs = n.call("get_devices")
		elif ("devices" in n):
			devs = n.devices

		for d in devs:
			if d == null:
				continue

			var dip := ""
			if ("ip_address" in d):
				dip = String(d.ip_address)
			elif ("ip" in d):
				dip = String(d.ip)

			if dip == ip:
				return d

	return null
