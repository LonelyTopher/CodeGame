extends CommandBase
class_name CmdMv

func get_name() -> String:
	return "mv"

func get_help() -> String:
	return "Move (rename) a file."

func get_usage() -> String:
	return "mv <source> <destination>"

func get_options() -> Array[Dictionary]:
	return [] # we can add -f, -n, -i later

func get_examples() -> Array[String]:
	return [
		"mv notes.txt notes_old.txt",
		"mv readme.txt local/readme.txt",
		"mv /home/local/file.txt /home/file.txt"
	]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.size() < 2:
		return ["mv: missing source or destination"]

	var src_arg := args[0]
	var dst_arg := args[1]

	var src := terminal.resolve_path(src_arg)
	var dst := terminal.resolve_path(dst_arg)

	# source must exist
	if not terminal.fs.exists(src):
		return ["mv: cannot stat '%s': No such file" % src_arg]

	# v1: file-only
	if terminal.fs.is_dir(src):
		return ["mv: cannot move '%s': Is a directory" % src_arg]

	# if destination is a directory, move into it with same filename
	if terminal.fs.is_dir(dst):
		var name := src.get_file()
		dst = dst.rstrip("/") + "/" + name

	# attempt move
	if not terminal.fs.move_file(src, dst):
		return ["mv: cannot move '%s' to '%s'" % [src_arg, dst_arg]]

	return []
