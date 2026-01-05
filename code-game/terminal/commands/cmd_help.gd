extends CommandBase
class_name CmdHelp

# How wide should the header be?
# Option A: fixed width that matches your UI pretty well.
const DEFAULT_TERM_WIDTH := 64

# Category print order (HELP always first)
const CATEGORY_ORDER := [
	"GENERAL",
	"CORE",
	"GAMEPLAY",
	"SAVES",
	"NETWORK",
	"FILESYSTEM",
	"HELP"
]
	
	

func get_name() -> String:
	return "help"

func get_aliases() -> Array[String]:
	return ["?"]

func get_help() -> String:
	return "List available commands (or 'help <command>')"

func get_usage() -> String:
	return "help [command]"

func get_examples() -> Array[String]:
	return ["help", "help rm", "? cat"]

func get_category() -> String:
	return "HELP"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.size() > 0:
		return _detailed_help(args[0], terminal)

	var lines: Array[String] = []
	lines.append("Commands:")

	# Collect unique command names
	var names := terminal.get_unique_command_names()
	names.sort()

	# Group: CATEGORY -> Array[String command_names]
	var groups: Dictionary = {}

	for name in names:
		var cmd: CommandBase = terminal.commands[name]
		var cat := _normalize_category(_get_command_category(cmd))

		if not groups.has(cat):
			groups[cat] = []
		(groups[cat] as Array).append(name)

	# Determine terminal width (best effort)
	var width := _get_terminal_width(terminal)
	if width <= 0:
		width = DEFAULT_TERM_WIDTH

	# Print in order
	for cat in CATEGORY_ORDER:
		if not groups.has(cat):
			continue

		lines.append("")
		lines.append(_header_line(cat, width))

		var list: Array = groups[cat]
		list.sort()

		for cmd_name in list:
			var cmd2: CommandBase = terminal.commands[cmd_name]
			var desc := cmd2.get_help()
			if desc == "":
				desc = "(no description)"
			lines.append("- [color=lime]%s[/color] : %s" % [cmd_name, desc])

	# Any categories not in CATEGORY_ORDER (future-proof)
	var extra_cats: Array = groups.keys()
	extra_cats.sort()
	for cat2 in extra_cats:
		if CATEGORY_ORDER.has(cat2):
			continue
		lines.append("")
		lines.append(_header_line(cat2, width))

		var list2: Array = groups[cat2]
		list2.sort()
		for cmd_name2 in list2:
			var cmd3: CommandBase = terminal.commands[cmd_name2]
			var desc2 := cmd3.get_help()
			if desc2 == "":
				desc2 = "(no description)"
			lines.append("- [color=lime]%s[/color] : %s" % [cmd_name2, desc2])

	return lines

# -----------------------------
# Header + category helpers
# -----------------------------

func _header_line(title: String, width: int) -> String:
	# Format: ----- TITLE -----
	# Try to fill the full width with dashes around the title.
	var t := " " + title.strip_edges().to_upper() + " "
	var min_len := t.length() + 2 # at least one dash on each side

	if width < min_len:
		width = min_len

	var dash_total := width - t.length()
	var left := int(floor(dash_total / 2.0))
	var right := dash_total - left

	return "[color=lime]%s%s%s[/color]" % [
	"-".repeat(left),
	t,
	"-".repeat(right)
]


func _get_command_category(cmd: CommandBase) -> String:
	if cmd == null:
		return "GENERAL"

	# Safely support commands that don't implement get_category
	if cmd.has_method("get_category"):
		var c := String(cmd.call("get_category"))
		if c.strip_edges() != "":
			return c

	# Fallback: infer based on command name (optional safety net)
	var n := cmd.get_name().to_lower()
	return _infer_category_from_name(n)

func _infer_category_from_name(name_lower: String) -> String:
	match name_lower:
		"help", "?":
			return "HELP"
		"clear", "exit", "list", "echo":
			return "CORE"
		"ls", "cd", "pwd", "cat", "touch", "mkdir", "cp", "mv", "rm":
			return "FILESYSTEM"
		"scan", "connect", "ifconfig", "arp", "ssh":
			return "NETWORK"
		"save", "load", "delete":
			return "SAVES"
		_:
			return "GENERAL"

func _normalize_category(cat: String) -> String:
	var c := cat.strip_edges().to_upper()
	if c == "":
		return "GENERAL"
	return c

func _get_terminal_width(terminal: Terminal) -> int:
	if terminal == null:
		return DEFAULT_TERM_WIDTH

	for p in terminal.get_property_list():
		if String(p.name) == "term_width":
			return int(terminal.get("term_width"))

	return DEFAULT_TERM_WIDTH

# -----------------------------
# Detailed help (unchanged)
# -----------------------------

func _detailed_help(query: String, terminal: Terminal) -> Array[String]:
	var key := query.strip_edges().to_lower()
	var cmd := _find_command_by_name_or_alias(key, terminal)

	if cmd == null:
		return ["help: '%s' is not a recognized command." % key]

	var lines: Array[String] = []
	lines.append("%s - %s" % [cmd.get_name(), cmd.get_help()])
	lines.append("")

	# Usage
	var usage := cmd.get_usage()
	if usage != "":
		lines.append("Usage:")
		lines.append("  " + usage)
		lines.append("")

	# Options
	var options: Array[Dictionary] = cmd.get_options()
	if options.size() > 0:
		lines.append("Options:")
		for opt in options:
			var flag := str(opt.get("flag", "")).strip_edges()
			var long := str(opt.get("long", "")).strip_edges()
			var desc := str(opt.get("desc", "")).strip_edges()
			var left := flag
			if long != "":
				left = "%s, %s" % [flag, long]
			if desc == "":
				desc = "(no description)"
			lines.append("  %-18s %s" % [left, desc])
		lines.append("")

	# Examples
	var examples: Array[String] = cmd.get_examples()
	if examples.size() > 0:
		lines.append("Examples:")
		for ex in examples:
			lines.append("  " + ex)
		lines.append("")

	return lines

func _find_command_by_name_or_alias(name_or_alias: String, terminal: Terminal) -> CommandBase:
	if terminal.commands.has(name_or_alias):
		return terminal.commands[name_or_alias]

	for k in terminal.commands.keys():
		var cmd: CommandBase = terminal.commands[k]

		if cmd.get_name().to_lower() == name_or_alias:
			return cmd

		for a in cmd.get_aliases():
			if a.to_lower() == name_or_alias:
				return cmd

	return null
