extends Node

const STATS_DIR := "res://Systems/Stats/Definitions"

# id -> StatBase instance
var stats: Dictionary = {}

@onready var player := get_node("/root/PlayerBase")

signal stat_registered(stat_id: String)
signal stat_xp_awarded(stat_id: String, gained: int)
signal stat_leveled_up(stat_id: String, new_level: int)

func _ready() -> void:
	load_all_stats()

func load_all_stats() -> void:
	stats.clear()

	var dir := DirAccess.open(STATS_DIR)
	if dir == null:
		push_error("StatsSystem: couldn't open %s" % STATS_DIR)
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".gd"):
			var path := "%s/%s" % [STATS_DIR, file]
			_register_stat_script(path)
		file = dir.get_next()
	dir.list_dir_end()

func _register_stat_script(path: String) -> void:
	var script := load(path)
	if script == null:
		push_error("StatsSystem: failed to load %s" % path)
		return

	var obj = script.new()
	if obj == null or not (obj is StatBase):
		push_error("StatsSystem: %s does not extend StatBase" % path)
		return

	var stat: StatBase = obj
	if stat.id == "" or stat.id == "unknown":
		push_error("StatsSystem: %s has invalid stat.id" % path)
		return

	stats[stat.id] = stat

	# Hook leveling to player XP (+3 each stat level)
	stat.leveled_up.connect(_on_stat_leveled_up)

	emit_signal("stat_registered", stat.id)

func has_stat(stat_id: String) -> bool:
	return stats.has(stat_id)

func get_stat(stat_id: String) -> StatBase:
	return stats.get(stat_id, null)

func award_xp(stat_id: String, base_amount: int) -> int:
	var stat := get_stat(stat_id)
	if stat == null:
		return 0

	var result := stat.add_xp(base_amount)
	var gained: int = result.get("gained", 0)
	if gained > 0:
		emit_signal("stat_xp_awarded", stat_id, gained)

	print("award_xp: stat_id=", stat_id, " base=", base_amount)
	print("award_xp: stat obj=", stat, " before xp=", stat.xp, " lv=", stat.level)


	return gained

func _on_stat_leveled_up(stat_id: String, new_level: int) -> void:
	emit_signal("stat_leveled_up", stat_id, new_level)
	# +3 player XP per stat level-up
	player.add_player_xp(3)
