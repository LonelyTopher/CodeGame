extends Node

const MAX_PLAYER_LEVEL: int = 50
const XP_PER_PLAYER_LEVEL: int = 100

signal player_xp_changed(new_xp: int, new_level: int)
signal player_leveled_up(new_level: int)

var level: int = 1
var xp: int = 0

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
