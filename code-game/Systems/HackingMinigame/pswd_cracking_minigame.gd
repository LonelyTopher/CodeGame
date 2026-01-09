extends Node
class_name PswdCrackingMinigame

signal crack_success
signal crack_failed
signal crack_closed

const GRID_W := 125
const GRID_H := 25
const HEADER_LINES := 5
const DEFAULT_ATTEMPTS := 10

const INVALID_POS := Vector2i(-999, -999)

# Mouse alignment tuning:
const MOUSE_X_BIAS_PX := 0.0
const MOUSE_Y_BIAS_FRAC := 0.25

# Visual tuning
const SOUP_COLOR := "#008000"
const TOKEN_COLOR := "lime"

const SPECIAL_TOKENS: Array[Dictionary] = [
	{"text":"<@", "effect":"GAIN_ATTEMPT"},
	{"text":"%*", "effect":"REVEAL_NEXT"},
	{"text":"<>", "effect":"GAIN_ATTEMPT"},
	{"text":"{}", "effect":"REVEAL_NEXT"},
	{"text":"+=", "effect":"GAIN_ATTEMPT"},
	{"text":"!?", "effect":"REVEAL_NEXT"},
]

# Soup characters (BBCode-safe; no [ ])
const JUNK_CHARS := "!@#$%^&*()_+-={}`~;:'\",.<>?/\\|"

# Hint tuning
const WRONGS_FOR_HINT := 3
const HINT_FLASH_SECONDS := 0.55

# --- XP routing ---
const HACKING_STAT_ID_PRIMARY := "hacking"
const HACKING_STAT_ID_FALLBACKS := ["hack", "intrusion", "exploit"] # used only if you named it differently


static func _letter_token(ch: String) -> String:
	return "<%s>" % ch


# ------------------------------------------------------------
# Public state
# ------------------------------------------------------------
var terminal: Terminal = null
var screen: Node = null             # modal surface
var _main_screen: Node = null       # underlying terminal screen (where animations print)
var source_device: Device = null
var target_ip: String = "--"

var difficulty_tier := 1
var attempts_left := DEFAULT_ATTEMPTS

# Password is authored (from target device)
var _password := ""
var _mask: Array[String] = []
var _reveal_index := 0

var _status := ""
var _cursor_on := true
var _cursor_task_running := false
var _last_input := ""

var _rng := RandomNumberGenerator.new()
var _block_base_line := -1
var _is_generated := false

# grid + tokens
var _grid: Array[String] = []
var _tokens: Dictionary = {}          # token_id -> dict
var _cell_to_token: Dictionary = {}   # "x,y" -> token_id
var _next_token_id := 1

# hover
var _hover_row := -1
var _hover_col := -1
var _hover_token_id := -1

# wrong streak -> hint
var _wrong_streak := 0
var _hint_token_id := -1
var _hint_timer_running := false

# for success/fail routing
var _target_obj: Object = null
var _p_target_is_device := false

# xp bookkeeping for post-minigame animation
var _last_xp_awarded: int = 0


