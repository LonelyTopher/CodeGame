extends Node

const MAX_PLAYER_LEVEL: int = 50
const XP_PER_PLAYER_LEVEL: int = 100

signal player_xp_changed(new_xp: int, new_level: int)
signal player_leveled_up(new_level: int)
signal currency_changed(type: int, new_amount: float)

# --- Currency Enum --- #
enum Currency {
	DOLLARS,
	BITCOIN,
	ETHEREUM
}

# --- Player owns variable items below --- #
var level: int = 1
var xp: int = 0
var currencies: Dictionary = {
	Currency.DOLLARS: 0.0,
	Currency.BITCOIN: 0.0,
	Currency.ETHEREUM: 0.0
}

func xp_to_next_level(_lv: int) -> int:
	return XP_PER_PLAYER_LEVEL

func add_player_xp(amount: int) -> void:
	if amount <= 0:
		return
	if level >= MAX_PLAYER_LEVEL:
		return

	xp += amount
	emit_signal("player_xp_changed", xp, level)

	while xp >= xp_to_next_level(level) and level < MAX_PLAYER_LEVEL:
		xp -= xp_to_next_level(level)
		level += 1
		emit_signal("player_leveled_up", level)
		emit_signal("player_xp_changed", xp, level)

# Optional helper: enum -> display name (for UI / logs)
func currency_name(type: int) -> String:
	match type:
		Currency.DOLLARS:
			return "Dollars"
		Currency.BITCOIN:
			return "Bitcoin"
		Currency.ETHEREUM:
			return "Ethereum"
		_:
			return "Unknown"

func add_currency(type: int, amount: float) -> void:
	if not currencies.has(type):
		push_error("Currency does not exist: " + currency_name(type))
		return
	if amount == 0.0:
		return

	currencies[type] += amount
	emit_signal("currency_changed", type, float(currencies[type]))

func spend_currency(type: int, amount: float) -> bool:
	if not currencies.has(type):
		return false
	if amount <= 0.0:
		return false
	if currencies[type] < amount:
		return false

	currencies[type] -= amount
	emit_signal("currency_changed", type, float(currencies[type]))
	return true

func get_currency(type: int) -> float:
	return currencies.get(type, 0.0)

func build_currency_state() -> Dictionary:
	var out := {}
	for key in currencies.keys():
		out[currency_name(key)] = currencies[key]
	return out

func apply_currency_state(state: Dictionary) -> void:
	for n in state.keys():
		var amount := float(state[n])
		match String(n):
			"Dollars":
				currencies[Currency.DOLLARS] = amount
				emit_signal("currency_changed", Currency.DOLLARS, amount)
			"Bitcoin":
				currencies[Currency.BITCOIN] = amount
				emit_signal("currency_changed", Currency.BITCOIN, amount)
			"Ethereum":
				currencies[Currency.ETHEREUM] = amount
				emit_signal("currency_changed", Currency.ETHEREUM, amount)
			_:
				pass

func currency_from_name(name: String) -> int:
	match name.strip_edges().to_lower():
		"dollars", "usd", "DOLLARS", "USD":
			return Currency.DOLLARS
		"bitcoin", "btc", "BITCOIN", "BTC":
			return Currency.BITCOIN
		"ethereum", "eth", "ETHEREUM", "ETH":
			return Currency.ETHEREUM
		_:
			return -1

# OPTIONAL: full save chunk for PlayerBase (SaveSystem can use this later if you want)
func to_data() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"currencies": build_currency_state()
	}

func from_data(state: Dictionary) -> void:
	if state.is_empty():
		return
	level = clamp(int(state.get("level", level)), 1, MAX_PLAYER_LEVEL)
	xp = max(int(state.get("xp", xp)), 0)
	var cur_state: Variant = state.get("currencies", {})
	if typeof(cur_state) == TYPE_DICTIONARY:
		apply_currency_state(cur_state as Dictionary)
	emit_signal("player_xp_changed", xp, level)
