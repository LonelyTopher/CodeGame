extends CommandBase
class_name CmdHelp

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

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.size() > 0:
		return _detailed_help(args[0], terminal)

	var lines: Array[String] = []
	lines.append("Commands:")

	var names := terminal.get_unique_command_names()
	names.sort()

	for name in names:
		var cmd: CommandBase = terminal.commands[name]
		var desc := cmd.get_help()
		if desc == "":
			desc = "(no description)"
		lines.append("- %s : %s" % [name, desc])

	lines.append("")
	lines.append("Type 'help <command>' for more info.")
	return lines

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
	# direct dict key
	if terminal.commands.has(name_or_alias):
		return terminal.commands[name_or_alias]

	# search through commands for matching name/alias
	for k in terminal.commands.keys():
		var cmd: CommandBase = terminal.commands[k]

		if cmd.get_name().to_lower() == name_or_alias:
			return cmd

		for a in cmd.get_aliases():
			if a.to_lower() == name_or_alias:
				return cmd

	return null
