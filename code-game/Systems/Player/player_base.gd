extends Node

const MAX_PLAYER_LEVEL: int = 50
const XP_PER_PLAYER_LEVEL: int = 100

signal player_xp_changed(new_xp: int, new_level: int)
signal player_leveled_up(new_level: int)

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

	currencies[type] += amount

func spend_currency(type: int, amount: float) -> bool:
	if not currencies.has(type):
		return false

	if currencies[type] < amount:
		return false

	currencies[type] -= amount
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
			"Bitcoin":
				currencies[Currency.BITCOIN] = amount
			"Ethereum":
				currencies[Currency.ETHEREUM] = amount
			_:
				# Unknown currency in save (future-proofing)
				pass