# ------------------------------------------------------------
# BBCode safety
# ------------------------------------------------------------
func _bb_escape(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")


# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------
func setup_and_generate(
	p_terminal: Terminal,
	p_target: Object,
	p_hack_chance: float = 0.99,
	p_source: Device = null,
	p_attempts: int = DEFAULT_ATTEMPTS
) -> void:
	_rng.randomize()
	_is_generated = false
	_last_xp_awarded = 0

	terminal = p_terminal
	if terminal == null:
		push_error("PswdCrackingMinigame: terminal is null")
		return

	_main_screen = terminal.screen
	if _main_screen == null:
		push_error("PswdCrackingMinigame: terminal.screen is null")
		return

	# Default to terminal screen (but we will swap to modal surface)
	screen = _main_screen

	# OPEN CENTER MODAL WINDOW and print into that surface
	if screen.has_method("open_modal_window"):
		var modal_surface = screen.call("open_modal_window", self)
		if modal_surface != null:
			screen = modal_surface

	source_device = p_source
	attempts_left = p_attempts
	difficulty_tier = _tier_from_hack_chance(p_hack_chance)

	_target_obj = p_target
	_p_target_is_device = _is_device_target(_target_obj)

	# Hook signals (avoid double connect)
	if is_connected("crack_success", Callable(self, "_on_crack_success")):
		disconnect("crack_success", Callable(self, "_on_crack_success"))
	if is_connected("crack_failed", Callable(self, "_on_crack_failed")):
		disconnect("crack_failed", Callable(self, "_on_crack_failed"))
	connect("crack_success", Callable(self, "_on_crack_success"))
	connect("crack_failed", Callable(self, "_on_crack_failed"))

	# AUTHORED PASSWORD
	_password = _get_target_password(p_target)
	if _password == "":
		_password = "ADMIN"

	_password = _sanitize_password(_password)

	_mask.clear()
	for i in range(_password.length()):
		_mask.append("_")

	_reveal_index = 0
	_last_input = ""
	_status = _trace_idle_line()

	_hover_row = -1
	_hover_col = -1
	_hover_token_id = -1

	_wrong_streak = 0
	_hint_token_id = -1
	_hint_timer_running = false

	_build_grid()
	_print_block()

	screen.append_line("Type: pick <row> <col>   (example: pick 3 44)")
	screen.append_line("Type: close              (to exit minigame)")

	_is_generated = true
	_start_cursor_blink()


# Accept either:
# - target is Device with network_password
# - target has .device which is Device with network_password
func _get_target_password(p_target: Object) -> String:
	if p_target == null:
		return ""
	if "network_password" in p_target:
		return str(p_target.get("network_password"))
	if "device" in p_target:
		var d = p_target.get("device")
		if d != null and ("network_password" in d):
			return str(d.get("network_password"))
	return ""


func _sanitize_password(s: String) -> String:
	var up := s.strip_edges().to_upper()
	var out := ""
	for i in range(up.length()):
		var ch := up.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_letter := code >= 65 and code <= 90
		var is_digit := code >= 48 and code <= 57
		if is_letter or is_digit:
			out += ch
	return out


# ------------------------------------------------------------
# Terminal input
# ------------------------------------------------------------
func handle_terminal_line(line: String) -> bool:
	var t := line.strip_edges()
	if t == "":
		return true

	var low := t.to_lower()

	if low == "close" or low == "exit":
		close()
		return true

	var parts := t.split(" ", false)
	if parts.size() == 3 and parts[0].to_lower() == "pick":
		var r := int(parts[1])
		var c := int(parts[2])

		_last_input = "pick %d %d" % [r, c]
		var result_key := _pick_cell_internal(r, c)
		_status = _trace_line(result_key, _last_input)
		_rerender_header_only()
		_render_grid_row(r)
		return true

	_last_input = t
	_status = "TRACE: > %s  → invalid (use: pick <row> <col> | close)%s" % [_last_input, _cursor_char()]
	_rerender_header_only()
	return true


# ------------------------------------------------------------
# Mouse input
# ------------------------------------------------------------
func handle_mouse_move(local_pos: Vector2, output: RichTextLabel, scroll: ScrollContainer) -> bool:
	if not _is_generated or _block_base_line < 0:
		return false

	var rc: Vector2i = _mouse_to_row_col(local_pos, output, scroll)
	if rc == INVALID_POS:
		if _hover_row != -1:
			var prev := _hover_row
			_hover_row = -1
			_hover_col = -1
			_hover_token_id = -1
			_render_grid_row(prev)
		return false

	var row := rc.x
	var col := rc.y

	if row == _hover_row and col == _hover_col:
		return true

	var old_row := _hover_row
	var old_token := _hover_token_id

	_hover_row = row
	_hover_col = col

	var key := "%d,%d" % [col, row]
	_hover_token_id = int(_cell_to_token[key]) if _cell_to_token.has(key) else -1

	if old_row != -1 and (old_row != row or old_token != _hover_token_id):
		_render_grid_row(old_row)
	_render_grid_row(row)

	return true


func handle_mouse_click(local_pos: Vector2, output: RichTextLabel, scroll: ScrollContainer) -> bool:
	if not _is_generated or _block_base_line < 0:
		return false

	var rc: Vector2i = _mouse_to_row_col(local_pos, output, scroll)
	if rc == INVALID_POS:
		return false

	var row := rc.x
	var col := rc.y

	_last_input = "pick %d %d" % [row, col]
	var result_key := _pick_cell_internal(row, col)
	_status = _trace_line(result_key, _last_input)

	_rerender_header_only()
	_render_grid_row(row)
	return true


# ------------------------------------------------------------
# Picking logic
# ------------------------------------------------------------
func _pick_cell_internal(row: int, col: int) -> String:
	if attempts_left <= 0:
		return "locked"

	if row < 0 or row >= GRID_H or col < 0 or col >= GRID_W:
		return "bounds"

	var key := "%d,%d" % [col, row]
	if not _cell_to_token.has(key):
		return "junk"

	var token_id := int(_cell_to_token[key])
	var t: Dictionary = _tokens.get(token_id, {})
	if t.is_empty():
		return "junk"

	if bool(t.get("used", false)):
		return "used"

	var kind := str(t.get("kind", ""))
	if kind == "letter":
		return _click_letter_token(token_id, t)
	if kind == "special":
		return _click_special_token(token_id, t)

	return "junk"


# Manual close
func close() -> void:
	_is_generated = false
	_status = "TRACE: > closed"
	_rerender_header_only()

	if terminal != null and terminal.screen != null and terminal.screen.has_method("close_modal_window"):
		terminal.screen.call("close_modal_window")

	emit_signal("crack_closed")


# SUCCESS/FAIL CLOSE (silent)
func _close_modal_silent() -> void:
	_is_generated = false
	if terminal != null and terminal.screen != null and terminal.screen.has_method("close_modal_window"):
		terminal.screen.call("close_modal_window")


# ------------------------------------------------------------
# Completion handlers
# ------------------------------------------------------------
func _on_crack_success() -> void:
	_close_modal_silent()
	_success_flow()


func _on_crack_failed() -> void:
	_close_modal_silent()
	_fail_flow()


# ------------------------------------------------------------
# Post-minigame animations
# ------------------------------------------------------------
func _success_flow() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_apply_success_connection()
		return

	_print_main("")
	_print_main(">> exploit accepted")
	await tree.create_timer(0.20).timeout
	_print_main(">> negotiating handshake...")
	await tree.create_timer(0.25).timeout
	_print_main(">> elevating session...")
	await tree.create_timer(0.25).timeout
	_print_main(">> ACCESS GRANTED")
	await tree.create_timer(0.15).timeout

	_apply_success_connection()

	# ✅ NEW: show XP gained (after applying success so it’s accurate)
	if _last_xp_awarded > 0:
		await tree.create_timer(0.10).timeout
		_print_main(">> hacking.xp awarded: +%d" % _last_xp_awarded)
	else:
		await tree.create_timer(0.10).timeout
		_print_main(">> hacking.xp awarded: +0")


func _fail_flow() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	_print_main("")

	# Award 1 XP ONLY for lockout / failed minigame attempt (your request)
	_last_xp_awarded = _award_hacking_xp(1)

	# WIFI: auth fail (NOT a “lockout” vibe, but still a failed attempt)
	if _is_network_target(_target_obj) and not _p_target_is_device:
		_print_main(">> authentication failed")
		await tree.create_timer(0.20).timeout
		_print_main(">> cannot connect: invalid credentials")
		await tree.create_timer(0.15).timeout
		_print_main(">> hacking.xp awarded: +%d" % _last_xp_awarded)
		return

	# SSH / Device: harsher failure vibe
	_print_main(">> exploit rejected")
	await tree.create_timer(0.20).timeout
	_print_main(">> attempts exhausted")
	await tree.create_timer(0.20).timeout
	_print_main(">> LOCKED OUT")
	await tree.create_timer(0.15).timeout
	_print_main(">> hacking.xp awarded: +%d" % _last_xp_awarded)

	if terminal != null and terminal.has_method("on_minigame_failed"):
		terminal.call("on_minigame_failed", {"target": _target_obj, "target_ip": target_ip})


func _print_main(line: String) -> void:
	if _main_screen == null:
		return
	if _main_screen.has_method("append_line"):
		_main_screen.call("append_line", line)


# ------------------------------------------------------------
# XP AWARDING (uses your StatsSystem)
# ------------------------------------------------------------
func _get_stats_system() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.get_root()
	return root.get_node_or_null("/root/StatsSystem")


func _resolve_hacking_stat_id(stats_system: Node) -> String:
	if stats_system == null:
		return HACKING_STAT_ID_PRIMARY

	if stats_system.has_method("has_stat") and stats_system.call("has_stat", HACKING_STAT_ID_PRIMARY):
		return HACKING_STAT_ID_PRIMARY

	# fallback tries only if you named it differently
	if stats_system.has_method("has_stat"):
		for sid in HACKING_STAT_ID_FALLBACKS:
			if stats_system.call("has_stat", sid):
				return sid

	# default (will just award 0 if missing)
	return HACKING_STAT_ID_PRIMARY


func _award_hacking_xp(amount: int) -> int:
	if amount <= 0:
		return 0

	var ss := _get_stats_system()
	if ss == null:
		return 0

	var stat_id := _resolve_hacking_stat_id(ss)

	if ss.has_method("award_xp"):
		# StatsSystem.award_xp returns gained after diminishing returns
		return int(ss.call("award_xp", stat_id, int(amount)))

	return 0


func _award_xp_for_device(dev: Object) -> int:
	if dev == null:
		return 0

	var already := false
	if "was_hacked" in dev:
		already = bool(dev.get("was_hacked"))
	elif dev.has_meta("was_hacked"):
		already = bool(dev.get_meta("was_hacked"))

	var xp_first := _get_int_field(dev, "hack_xp_first", 0)
	var xp_repeat := _get_int_field(dev, "hack_xp_repeat", 0)

	var award := xp_repeat if already else xp_first
	var gained := _award_hacking_xp(award)

	# Mark device as hacked
	if "was_hacked" in dev:
		dev.set("was_hacked", true)
	else:
		dev.set_meta("was_hacked", true)

	return gained


func _award_xp_for_network(net: Object) -> int:
	if net == null:
		return 0
	var base := _get_int_field(net, "hack_xp", 0)
	return _award_hacking_xp(base)


func _get_int_field(o: Object, field: String, fallback: int = 0) -> int:
	if o == null:
		return fallback
	if field in o:
		var v = o.get(field)
		if v == null:
			return fallback
		return int(v)
	if o.has_meta(field):
		var mv = o.get_meta(field)
		if mv == null:
			return fallback
		return int(mv)
	return fallback


# ------------------------------------------------------------
# Connection application (SSH vs Network)
# ------------------------------------------------------------
func _apply_success_connection() -> void:
	# ------------------------------------------------------------
	# SSH TARGET (Device)
	# ------------------------------------------------------------
	if _p_target_is_device:
		var dev_for_xp := _extract_device(_target_obj)
		_last_xp_awarded = _award_xp_for_device(dev_for_xp)

		# Keep existing success behavior
		if terminal != null and terminal.has_method("on_minigame_success"):
			terminal.call("on_minigame_success", {"target": _target_obj, "target_ip": target_ip})
			return

		var dev := _extract_device(_target_obj)
		if dev != null:
			_enter_remote_session(dev)
			_print_main(">> session: remote shell opened")
			return

		_print_main(">> connection established")
		return

	# ------------------------------------------------------------
	# WIFI / NETWORK TARGET
	# ------------------------------------------------------------
	if _is_network_target(_target_obj) and source_device != null:
		if source_device.has_method("detach_from_network") and source_device.has_method("attach_to_network"):
			# Detach old network (if any)
			if "network" in source_device and source_device.get("network") != null:
				source_device.call("detach_from_network")

			# Attach to new network (assigns IP)
			source_device.call("attach_to_network", _target_obj)

			# ✅ Award XP for network
			_last_xp_awarded = _award_xp_for_network(_target_obj)

			# Mark network hacked (password remembered)
			if "was_hacked" in _target_obj:
				_target_obj.set("was_hacked", true)
			else:
				_target_obj.set_meta("was_hacked", true)

			var ssid := _get_field_str(_target_obj, "name", "unknown-ssid")
			var subnet := _get_field_str(_target_obj, "subnet", "--")
			var new_ip := _get_dev_field_str(source_device, "ip_address", "--")
			var ip_prefix := _ip_prefix_24(new_ip)

			_print_main(">> connection established")
			_print_main("Network: %s" % subnet)
			_print_main("Assigned IP address: %s" % new_ip)
			_print_main("")

			var vendor := _get_field_str(_target_obj, "vendor", "unknown")
			var notes := _get_field_str(_target_obj, "notes", "none")
			var visibility := _get_field_str(_target_obj, "visibility", "Public")
			var security := _get_field_str(_target_obj, "security", _get_field_str(_target_obj, "encryption", "OPEN"))
			var bssid := _get_field_str(_target_obj, "bssid", "--")
			var channel := _get_field_str(_target_obj, "channel", _get_field_str(_target_obj, "chan", "--"))
			var mode := _get_field_str(_target_obj, "mode", "--")

			_print_main(">> ssid..............: %s" % ssid)
			_print_main(">> bssid.............: %s" % bssid)
			_print_main(">> vendor............: %s" % vendor)
			_print_main(">> security..........: %s" % security)
			_print_main(">> radio.mode........: %s" % mode)
			_print_main(">> radio.channel.....: %s" % channel)
			_print_main(">> dhcp.lease........: granted")
			_print_main(">> route.default.....: %s" % (("%s.1" % ip_prefix) if ip_prefix != "" else "assigned"))
			_print_main(">> dns.server........: %s" % (("%s.1" % ip_prefix) if ip_prefix != "" else "auto"))
			_print_main(">> network.visibility: %s" % visibility)
			_print_main(">> network.notes.....: %s" % notes)
			_print_main(">> hint: run 'arp' to discover devices on this network.")
			return

	_print_main(">> connection established")


func _enter_remote_session(dev: Object) -> void:
	if terminal == null:
		return

	if "device_stack" in terminal:
		var st = terminal.get("device_stack")
		if st is Array:
			st.append(dev)
			terminal.set("device_stack", st)

	if "current_device" in terminal:
		terminal.set("current_device", dev)

	if terminal.has_method("set_current_device"):
		terminal.call("set_current_device", dev)


func _is_device_target(t: Object) -> bool:
	if t == null:
		return false
	if t is Device:
		return true
	if "device" in t:
		var d = t.get("device")
		return (d != null)
	return false


func _extract_device(t: Object) -> Object:
	if t == null:
		return null
	if t is Device:
		return t
	if "device" in t:
		return t.get("device")
	return null


# identify network-ish targets safely
func _is_network_target(t: Object) -> bool:
	if t == null:
		return false
	if "subnet" in t:
		return true
	if "ssid" in t:
		return true
	if "name" in t and "network_password" in t:
		return true
	return false


# generic field getter
func _get_field_str(o: Object, field: String, fallback: String = "--") -> String:
	if o == null:
		return fallback
	if field in o:
		var v = o.get(field)
		if v == null:
			return fallback
		var s := str(v)
		return fallback if s == "" else s
	if o.has_meta(field):
		var mv = o.get_meta(field)
		if mv == null:
			return fallback
		var ms := str(mv)
		return fallback if ms == "" else ms
	return fallback


func _ip_prefix_24(ip: String) -> String:
	if ip == null:
		return ""
	var parts := ip.split(".", false)
	if parts.size() < 3:
		return ""
	return "%s.%s.%s" % [parts[0], parts[1], parts[2]]


# ------------------------------------------------------------
# Rendering
# ------------------------------------------------------------
func _print_block() -> void:
	_block_base_line = screen.append_line(_header_line_0())
	screen.append_line(_header_line_1())
	screen.append_line(_header_line_2())
	screen.append_line(_header_line_3())
	screen.append_line(_header_line_4())
	screen.append_line("-".repeat(GRID_W))

	for y in range(GRID_H):
		screen.append_line(_rendered_row_string(y))


func _rerender_header_only() -> void:
	if screen == null or _block_base_line < 0:
		return
	screen.replace_line(_block_base_line + 0, _header_line_0())
	screen.replace_line(_block_base_line + 1, _header_line_1())
	screen.replace_line(_block_base_line + 2, _header_line_2())
	screen.replace_line(_block_base_line + 3, _header_line_3())
	screen.replace_line(_block_base_line + 4, _header_line_4())


func _render_grid_row(row: int) -> void:
	if screen == null or _block_base_line < 0:
		return
	if row < 0 or row >= GRID_H:
		return
	screen.replace_line(_block_base_line + HEADER_LINES + 1 + row, _rendered_row_string(row))


func _rendered_row_string(row: int) -> String:
	var base_plain := _bb_escape(_pad_to_width(_grid[row], GRID_W))
	var stamps: Array[Dictionary] = []

	for id in _tokens.keys():
		var tid := int(id)
		var t: Dictionary = _tokens[tid]
		if bool(t.get("used", false)):
			continue

		var cells: Array = t.get("cells", [])
		if cells.is_empty():
			continue

		var origin := cells[0] as Vector2i
		if origin.y != row:
			continue

		var visible_text := str(t.get("text", ""))
		var visible_len := visible_text.length()

		var hovered := (tid == _hover_token_id)
		var hinted := (tid == _hint_token_id)

		var decorated := _decorate_token(tid, t, hovered, hinted)
		stamps.append({"x": origin.x, "vis_len": visible_len, "bb": decorated})

	if row == _hover_row and _hover_token_id == -1 and _hover_col >= 0 and _hover_col < GRID_W:
		var ch := base_plain.substr(_hover_col, 1)
		var bb := "[bgcolor=#1b3a1b]%s[/bgcolor]" % ch
		stamps.append({"x": _hover_col, "vis_len": 1, "bb": bb})

	if stamps.is_empty():
		return "[color=%s]%s[/color]" % [SOUP_COLOR, base_plain]

	stamps.sort_custom(func(a, b): return int(a["x"]) < int(b["x"]))

	var out := ""
	var cursor := 0

	for st in stamps:
		var x := int(st["x"])
		var ln := int(st["vis_len"])
		var bb := str(st["bb"])

		if x < cursor:
			continue
		if x < 0 or x >= GRID_W:
			continue
		if x + ln > GRID_W:
			ln = GRID_W - x

		var seg := base_plain.substr(cursor, x - cursor)
		if seg != "":
			out += "[color=%s]%s[/color]" % [SOUP_COLOR, seg]

		out += bb
		cursor = x + ln

	var tail := base_plain.substr(cursor, GRID_W - cursor)
	if tail != "":
		out += "[color=%s]%s[/color]" % [SOUP_COLOR, tail]

	return out


func _decorate_token(_token_id: int, t: Dictionary, hovered: bool, hinted: bool) -> String:
	var kind := str(t.get("kind", ""))
	var txt := _bb_escape(str(t.get("text", "")))

	var rendered := txt
	if kind == "letter":
		rendered = "[color=%s]%s[/color]" % [TOKEN_COLOR, txt]
	elif kind == "special":
		rendered = txt

	if hinted:
		rendered = "[bgcolor=#2d5a2d]%s[/bgcolor]" % rendered
	if hovered:
		rendered = "[bgcolor=#1b3a1b]%s[/bgcolor]" % rendered

	return rendered


func _header_line_0() -> String:
	return "PASSWORD: %s" % _masked_password_string()

func _header_line_1() -> String:
	return "ATTEMPTS REMAINING: %d" % attempts_left

func _header_line_2() -> String:
	var src_host := _get_dev_field_str(source_device, "hostname", "")
	if src_host == "":
		src_host = _get_dev_field_str(source_device, "device_hostname", "")
	if src_host == "":
		src_host = _get_dev_field_str(source_device, "name", "")
	if src_host == "":
		src_host = _get_dev_field_str(source_device, "device_name", "host")

	var src_ip := _get_dev_field_str(source_device, "ip_address", "--")
	var iface := _get_dev_field_str(source_device, "iface", "wlan0")
	return "SOURCE: %s (%s)  IFACE: %s" % [src_host, src_ip, iface]

func _header_line_3() -> String:
	return "TARGET: %s  DIFFICULTY: tier-%d" % [target_ip, difficulty_tier]

func _header_line_4() -> String:
	return _status


# ------------------------------------------------------------
# Token effects
# ------------------------------------------------------------
func _click_letter_token(token_id: int, t: Dictionary) -> String:
	var letter := str(t.get("letter", ""))
	if letter == "":
		return "junk"

	var needed := _password.substr(_reveal_index, 1)

	if letter == needed:
		_wrong_streak = 0
		_tokens[token_id]["used"] = true
		_dim_token_in_grid(token_id)

		_mask[_reveal_index] = letter
		_reveal_index += 1

		_ensure_remaining_password_letters_present()

		if _reveal_index >= _password.length():
			emit_signal("crack_success")
			return "granted"
		return "correct"

	attempts_left -= 1
	_wrong_streak += 1

	var still_needed := _is_letter_needed_in_remaining_password(letter)
	if not still_needed:
		_tokens[token_id]["used"] = true
		_dim_token_in_grid(token_id)

	_ensure_remaining_password_letters_present()

	if _wrong_streak >= WRONGS_FOR_HINT and attempts_left > 0:
		_wrong_streak = 0
		_trigger_hint_for_next_letter()

	if attempts_left <= 0:
		emit_signal("crack_failed")
		return "locked"

	return "wrong"


func _click_special_token(token_id: int, t: Dictionary) -> String:
	_tokens[token_id]["used"] = true
	_dim_token_in_grid(token_id)
	_wrong_streak = 0

	var effect := str(t.get("effect", ""))
	match effect:
		"GAIN_ATTEMPT":
			attempts_left += 1
			_ensure_remaining_password_letters_present()
			return "attempt"
		"REVEAL_NEXT":
			if _reveal_index < _password.length():
				var letter := _password.substr(_reveal_index, 1)
				_mask[_reveal_index] = letter
				_reveal_index += 1

				_ensure_remaining_password_letters_present()

				if _reveal_index >= _password.length():
					emit_signal("crack_success")
					return "granted"
				return "reveal"
			_ensure_remaining_password_letters_present()
			return "waste"
		_:
			_ensure_remaining_password_letters_present()
			return "ok"


# ------------------------------------------------------------
# Hint system
# ------------------------------------------------------------
func _trigger_hint_for_next_letter() -> void:
	if _reveal_index >= _password.length():
		return

	var needed := _password.substr(_reveal_index, 1)
	var tid := _find_any_unused_letter_token_id(needed)
	if tid == -1:
		return

	_hint_token_id = tid
	var row := int((_tokens[tid].get("cells", [])[0] as Vector2i).y)
	_render_grid_row(row)

	if not _hint_timer_running:
		_hint_timer_running = true
		_hint_flash_clear_after_delay()


func _hint_flash_clear_after_delay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_hint_token_id = -1
		_hint_timer_running = false
		return

	await tree.create_timer(HINT_FLASH_SECONDS).timeout

	if not _is_generated:
		_hint_token_id = -1
		_hint_timer_running = false
		return

	if _hint_token_id != -1 and _tokens.has(_hint_token_id):
		var row := int((_tokens[_hint_token_id].get("cells", [])[0] as Vector2i).y)
		_hint_token_id = -1
		_render_grid_row(row)
	else:
		_hint_token_id = -1

	_hint_timer_running = false


func _find_any_unused_letter_token_id(letter: String) -> int:
	for id in _tokens.keys():
		var tid := int(id)
		var t: Dictionary = _tokens[tid]
		if bool(t.get("used", false)):
			continue
		if str(t.get("kind", "")) != "letter":
			continue
		if str(t.get("letter", "")) == letter:
			return tid
	return -1


# ------------------------------------------------------------
# Solvability failsafe
# ------------------------------------------------------------
func _ensure_remaining_password_letters_present() -> void:
	if _reveal_index >= _password.length():
		return

	var unused_counts: Dictionary = {}
	for id in _tokens.keys():
		var tid := int(id)
		var t: Dictionary = _tokens[tid]
		if bool(t.get("used", false)):
			continue
		if str(t.get("kind", "")) != "letter":
			continue

		var l := str(t.get("letter", ""))
		if l == "":
			continue
		unused_counts[l] = int(unused_counts.get(l, 0)) + 1

	for i in range(_reveal_index, _password.length()):
		var need := _password.substr(i, 1)
		if int(unused_counts.get(need, 0)) > 0:
			continue

		for id in _tokens.keys():
			var tid := int(id)
			var t: Dictionary = _tokens[tid]
			if not bool(t.get("used", false)):
				continue
			if str(t.get("kind", "")) != "letter":
				continue
			if str(t.get("letter", "")) != need:
				continue

			_tokens[tid]["used"] = false
			_restore_token_in_grid(tid)

			var cells: Array = _tokens[tid].get("cells", [])
			if not cells.is_empty():
				var origin := cells[0] as Vector2i
				_render_grid_row(origin.y)

			unused_counts[need] = 1
			break


# ------------------------------------------------------------
# Cursor blink loop
# ------------------------------------------------------------
func _start_cursor_blink() -> void:
	if _cursor_task_running:
		return
	_cursor_task_running = true
	_cursor_blink_loop()

func _cursor_blink_loop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_cursor_task_running = false
		return

	while _is_generated:
		_cursor_on = not _cursor_on
		_rerender_header_only()
		await tree.create_timer(0.45).timeout

	_cursor_task_running = false


# ------------------------------------------------------------
# TRACE
# ------------------------------------------------------------
func _cursor_char() -> String:
	return " █" if _cursor_on else "  "

func _trace_idle_line() -> String:
	return "TRACE: > awaiting input%s" % _cursor_char()

func _trace_line(result_key: String, input_line: String) -> String:
	var msg := ""
	match result_key:
		"junk": msg = "junk"
		"used": msg = "used"
		"bounds": msg = "out of bounds"
		"correct": msg = "correct (%d/%d)" % [_reveal_index, _password.length()]
		"wrong": msg = "wrong (attempts=%d)" % attempts_left
		"attempt": msg = "exploit +1 attempt (%d)" % attempts_left
		"reveal": msg = "memory leak reveal (%d/%d)" % [_reveal_index, _password.length()]
		"waste": msg = "exploit wasted"
		"locked": msg = "LOCKED OUT"
		"granted": msg = "ACCESS GRANTED"
		_: msg = "ok"

	return "TRACE: > %s  → %s%s" % [input_line, msg, _cursor_char()]


# ------------------------------------------------------------
# Mouse mapping
# ------------------------------------------------------------
func _mouse_to_row_col(local_pos: Vector2, output: RichTextLabel, _scroll_unused) -> Vector2i:
	if output == null:
		return INVALID_POS

	var line_h := _estimate_line_height(output)
	var char_w := _estimate_char_width(output)
	if line_h <= 0.0 or char_w <= 0.0:
		return INVALID_POS

	var left_pad := _get_rtl_left_padding(output)
	var top_pad := _get_rtl_top_padding(output)

	var x := local_pos.x - left_pad - MOUSE_X_BIAS_PX
	var y := local_pos.y - top_pad - (line_h * MOUSE_Y_BIAS_FRAC)

	var global_line := int(floor(y / line_h))
	var global_col := int(floor(x / char_w))

	var grid_start_line := HEADER_LINES + 1
	var row := global_line - grid_start_line
	var col := global_col

	if row < 0 or row >= GRID_H:
		return INVALID_POS
	if col < 0 or col >= GRID_W:
		return INVALID_POS

	return Vector2i(row, col)


func _get_rtl_left_padding(output: RichTextLabel) -> float:
	var candidates := ["margin_left", "content_margin_left", "padding_left"]
	for c in candidates:
		if output.has_theme_constant(c):
			return float(output.get_theme_constant(c))
	return 0.0

func _get_rtl_top_padding(output: RichTextLabel) -> float:
	var candidates := ["margin_top", "content_margin_top", "padding_top"]
	for c in candidates:
		if output.has_theme_constant(c):
			return float(output.get_theme_constant(c))
	return 0.0


func _estimate_line_height(output: RichTextLabel) -> float:
	var font := output.get_theme_font("normal_font")
	var font_size := output.get_theme_font_size("normal_font_size")
	if font == null:
		font = output.get_theme_default_font()
		font_size = output.get_theme_default_font_size()
	if font == null:
		return 16.0

	var base := float(font.get_height(font_size))

	var sep := 0.0
	if output.has_theme_constant("line_separation"):
		sep = float(output.get_theme_constant("line_separation"))

	var psep := 0.0
	if output.has_theme_constant("paragraph_separation"):
		psep = float(output.get_theme_constant("paragraph_separation"))

	return base + sep + psep


func _estimate_char_width(output: RichTextLabel) -> float:
	var font := output.get_theme_font("normal_font")
	var font_size := output.get_theme_font_size("normal_font_size")
	if font == null:
		font = output.get_theme_default_font()
		font_size = output.get_theme_default_font_size()
	if font == null:
		return 8.0
	return float(font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


# ------------------------------------------------------------
# Grid generation
# ------------------------------------------------------------
func _build_grid() -> void:
	_tokens.clear()
	_cell_to_token.clear()
	_grid.clear()
	_next_token_id = 1

	for y in range(GRID_H):
		var line := ""
		for x in range(GRID_W):
			line += JUNK_CHARS[_rng.randi_range(0, JUNK_CHARS.length() - 1)]
		_grid.append(line)

	var letters_to_place: Array[String] = []
	for i in range(_password.length()):
		letters_to_place.append(_password.substr(i, 1))

	var decoys := _decoy_count_for_tier(difficulty_tier)
	for i in range(decoys):
		letters_to_place.append(_random_decoy_char_not_in_password())

	var specials_to_place: Array[Dictionary] = []
	var specials := _special_count_for_tier(difficulty_tier)
	for i in range(specials):
		specials_to_place.append(SPECIAL_TOKENS[_rng.randi_range(0, SPECIAL_TOKENS.size() - 1)])

	letters_to_place.shuffle()
	specials_to_place.shuffle()

	var free3 := _gather_free_starts(3)
	free3.shuffle()

	for ch in letters_to_place:
		var placed := false
		while free3.size() > 0 and not placed:
			var pos: Vector2i = free3.pop_back()
			if _can_place_at(pos.x, pos.y, 3):
				_place_letter_token_at(ch, pos.x, pos.y)
				placed = true
		if not placed:
			_build_grid()
			return

	var free2 := _gather_free_starts(2)
	free2.shuffle()

	for sp in specials_to_place:
		var token_text := str(sp["text"])
		var effect := str(sp["effect"])
		var placed := false
		while free2.size() > 0 and not placed:
			var pos2: Vector2i = free2.pop_back()
			if _can_place_at(pos2.x, pos2.y, 2):
				_place_special_token_at(token_text, effect, pos2.x, pos2.y)
				placed = true

	for y in range(GRID_H):
		_grid[y] = _pad_to_width(_grid[y], GRID_W)


func _pad_to_width(s: String, w: int) -> String:
	if s.length() > w:
		return s.substr(0, w)
	if s.length() < w:
		return s + " ".repeat(w - s.length())
	return s


func _can_place_at(x: int, y: int, w: int) -> bool:
	for i in range(w):
		if _cell_to_token.has("%d,%d" % [x + i, y]):
			return false
	return true


func _stamp_text(x: int, y: int, text: String) -> void:
	var line := _pad_to_width(_grid[y], GRID_W)
	var before := line.substr(0, x)
	var after_start := x + text.length()
	var after := ""
	if after_start < GRID_W:
		after = line.substr(after_start, GRID_W - after_start)
	_grid[y] = before + text + after


func _place_letter_token_at(letter: String, x: int, y: int) -> void:
	var token_text := _letter_token(letter)
	var id := _new_token_id()
	var cells: Array[Vector2i] = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y)]
	_tokens[id] = {"kind":"letter","text":token_text,"cells":cells,"used":false,"letter":letter}
	_stamp_text(x, y, token_text)
	for c in cells:
		_cell_to_token["%d,%d" % [c.x, c.y]] = id


