extends CommandBase
class_name CmdHelp

func get_name() -> String:
	return "help"
	
func get_aliases() -> Array[String]:
	return ["?"]
	
func get_help() -> String:
	return "List available commands"
	
func run(_args: Array[String], terminal: Terminal) -> Array[String]:
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

	return lines
