extends CommandBase
class_name CmdXferData

const BASE_HEAT := 6
const SUSPICION_PER_EXTRACT := 10

func get_name() -> String:
	return "xferdata"

func get_aliases() -> Array[String]:
	return ["exfil", "extract"]

func get_help() -> String:
	return "Steal funds from a remote DATA account file and save a local exfil copy. Leaves a trace."

func get_usage() -> String:
	return "xferdata <targetIP>:<path> <currency> <amount> <local_dest_dir>"

func get_examples() -> Array[String]:
	return [
		"xferdata 201.6.99.2:/server/accounts/Daniel_Kurosawa.data USD 15000 /home",
		"xferdata 201.6.99.2:/server/accounts/Daniel_Kurosawa.data dollars 250 /home",
		"xferdata 201.6.99.2:/server/accounts/Daniel_Kurosawa.data btc 0.05 /home"
	]

func get_category() -> String:
	return "NETWORK"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	# command name is NOT included in args
	if args.size() != 4:
		return ["usage: " + get_usage()]

	if terminal == null or terminal.current_device == null or terminal.device_stack.size() <= 1:
		return ["xferdata: not connected to a remote device (use connect/ssh first)"]

	var target = String(args[0]).strip_edges()
	var currency_raw = String(args[1]).strip_edges()
	var amount = float(args[2])
	var local_dest = String(args[3]).strip_edges()

	if amount <= 0.0:
		return ["xferdata: amount must be greater than zero"]

	var parsed: Dictionary = _parse_target(target)
	if not bool(parsed.get("ok", false)):
		return ["xferdata: invalid target. Expected <ip>:<path>"]

	var target_ip: String = String(parsed.get("ip", ""))
	var remote_path: String = String(parsed.get("path", ""))

	var remote = terminal.current_device
	var local = terminal.device_stack[0]

	if remote.fs == null or local.fs == null:
		return ["xferdata: filesystem not available."]

	var remote_ip: String = _get_device_ip(remote)
	if remote_ip != target_ip:
		return [
			"xferdata: denied (not connected to %s)" % target_ip,
			"hint: connect/ssh to that device first"
		]

	# Ensure local dest dir exists
	if not local.fs.is_dir(local_dest):
		var ok_mk: bool = bool(local.fs.mkdir(local_dest))
		if not ok_mk:
			return ["xferdata: local destination dir missing: " + local_dest]

	# Must be data node
	if not remote.fs.is_data_file(remote_path):
		return ["xferdata: blocked. Target is not a data file: " + remote_path]

	var data: Dictionary = remote.fs.read_data_file(remote_path)
	if data.is_empty():
		return ["xferdata: failed to read remote data file: " + remote_path]

	# Currency alias handling (same as cashout)
	var player = PlayerBase
	var currency_enum = player.currency_from_name(currency_raw)
	if currency_enum == -1:
		currency_enum = player.currency_from_name(currency_raw.to_upper())
	if currency_enum == -1:
		return ["xferdata: unsupported currency: " + currency_raw]

	var normalized_key: String = _normalize_currency_key(currency_raw)

	# Expect balances format on remote
	if not (data.has("balances") and typeof(data["balances"]) == TYPE_DICTIONARY):
		return ["xferdata: unsupported data file format (expected balances dict)"]

	var balances: Dictionary = data["balances"]

	if not balances.has(normalized_key):
		return ["xferdata: currency not found in file: " + normalized_key]

	var current_balance: float = float(balances[normalized_key])
	if current_balance <= 0.0:
		return ["xferdata: empty (0 %s)" % normalized_key]

	# Clamp take amount
	var taken: float = min(amount, current_balance)
	var new_balance: float = max(current_balance - taken, 0.0)

	# Update remote balance
	balances[normalized_key] = new_balance
	data["balances"] = balances

	# Leave trace on remote
	var dest_ip: String = _get_device_ip(local)
	_leave_transfer_trace(remote.fs, remote_path, dest_ip)

	# Write remote updated balances back
	var wrote_remote: bool = false
	if remote.fs.has_method("force_set_data_file"):
		wrote_remote = bool(remote.fs.force_set_data_file(remote_path, data))
	else:
		wrote_remote = bool(remote.fs.set_data_file(remote_path, data))

	if not wrote_remote:
		return ["xferdata: failed to update remote data file (protected?)"]

	# -------------------------------------------------
	# LOCAL LOOT FILE (MATCHES YOUR ACCOUNT TEMPLATE)
	# balances:{<currency>:taken}, owner, plus your "notes at bottom" metadata
	# -------------------------------------------------
	var loot_balances: Dictionary = {}
	loot_balances[normalized_key] = taken

	# If you have a player name somewhere, swap this in later
	var local_owner := "user"
	# Example future hook:
	# if Engine.has_singleton("World"):
	#   var w = Engine.get_singleton("World")
	#   if w != null and w.has_method("get_player_name"):
	#       local_owner = String(w.get_player_name())

	var loot: Dictionary = {
		"balances": loot_balances,
		"owner": local_owner,

		# ---- "text at the bottom" / metadata you wanted to keep ----
		"note": "EXFILTRATED FUNDS",
		"source_ip": remote_ip,
		"source_owner": String(data.get("owner", "")),
		"source_path": remote_path,
		"stolen_at": Time.get_datetime_string_from_system()
	}

	# Unique loot filename: timestamp + random suffix (prevents same-second collisions)
	var base: String = remote_path.get_file()              # Daniel_Kurosawa.data
	var base_no_ext: String = base.trim_suffix(".data")    # Daniel_Kurosawa

	var ts := str(int(Time.get_unix_time_from_system()))
	var rand4 := str(randi_range(1000, 9999))              # random-ish

	var loot_name: String = "%s_%s_%s_%s.data" % [
		base_no_ext,
		normalized_key.to_lower(),
		ts,
		rand4
	]

	var dest_path: String = local_dest.rstrip("/") + "/" + loot_name

	var ok_write: bool = bool(local.fs.write_data_file(dest_path, loot, false, {
		"exfil": true,
		"from_ip": remote_ip
	}))

	if not ok_write:
		return ["xferdata: remote updated, but failed to write local exfil file: " + dest_path]

	_apply_suspicion(remote)
	_apply_heat(taken)

	return [
		">> negotiating handshake...",
		">> elevating session...",
		">> exfil stream: OK",
		"Stolen: %s %s" % [str(taken), normalized_key],
		"Remote remaining: %s %s" % [str(new_balance), normalized_key],
		"Saved loot: %s" % dest_path,
		"Trace written: transfers += [%s]" % dest_ip
	]


