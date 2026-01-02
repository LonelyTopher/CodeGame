extends CommandBase
class_name CmdCat

func get_name() -> String:
	return "cat"

func get_help() -> String:
	return "Display the contents of a file."

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["cat: missing file"]

	var path := terminal.resolve_path(args[0])
	var content := terminal.fs.read_file(path)
	if content == "":
		# could be empty file or missing; simplest message:
		if not terminal.fs.exists(path):
			return ["cat: no such file: " + args[0]]
		return [""] # empty file

# split() return PackedStringArray -> convert to Array[String] #
	var packed: PackedStringArray = content.split("/n", false)
	var lines: Array[String] = []
	lines.assign(packed)
	return lines
