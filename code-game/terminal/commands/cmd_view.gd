extends CommandBase
class_name CmdView

func get_name() -> String:
	return "view"

func get_aliases() -> Array[String]:
	return ["inspect", "dump"]

func get_help() -> String:
	return "Inspect a file. Supports text files and structured .dat files."

func get_usage() -> String:
	return "view <path>"

func get_examples() -> Array[String]:
	return ["view /home/readme.txt", "view /bank/ledger.dat", "inspect money.dat"]

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	if args.is_empty():
		return ["Usage: " + get_usage()]

	var path := args[0]
	var full := _resolve_path(terminal, path)

	var dev = terminal.current_device
	if dev == null or dev.fs == null:
		return ["No active device."]

	var fs: FileSystem = dev.fs

	if not fs.exists(full):
		return ["No such file: " + full]

	# Directories: show a tiny listing
	if fs.is_dir(full):
		var items := fs.list_dir(full)
		if items.is_empty():
			return [full + " (empty)"]
		return [full + ":\n  " + "\n  ".join(items)]

	# Normal text file
	if fs.is_file(full):
		var txt := fs.read_file(full)
		if txt == "":
			return ["(empty)"]
		return [txt]

	# Data file
	if fs.has_method("is_data_file") and fs.is_data_file(full):
		var data := fs.read_data_file(full)

		# Pretty output (not raw JSON yet)
		var lines: Array[String] = []
		lines.append("== DATA FILE ==")
		lines.append("path: " + full)
		lines.append("keys: " + ", ".join(_sorted_keys(data)))
		lines.append("")
		lines.append(_pretty_dict(data, 0))
		return [ "\n".join(lines) ]

	return ["Unsupported node type at: " + full]


# -------------------------
# Helpers
# -------------------------

func _resolve_path(term: Terminal, p: String) -> String:
	if p.begins_with("/"):
		return p
	# relative -> combine with cwd
	var base := term.cwd
	if not base.ends_with("/"):
		base += "/"
	return (base + p).replace("//", "/")

func _sorted_keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in d.keys():
		out.append(String(k))
	out.sort()
	return out

func _pretty_dict(d: Dictionary, indent: int) -> String:
	var pad := "  ".repeat(indent)
	var keys := _sorted_keys(d)
	var lines: Array[String] = []
	lines.append(pad + "{")
	for k in keys:
		var v: Variant = d[k]
		lines.append(pad + "  " + String(k) + ": " + _pretty_value(v, indent + 1))
	lines.append(pad + "}")
	return "\n".join(lines)

func _pretty_array(a: Array, indent: int) -> String:
	var pad := "  ".repeat(indent)
	var lines: Array[String] = []
	lines.append("[")
	for v in a:
		lines.append(pad + _pretty_value(v, indent))
	lines.append("  ".repeat(indent - 1) + "]")
	return "\n".join(lines)

func _pretty_value(v: Variant, indent: int) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			return "\n" + _pretty_dict(v as Dictionary, indent)
		TYPE_ARRAY:
			return "\n" + _pretty_array(v as Array, indent + 1)
		TYPE_STRING:
			return "\"" + String(v) + "\""
		_:
			return str(v)
