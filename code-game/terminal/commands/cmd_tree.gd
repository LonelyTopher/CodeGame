extends CommandBase
class_name CmdTree

# Root-level "system" directories we hide unless -a/--all is used.
const SYSTEM_ROOT_DIRS := {
	"etc": true,
	"var": true,
	"bin": true,
	"usr": true,
	"tmp": true,
	"dev": true,
	"proc": true,
	"sys": true,
	"root": true
}

func get_name() -> String:
	return "tree"

func get_help() -> String:
	return "Display the directory structure as a tree."

func get_usage() -> String:
	return "tree [path] [-a|--all] [-d|--files-only] [-L <depth>] [-f] [--dirsfirst] [--nocolor] [-P <pattern>] [--count-only] [--ascii] [-s]"

func get_options() -> Array[Dictionary]:
	return [
		{"flag":"-a", "long":"--all", "desc":"Show all entries (including dotfiles and system root dirs)."},
		{"flag":"-d", "long":"", "desc":"List directories only."},
		{"flag":"", "long":"--files-only", "desc":"List files only."},
		{"flag":"-L", "long":"", "desc":"Limit the display depth. Example: -L 2"},
		{"flag":"-f", "long":"", "desc":"Print full paths for entries."},
		{"flag":"", "long":"--dirsfirst", "desc":"List directories before files."},
		{"flag":"", "long":"--nocolor", "desc":"Disable colored directory output."},
		{"flag":"-P", "long":"", "desc":"Only show entries that match a glob pattern (* and ?). Example: -P *.txt"},
		{"flag":"", "long":"--count-only", "desc":"Print only the summary counts."},
		{"flag":"", "long":"--ascii", "desc":"Use ASCII branch characters instead of Unicode."},
		{"flag":"-s", "long":"", "desc":"Show file sizes (based on content length)."},
	]

func get_examples() -> Array[String]:
	return [
		"tree",
		"tree /home",
		"tree /",
		"tree -a /",
		"tree -d",
		"tree --files-only",
		"tree -L 2",
		"tree -f --dirsfirst",
		"tree -P *.txt",
		"tree --ascii",
		"tree --count-only"
	]

func get_category() -> String:
	return "FILESYSTEM"

# -------------------- main --------------------

func run(args: Array[String], terminal: Terminal) -> Array[String]:
	var show_all := false
	var dirs_only := false
	var files_only := false
	var max_depth := -1 # -1 = unlimited
	var full_paths := false
	var dirs_first := false
	var no_color := false
	var count_only := false
	var ascii := false
	var show_sizes := false

	var pattern := ""
	var re: RegEx = null

	# optional path (first non-flag token)
	var target_path := ""

	# parse args
	var i := 0
	while i < args.size():
		var a := args[i]

		match a:
			"-a", "--all":
				show_all = true
			"-d":
				dirs_only = true
			"--files-only":
				files_only = true
			"-L":
				if i + 1 >= args.size():
					return ["tree: option requires an argument: -L"]
				var v := args[i + 1]
				if not v.is_valid_int():
					return ["tree: invalid depth for -L: " + v]
				max_depth = int(v)
				i += 1
			"-f":
				full_paths = true
			"--dirsfirst":
				dirs_first = true
			"--nocolor":
				no_color = true
			"-P":
				if i + 1 >= args.size():
					return ["tree: option requires an argument: -P"]
				pattern = args[i + 1]
				i += 1
			"--count-only":
				count_only = true
			"--ascii":
				ascii = true
			"-s":
				show_sizes = true
			_:
				# non-flag = path (only allow one)
				if a.begins_with("-"):
					return ["tree: unknown option: " + a]
				if target_path != "":
					return ["tree: too many paths (only one allowed)"]
				target_path = a

		i += 1

	# validate flag conflicts
	if dirs_only and files_only:
		return ["tree: cannot use -d with --files-only"]

	# resolve root path
	var root_path := terminal.cwd
	if target_path != "":
		root_path = terminal.resolve_path(target_path)

	if not terminal.fs.is_dir(root_path):
		return ["tree: not a directory: " + root_path]

	# build glob regex if needed
	if pattern != "":
		re = _glob_to_regex(pattern)
		if re == null:
			return ["tree: invalid pattern: " + pattern]

	# Tree output
	var lines: Array[String] = []
	var counts := {"dirs": 0, "files": 0}

	# root header
	var root_name := _display_name(root_path)
	var root_display := "*" + root_name
	root_display = _maybe_color_dir(root_display, no_color)
	lines.append(root_display)
	counts["dirs"] = 1

	# depth: if max_depth == 1, only show root
	if max_depth == 1:
		if count_only:
			return [_summary_line(counts, dirs_only, files_only)]
		lines.append("")
		lines.append(_summary_line(counts, dirs_only, files_only))
		return lines

	_build_tree(
		lines,
		terminal,
		root_path,
		"",
		1,
		max_depth,
		show_all,
		dirs_only,
		files_only,
		full_paths,
		dirs_first,
		no_color,
		ascii,
		show_sizes,
		re,
		counts
	)

	if count_only:
		return [_summary_line(counts, dirs_only, files_only)]

	lines.append("")
	lines.append(_summary_line(counts, dirs_only, files_only))
	return lines

# -------------------- helpers --------------------

func _display_name(path: String) -> String:
	if path == "/":
		return "/"
	return path.get_file()

func _summary_line(counts: Dictionary, dirs_only: bool, files_only: bool) -> String:
	var d := int(counts.get("dirs", 0))
	var f := int(counts.get("files", 0))
	if dirs_only:
		return "%d directories" % d
	if files_only:
		return "%d files" % f
	return "%d directories, %d files" % [d, f]