func _place_special_token_at(token_text: String, effect: String, x: int, y: int) -> void:
	var w := token_text.length()
	var id := _new_token_id()
	var cells: Array[Vector2i] = []
	for i in range(w):
		cells.append(Vector2i(x + i, y))
	_tokens[id] = {"kind":"special","text":token_text,"cells":cells,"used":false,"effect":effect}
	_stamp_text(x, y, token_text)
	for c in cells:
		_cell_to_token["%d,%d" % [c.x, c.y]] = id


func _dim_token_in_grid(token_id: int) -> void:
	if not _tokens.has(token_id):
		return
	var t: Dictionary = _tokens[token_id]
	var cells: Array = t.get("cells", [])
	for c in cells:
		var cc := c as Vector2i
		_stamp_text(cc.x, cc.y, ".")


func _restore_token_in_grid(token_id: int) -> void:
	if not _tokens.has(token_id):
		return
	var t: Dictionary = _tokens[token_id]
	var cells: Array = t.get("cells", [])
	if cells.is_empty():
		return
	var origin := cells[0] as Vector2i
	var txt := str(t.get("text", ""))
	if txt == "":
		return
	_stamp_text(origin.x, origin.y, txt)


# ------------------------------------------------------------
# Difficulty helpers
# ------------------------------------------------------------
func _tier_from_hack_chance(ch: float) -> int:
	var cl: float = clamp(ch, 0.01, 0.99)
	var t := int(floor((1.0 - cl) * 10.0)) + 1
	return clamp(t, 1, 10)