# ---------------- Helpers ----------------
func _parse_target(s: String) -> Dictionary:
	var idx = s.find(":")
	if idx <= 0:
		return {"ok": false}
	var ip = s.substr(0, idx).strip_edges()
	var path = s.substr(idx + 1, s.length()).strip_edges()
	if not path.begins_with("/"):
		return {"ok": false}
	return {"ok": true, "ip": ip, "path": path}

func _get_device_ip(device) -> String:
	if device == null:
		return "0.0.0.0"
	if "ip" in device:
		return String(device.ip)
	if "ip_addr" in device:
		return String(device.ip_addr)
	if device.has_method("get_ip"):
		return String(device.get_ip())
	return "0.0.0.0"

func _leave_transfer_trace(fs: FileSystem, path: String, dest_ip: String) -> void:
	if fs.has_method("append_data_transfer_trace"):
		fs.append_data_transfer_trace(path, dest_ip)
		return

	var d: Dictionary = fs.read_data_file(path)
	var transfers = d.get("transfers", [])
	if typeof(transfers) != TYPE_ARRAY:
		transfers = []
	if not transfers.has(dest_ip):
		transfers.append(dest_ip)
	d["transfers"] = transfers

	if fs.has_method("force_set_data_file"):
		fs.force_set_data_file(path, d)
	else:
		fs.set_data_file(path, d)

func _normalize_currency_key(s: String) -> String:
	var k = s.strip_edges().to_upper()
	match k:
		"USD", "$", "DOLLAR", "DOLLARS":
			return "DOLLARS"
		"BTC", "BITCOIN":
			return "BITCOIN"
		"ETH", "ETHEREUM":
			return "ETHEREUM"
		_:
			return k

func _apply_suspicion(remote) -> void:
	if remote == null:
		return
	if remote.has_method("add_suspicion"):
		remote.add_suspicion(SUSPICION_PER_EXTRACT)
	elif "suspicion" in remote:
		remote.suspicion += SUSPICION_PER_EXTRACT

func _apply_heat(taken_amount: float) -> void:
	if Engine.has_singleton("World"):
		var w = Engine.get_singleton("World")
		if w != null and w.has_method("add_heat"):
			var heat = BASE_HEAT + (taken_amount / 10000.0)
			w.add_heat(heat, "xferdata")