func _maybe_color_dir(s: String, no_color: bool) -> String:
	if no_color:
		return s
	return "[color=lime]" + s + "[/color]"

func _file_size_bytes(terminal: Terminal, path: String) -> int:
	# "size" = length of file content in bytes (good enough for your virtual FS)
	var txt := terminal.fs.read_file(path)
	return txt.to_utf8_buffer().size()

func _matches(re: RegEx, name: String) -> bool:
	if re == null:
		return true
	return re.search(name) != null

func _glob_to_regex(glob: String) -> RegEx:
	# supports * and ? (simple glob)
	var escaped := ""
	for ch in glob:
		match ch:
			"*":
				escaped += ".*"
			"?":
				escaped += "."
			".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\", "/":
				escaped += "\\" + ch
			_:
				escaped += ch

	var r := RegEx.new()
	var err := r.compile("^" + escaped + "$")
	if err != OK:
		return null
	return r

func _child_path(dir_path: String, name: String) -> String:
	var p := dir_path.rstrip("/") + "/" + name
	if dir_path == "/":
		p = "/" + name
	return p

func _is_hidden_or_system(dir_path: String, name: String, show_all: bool) -> bool:
	if show_all:
		return false

	# Hide dotfiles unless -a
	if name.begins_with("."):
		return true

	# Hide system root dirs unless -a (only when listing the root "/")
	if dir_path == "/" and SYSTEM_ROOT_DIRS.has(name):
		return true

	return false

func _build_tree(
	lines: Array[String],
	terminal: Terminal,
	dir_path: String,
	prefix: String,
	depth: int,
	max_depth: int,
	show_all: bool,
	dirs_only: bool,
	files_only: bool,
	full_paths: bool,
	dirs_first: bool,
	no_color: bool,
	ascii: bool,
	show_sizes: bool,
	re: RegEx,
	counts: Dictionary
) -> void:
	if max_depth != -1 and depth >= max_depth:
		return

	var names := terminal.fs.list_dir(dir_path)
	names.sort()

	# optional dirs-first ordering
	if dirs_first:
		var dirs: Array[String] = []
		var files: Array[String] = []
		for n in names:
			if _is_hidden_or_system(dir_path, n, show_all):
				continue
			var cp := _child_path(dir_path, n)
			if terminal.fs.is_dir(cp):
				dirs.append(n)
			else:
				files.append(n)
		names = dirs + files
	else:
		# still need to filter hidden/system before later logic
		var filtered: Array[String] = []
		for n in names:
			if _is_hidden_or_system(dir_path, n, show_all):
				continue
			filtered.append(n)
		names = filtered

	# filter by pattern AND mode, but keep a "final list" so is_last works right
	var final: Array[String] = []
	for n in names:
		if not _matches(re, n):
			continue
		var cp := _child_path(dir_path, n)
		var is_dir := terminal.fs.is_dir(cp)

		if dirs_only and not is_dir:
			continue
		if files_only and is_dir:
			# we still want to traverse into dirs even if we don't print them,
			# but whether we traverse is handled later.
			continue

		final.append(n)

	# When NOT files_only, we print from final list (dirs + files or dirs only)
	for idx in range(final.size()):
		var name := final[idx]
		var is_last := (idx == final.size() - 1)
		var cp := _child_path(dir_path, name)
		var is_dir := terminal.fs.is_dir(cp)

		var branch := ""
		if ascii:
			branch = "`-- " if is_last else "|-- "
		else:
			branch = "└─ " if is_last else "├─ "

		var shown_name := name
		if full_paths:
			shown_name = cp

		# decorate
		if is_dir:
			shown_name = "*" + shown_name
			shown_name = _maybe_color_dir(shown_name, no_color)
			counts["dirs"] = int(counts.get("dirs", 0)) + 1
		else:
			if show_sizes:
				var sz := _file_size_bytes(terminal, cp)
				shown_name = "%s (%d B)" % [shown_name, sz]
			counts["files"] = int(counts.get("files", 0)) + 1

		lines.append(prefix + branch + shown_name)

		# descend if dir
		if is_dir:
			var next_prefix := ""
			if ascii:
				next_prefix = prefix + ("    " if is_last else "|   ")
			else:
				next_prefix = prefix + ("   " if is_last else "│  ")
			_build_tree(lines, terminal, cp, next_prefix, depth + 1, max_depth, show_all, dirs_only, files_only, full_paths, dirs_first, no_color, ascii, show_sizes, re, counts)

	# Special handling for files_only: traverse directories even though we didn't print them.
	if files_only:
		var dir_names := terminal.fs.list_dir(dir_path)
		dir_names.sort()

		if dirs_first:
			var ds: Array[String] = []
			var fs: Array[String] = []
			for n in dir_names:
				if _is_hidden_or_system(dir_path, n, show_all):
					continue
				var cp := _child_path(dir_path, n)
				if terminal.fs.is_dir(cp):
					ds.append(n)
				else:
					fs.append(n)
			dir_names = ds + fs
		else:
			var filtered_dirs: Array[String] = []
			for n in dir_names:
				if _is_hidden_or_system(dir_path, n, show_all):
					continue
				filtered_dirs.append(n)
			dir_names = filtered_dirs

		for n in dir_names:
			var cp2 := _child_path(dir_path, n)
			if terminal.fs.is_dir(cp2):
				# traverse regardless of pattern; pattern applies to printed entries
				_build_tree(lines, terminal, cp2, prefix, depth + 1, max_depth, show_all, dirs_only, files_only, full_paths, dirs_first, no_color, ascii, show_sizes, re, counts)
