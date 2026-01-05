extends CommandBase
class_name CmdList

func get_name() -> String:
	return "list"

func get_help() -> String:
	return "List things (e.g. saves, skills)."

func get_usage() -> String:
	return "list saves | list skills"

func get_examples() -> Array[String]:
	return ["list saves", "list skills"]

func get_category() -> String:
	return "HELP"

func run(args: Array[String], _terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["list: usage: list saves | list skills"]

	match args[0]:
		"saves":
			return _list_saves()
		"skills":
			return _list_skills()
		_:
			return ["list: unknown category '%s' (try: saves, skills)" % args[0]]

func _list_saves() -> Array[String]:
	var ss := SaveSystem.new()
	var slots := ss.list_slots()
	if slots.is_empty():
		return ["(no saves found)"]
	return ["Saves: " + ", ".join(slots)]

func _list_skills() -> Array[String]:
	var lines: Array[String] = []

	# Access the autoload instance
	var stats_system = Engine.get_main_loop().get_root().get_node("StatsSystem")
	# Expecting: stats_system.stats is a Dictionary: id -> StatBase
	var stats_dict: Dictionary = stats_system.stats

	if stats_dict.is_empty():
		return ["(no skills registered)"]

	lines.append("Skills:")

	# Sort by id for stable output
	var ids: Array = stats_dict.keys()
	ids.sort()

	for stat_id in ids:
		var stat = stats_dict[stat_id]
		if stat == null:
			continue

		# StatBase fields we set up earlier
		var name: String = stat.display_name if stat.display_name != "" else String(stat_id)
		var lv: int = stat.level
		var xp: int = stat.xp

		# Your system: 100 XP per level
		var xp_needed := 100
		# If you later change curves, you can call stat.xp_to_next_level(lv) if it's exposed
		# var xp_needed := stat.xp_to_next_level(lv)

		var bar := _progress_bar(xp, xp_needed, 14) # 14 segments looks nice in terminal
		lines.append("%s  Lv %d  %s  %d/%d XP" % [name, lv, bar, xp, xp_needed])

	return lines

func _progress_bar(current: int, max_value: int, width: int = 10) -> String:
	if max_value <= 0:
		max_value = 1

	var pct := float(current) / float(max_value)
	pct = clamp(pct, 0.0, 1.0)

	var filled := int(round(pct * float(width)))
	filled = clamp(filled, 0, width)

	var left := "|".repeat(filled)
	var right := "-".repeat(width - filled)

	return "[" + left + right + "]"
