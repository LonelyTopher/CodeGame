extends RefCounted
class_name StatBase

const MAX_STAT_LEVEL: int = 50
const XP_PER_STAT_LEVEL: int = 100

signal xp_changed(stat_id: String, new_xp: int, new_level: int)
signal leveled_up(stat_id: String, new_level: int)

var id: String = "unknown"
var display_name: String = "Unknown"

var level: int = 1
var xp: int = 0

# Diminishing returns:
# "take away 1% xp per level"
# Level 1 => 1.00
# Level 2 => 0.99
# Level 50 => 0.51
func xp_gain_multiplier() -> float:
	var m := 1.0 - (0.01 * float(level - 1))
	return clamp(m, 0.1, 1.0) # clamp floor so it never becomes useless

func xp_to_next_level(_lv: int) -> int:
	return XP_PER_STAT_LEVEL

func add_xp(base_amount: int) -> Dictionary:
	# returns: { "gained": int, "leveled": bool, "new_level": int }
	if base_amount <= 0:
		return {"gained": 0, "leveled": false, "new_level": level}

	if level >= MAX_STAT_LEVEL:
		return {"gained": 0, "leveled": false, "new_level": level}

	var gained := int(round(float(base_amount) * xp_gain_multiplier()))
	gained = max(gained, 1) # always at least 1 if you earned XP

	xp += gained
	emit_signal("xp_changed", id, xp, level)

	var did_level := false
	while xp >= xp_to_next_level(level) and level < MAX_STAT_LEVEL:
		xp -= xp_to_next_level(level)
		level += 1
		did_level = true
		emit_signal("leveled_up", id, level)
		emit_signal("xp_changed", id, xp, level)

	return {"gained": gained, "leveled": did_level, "new_level": level}
