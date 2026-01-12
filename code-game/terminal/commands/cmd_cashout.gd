extends CommandBase
class_name CmdCashout

func get_name() -> String:
	return "cashout"

func get_help() -> String:
	return "Withdraw funds from a data account file into your wallet."

func get_usage() -> String:
	return "cashout <path> <currency> <amount>"

func get_examples() -> Array[String]:
	return [
		"cashout /srv/accounts/1001/balances.dat DOLLARS 250",
		"cashout /srv/accounts/1001/balances.dat BITCOIN 0.05",
		"cashout /home/money.dat USD 100"
	]

func get_category() -> String:
	return "FINANCE"


func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.size() != 3:
		return ["usage: " + get_usage()]

	var path := args[0]
	var requested_currency_raw := String(args[1]).strip_edges()
	var requested_currency := requested_currency_raw.to_upper()
	var amount := float(args[2])

	if amount <= 0.0:
		return ["cashout: amount must be greater than zero"]

	var device := terminal.current_device
	if device == null or device.fs == null:
		return ["cashout: no active filesystem"]

	var fs := device.fs

	if not fs.is_data_file(path):
		return ["cashout: not a data file: " + path]

	var data := fs.read_data_file(path)
	if data.is_empty():
		return ["cashout: failed to read data file"]

	# Resolve requested currency to a PlayerBase enum (accepts USD/BTC/ETH etc)
	var player := PlayerBase
	var currency_enum := player.currency_from_name(requested_currency_raw)
	if currency_enum == -1:
		# Try again using upper (covers "DOLLARS"/"BTC"/etc)
		currency_enum = player.currency_from_name(requested_currency)
	if currency_enum == -1:
		return ["cashout: unsupported currency: " + requested_currency_raw]

	# Normalize the currency key we store/compare in data files
	var normalized_currency_key := _normalize_currency_key(requested_currency)

	# -----------------------------
	# FORMAT A: MULTI-CURRENCY FILE
	# { balances: { "DOLLARS": 500.0, ... } }
	# -----------------------------
	if data.has("balances") and typeof(data["balances"]) == TYPE_DICTIONARY:
		var balances: Dictionary = data["balances"]

		if not balances.has(normalized_currency_key):
			return ["cashout: currency not found in file: " + normalized_currency_key]

		var current_balance := float(balances[normalized_currency_key])

		if current_balance <= 0.0:
			return [
				"cashout: empty",
				"available: 0 " + normalized_currency_key
			]

		if current_balance < amount:
			return [
				"cashout: insufficient funds",
				"available: %s %s" % [str(current_balance), normalized_currency_key]
			]

		# Apply withdrawal
		balances[normalized_currency_key] = current_balance - amount
		data["balances"] = balances

		# Write back to file (respects protection)
		if not fs.set_data_file(path, data):
			return ["cashout: failed to update data file (protected?)"]

		# Credit player wallet
		player.add_currency(currency_enum, amount)

		return [
			"cashout successful",
			"received: %s %s" % [str(amount), normalized_currency_key],
			"remaining: %s %s" % [str(balances[normalized_currency_key]), normalized_currency_key]
		]

	# -----------------------------
	# FORMAT B: SINGLE-CURRENCY FILE
	# { amount: 500.0, currency: "DOLLARS" }
	# Uses FileSystem.withdraw_money() which also updates the file.
	# -----------------------------
	if data.has("amount") and data.has("currency"):
		var file_currency := String(data.get("currency", "")).strip_edges().to_upper()
		var file_currency_norm := _normalize_currency_key(file_currency)

		# Currency mismatch: user asked for BTC but file is DOLLARS, etc
		if file_currency_norm != normalized_currency_key:
			return [
				"cashout: currency mismatch",
				"file currency: " + file_currency_norm,
				"requested: " + normalized_currency_key
			]

		# Withdraw via filesystem helper (updates amount in the data file)
		var res: Dictionary = fs.withdraw_money(path, amount)
		if not bool(res.get("ok", false)):
			var reason := String(res.get("reason", "failed"))
			match reason:
				"empty":
					return ["cashout: empty (0 " + normalized_currency_key + ")"]
				_:
					return ["cashout: failed (" + reason + ")"]

		var taken := float(res.get("taken", 0.0))
		var remaining := float(res.get("remaining", 0.0))

		# Credit player wallet with what we actually took
		if taken > 0.0:
			player.add_currency(currency_enum, taken)

		return [
			"cashout successful",
			"received: %s %s" % [str(taken), normalized_currency_key],
			"remaining: %s %s" % [str(remaining), normalized_currency_key]
		]

	# Unknown schema
	return ["cashout: unsupported data file format"]


# -------------------------------------------------
# Normalize currency names to the keys you store in files
# Accepts: USD, DOLLARS, $, etc -> DOLLARS
# Accepts: BTC, BITCOIN -> BITCOIN
# Accepts: ETH, ETHEREUM -> ETHEREUM
# -------------------------------------------------
func _normalize_currency_key(s: String) -> String:
	var k := s.strip_edges().to_upper()
	match k:
		"USD", "$", "DOLLAR", "DOLLARS":
			return "DOLLARS"
		"BTC", "BITCOIN":
			return "BITCOIN"
		"ETH", "ETHEREUM":
			return "ETHEREUM"
		_:
			# Fall back to whatever they typed (still lets you add new currencies later)
			return k