func _decoy_count_for_tier(tier: int) -> int:
	if tier <= 2: return 10
	if tier <= 4: return 8
	if tier <= 6: return 6
	if tier <= 8: return 4
	return 3

func _random_decoy_char_not_in_password() -> String:
	var pool := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for tries in range(300):
		var c := pool[_rng.randi_range(0, pool.length() - 1)]
		if _password.find(c) == -1:
			return c
	return "X"

func _special_count_for_tier(tier: int) -> int:
	if tier <= 2: return 6
	if tier <= 4: return 4
	if tier <= 6: return 3
	if tier <= 8: return 2
	if tier <= 9: return 1
	return 0

func _new_token_id() -> int:
	var id := _next_token_id
	_next_token_id += 1
	return id

func _masked_password_string() -> String:
	var out := ""
	for i in range(_mask.size()):
		out += _mask[i]
		if i < _mask.size() - 1:
			out += " "
	return out

func _get_dev_field_str(d: Object, field: String, fallback: String) -> String:
	if d == null:
		return fallback
	if field in d:
		var v = d.get(field)
		if v == null:
			return fallback
		var s := str(v)
		return fallback if s == "" else s
	if d.has_meta(field):
		var mv = d.get_meta(field)
		if mv == null:
			return fallback
		var ms := str(mv)
		return fallback if ms == "" else ms
	return fallback

func _gather_free_starts(width: int) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	for y in range(GRID_H):
		for x in range(GRID_W - width + 1):
			if _can_place_at(x, y, width):
				starts.append(Vector2i(x, y))
	return starts

func _is_letter_needed_in_remaining_password(letter: String) -> bool:
	if letter == "":
		return false
	for i in range(_reveal_index, _password.length()):
		if _password.substr(i, 1) == letter:
			return true
	return false
