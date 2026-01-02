extends RefCounted
class_name Terminal

# Command name/alias -> CommandBase #
var commands: Dictionary = {}
var fs: FileSystem
var cwd: String = "/"

func register_command(cmd: CommandBase) -> void:
	commands[cmd.get_name()] = cmd
	for a in cmd.get_aliases():
		commands[a] = cmd
		
func execute(line: String) -> Array[String]:
	var text := line.strip_edges()
	if text.is_empty():
		return []
		
	var parts := text.split(" ", false)
	var name := parts[0].to_lower()
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])
		
	if not commands.has(name):
		return ["Unknown command: " + parts[0]]
		
	var cmd: CommandBase = commands[name]
	return cmd.run(args, self)

func load_commands_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Terminal: Could not open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		# Skip folders and non-gd files
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var full_path := dir_path.rstrip("/") + "/" + file_name
			var script := load(full_path)

			# Only handle valid scripts
			if script is Script:
				var obj = script.new()

				# Only register if it's a CommandBase
				if obj is CommandBase:
					register_command(obj)
				else:
					# Not a command script; ignore quietly or warn
					# print("Skipping non-command script:", full_path)
					pass

		file_name = dir.get_next()

	dir.list_dir_end()

func resolve_path(input_path: String) -> String:
	var p := input_path.strip_edges()
	if p == "" or p == ".":
		return cwd
	if p.begins_with("/"):
		return p
	# relative
	if cwd == "/":
		return "/" + p
	return cwd.rstrip("/") + "/" + p

func get_unique_command_names() -> Array[String]:
	var unique := {} # name -> true

	for key in commands.keys():
		var cmd: CommandBase = commands[key]
		unique[cmd.get_name()] = true

	var names: Array[String] = []
	for k in unique.keys():
		names.append(String(k))  # ensure it's a String
	return names
