extends CommandBase
class_name CmdCp

func get_name() -> String:
	return "cp"

func get_help() -> String:
	return "Copy a file to a destination."

func get_usage() -> String:
	return "cp <source> <destination>"

func get_options() -> Array[Dictionary]:
	return [] # we can add -r later

func get_examples() -> Array[String]:
	return [
		"cp readme.txt readme_backup.txt",
		"cp /home/readme.txt /home/local/readme.txt",
		"cp notes.txt local/notes.txt"
	]

func get_category() -> String:
	return "FILESYSTEM"

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.size() < 2:
		return ["cp: missing source or destination"]

	var src_arg := args[0]
	var dst_arg := args[1]

	var src := terminal.resolve_path(src_arg)
	var dst := terminal.resolve_path(dst_arg)

	# source must exist and be a file
	if not terminal.fs.exists(src):
		return ["cp: cannot stat '%s': No such file" % src_arg]

	if terminal.fs.is_dir(src):
		return ["cp: -r not specified; omitting directory '%s'" % src_arg]

	# destination: if it's a directory, copy into it using same filename
	if terminal.fs.is_dir(dst):
		var name := src.get_file()
		dst = dst.rstrip("/") + "/" + name

	# attempt copy
	if not terminal.fs.copy_file(src, dst):
		return ["cp: cannot create '%s': No such directory" % dst_arg]

	return []
