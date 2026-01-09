extends Control

@onready var output: RichTextLabel = $VBox/Scroll/ScrollContent/Output
@onready var prompt: Label = $VBox/InputRow/Prompt
@onready var input: LineEdit = $VBox/InputRow/Input
@onready var scroll: ScrollContainer = $VBox/Scroll
@onready var menu_btn: MenuButton = $SideBar/ScrollContainer/VBoxContainer/MenuBtn
@onready var wallet_btn: Button = $SideBar/ScrollContainer/VBoxContainer/WalletBtn
@onready var wallet_panel: PanelContainer = $SideBar/ScrollContainer/VBoxContainer/WalletPanel
@onready var usd_value: Label = $"SideBar/ScrollContainer/VBoxContainer/WalletPanel/MarginContainer/VBoxContainer/USD row/UsdValue"
@onready var btc_value: Label = $"SideBar/ScrollContainer/VBoxContainer/WalletPanel/MarginContainer/VBoxContainer/BTC row/BTC value"
@onready var eth_value: Label = $"SideBar/ScrollContainer/VBoxContainer/WalletPanel/MarginContainer/VBoxContainer/ETH row/ETH value"

# --- MINIGAME WINDOW @ONREADYS --- #

@onready var modal_layer: CanvasLayer = $ModalLayer
@onready var modal_window: PanelContainer = $ModalLayer/ModalWindow
@onready var modal_text: RichTextLabel = $ModalLayer/ModalWindow/MarginContainer/VBoxContainer/ModalText
@onready var modal_host: Control = $ModalLayer/ModalWindow/MarginContainer/VBoxContainer/ModalHost

var _modal_overlay: PswdCrackOverlay = null





var saves := SaveSystem.new()
var term: Terminal

var wallet_open := false
var wallet_height_open := 120.0
var _wallet_tween: Tween = null

const SLOT_AUTO := "autosave"
const SLOT_MANUAL := "save1"

# Output bookkeeping
var _lines: Array[String] = []

# Modal
var _modal_handler: Object = null
var _modal_lock_prompt: bool = true
var _overlay: PswdCrackOverlay = null
const OVERLAY_SCENE := preload("res://Systems/HackingMinigame/PswdCrackOverlay.tscn")

# wheel tuning
const WHEEL_STEP := 90


func _ready() -> void:
	var popup := menu_btn.get_popup()

	term = Terminal.new()
	term.load_commands_from_dir("res://terminal/commands")
	term.screen = self

	await _wait_for_world_device()
	term.set_active_device(World.current_device, true)

	output.bbcode_enabled = true
	output.autowrap_mode = TextServer.AUTOWRAP_OFF
	output.fit_content = false
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if World != null and World.has_signal("current_device_changed"):
		if not World.current_device_changed.is_connected(_on_current_device_changed):
			World.current_device_changed.connect(_on_current_device_changed)

	_update_prompt()

	output.focus_mode = Control.FOCUS_CLICK
	scroll.focus_mode = Control.FOCUS_CLICK
	_remove_focus_outline(output)
	_remove_focus_outline(scroll)

	# Non-modal scrolling only: keep wheel working on output
	output.mouse_filter = Control.MOUSE_FILTER_STOP
	if not output.gui_input.is_connected(_on_output_gui_input):
		output.gui_input.connect(_on_output_gui_input)

	input.text_submitted.connect(_on_input_submitted)
	input.grab_focus()

	_print_line("[color=lime]Terminal ready:[/color] Type 'help' for a list of commands. . .")

	if not saves.exists(SLOT_AUTO):
		saves.save_game(SLOT_AUTO, term)

	popup.clear()
	popup.add_item("Save Game", 0)
	popup.add_item("Load Save", 1)
	popup.add_item("Delete Save", 2)
	popup.id_pressed.connect(_on_menu_item_pressed)

	wallet_btn.pressed.connect(_on_wallet_pressed)

	wallet_panel.custom_minimum_size.y = 0
	wallet_panel.modulate.a = 0.0
	PlayerBase.currency_changed.connect(_on_currency_changed)
	_refresh_wallet()


# -------------------------------------------------
# Output mouse handler (ONLY for wheel scrolling now)
# -------------------------------------------------
func _on_output_gui_input(event: InputEvent) -> void:
	if _modal_handler != null:
		# Modal active => overlay owns the mouse; ignore output events
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var delta := -WHEEL_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else WHEEL_STEP
			scroll.scroll_vertical = max(scroll.scroll_vertical + delta, 0)
			accept_event()
			return


# -------------------------------------------------
# Device readiness + syncing
# -------------------------------------------------
func _wait_for_world_device() -> void:
	for i in range(240):
		if World != null and World.current_device != null and World.current_device.fs != null:
			return
		await get_tree().process_frame
	_print_line("[color=red]Fatal:[/color] World.current_device not ready. Check WorldNetwork autoload and LAN scripts.")

func _on_current_device_changed(dev: Device) -> void:
	if dev == null:
		return
	term.set_active_device(dev, false)
	_update_prompt()


# -------------------------------------------------
# Public API for commands/minigames
# -------------------------------------------------
func append_line(text: String) -> int:
	_print_line(text)
	return _lines.size() - 1

func replace_last_line(new_text: String) -> void:
	if _lines.is_empty():
		_print_line(new_text)
		return
	_lines[_lines.size() - 1] = new_text
	_rebuild_output_keep_scroll()

func replace_line(index: int, new_text: String) -> void:
	if index < 0 or index >= _lines.size():
		return
	_lines[index] = new_text
	_rebuild_output_keep_scroll()


# -------------------------------------------------
# INPUT / COMMAND EXECUTION
# -------------------------------------------------
func _on_input_submitted(text: String) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		call_deferred("_refocus_input")
		return

	# MODAL MODE: route to minigame
	if _modal_handler != null and _modal_handler.has_method("handle_terminal_line"):
		var consumed: bool = bool(_modal_handler.call("handle_terminal_line", line))
		input.clear()
		call_deferred("_refocus_input")
		if consumed:
			return

	# NORMAL TERMINAL MODE
	_print_line("[color=lime]%s %s[/color]" % [_prompt_text(), line])

	# ✅ clear immediately so async commands don't leave text sitting there
	input.clear()
	call_deferred("_refocus_input")

	var results: Array[String] = await term.execute(line)

	for r in results:
		if r == "__CLEAR__":
			output.clear()
			_lines.clear()
			_print_line("Type 'help' for a list of commands")
			scroll.scroll_vertical = 0
			continue
		_print_line(r)

	_update_prompt()
	call_deferred("_scroll_to_bottom")

# -------------------------------------------------
# OUTPUT HELPERS
# -------------------------------------------------
func _print_line(t: String) -> void:
	_lines.append(t)
	output.append_text(t + "\n")

func _rebuild_output_keep_scroll() -> void:
	var was_near_bottom := _is_near_bottom()
	output.clear()
	for l in _lines:
		output.append_text(l + "\n")
	if was_near_bottom:
		call_deferred("_scroll_to_bottom")

func _is_near_bottom() -> bool:
	var sb := scroll.get_v_scroll_bar()
	if sb == null:
		return true
	return scroll.scroll_vertical >= int(sb.max_value - 40.0)

func _scroll_to_bottom() -> void:
	var sb := scroll.get_v_scroll_bar()
	if sb == null:
		return
	scroll.scroll_vertical = int(sb.max_value)

func _refocus_input() -> void:
	input.grab_focus()

func _update_prompt() -> void:
	prompt.text = _prompt_text()

func _prompt_text() -> String:
	return "C:%s> " % term.cwd


# -------------------------------------------------
# Modal API (called by minigame)
# Returns overlay "screen" so minigame can print into it
# -------------------------------------------------

func set_modal(handler: Object, lock_prompt: bool = true) -> Object:
	_modal_handler = handler
	_modal_lock_prompt = lock_prompt

	# Remove old overlay if any
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

	# Instantiate overlay AS PswdCrackOverlay (not Control)
	_overlay = OVERLAY_SCENE.instantiate() as PswdCrackOverlay
	if _overlay == null:
		push_error("Overlay scene root must be PswdCrackOverlay (extends Control).")
		return null

	var layer := $VBox/OverlayLayer as Control
	if layer == null:
		push_error("Missing VBox/OverlayLayer. Add a Control named OverlayLayer under VBox.")
		return null

	layer.add_child(_overlay)
	_overlay.z_index = 999
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.focus_mode = Control.FOCUS_NONE

	# IMPORTANT: let the overlay own input routing
	_overlay.setup(handler)


	_position_overlay_to_output()
	call_deferred("_position_overlay_to_output")

	# RETURN overlay so minigame prints into it
	return _overlay

func clear_modal() -> void:
	_modal_handler = null
	_modal_lock_prompt = true

	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _position_overlay_to_output() -> void:
	if _overlay == null or output == null:
		return

	var layer := $VBox/OverlayLayer as Control
	if layer == null:
		return

	# Get Output's global rect
	var out_rect: Rect2 = output.get_global_rect()

	# Convert global -> layer local using screen transforms (works for Controls)
	var layer_inv := layer.get_screen_transform().affine_inverse()
	var local_pos: Vector2 = layer_inv * out_rect.position

	_overlay.position = local_pos
	_overlay.size = out_rect.size

func is_modal_active() -> bool:
	return _modal_handler != null


# -------------------------------------------------
# Menu / Wallet / Helpers unchanged
# -------------------------------------------------
func _on_save_pressed() -> void:
	if term == null:
		_print_line("[color=red]Save failed:[/color] Terminal not initialized.")
		return
	var success := saves.save_game(SLOT_MANUAL, term)
	_print_line("[color=lime]Game saved successfully.[/color]" if success else "[color=red]Save failed.[/color]")

func _on_load_pressed() -> void:
	if term == null:
		_print_line("[color=red]Load failed:[/color] Terminal not initialized.")
		return

	var slot := SLOT_MANUAL if saves.exists(SLOT_MANUAL) else SLOT_AUTO
	if not saves.exists(slot):
		_print_line("[color=red]Load failed:[/color] Save not found.")
		return

	var ok := saves.load_game(slot, term)
	if not ok:
		_print_line("[color=red]Load failed:[/color] Save data invalid/corrupted.")
		return

	_print_line("[color=lime]Loaded:[/color] %s" % slot)
	_update_prompt()
	call_deferred("_refocus_input")

func _on_delete_pressed() -> void:
	if not saves.exists(SLOT_MANUAL):
		_print_line("No manual save to delete.")
		return
	var ok := saves.delete(SLOT_MANUAL)
	_print_line("[color=lime]Deleted save:[/color] %s" % SLOT_MANUAL if ok else "[color=red]Delete failed.[/color]")

func _on_menu_item_pressed(id: int) -> void:
	match id:
		0: _on_save_pressed()
		1: _on_load_pressed()
		2: _on_delete_pressed()

func _on_wallet_pressed() -> void:
	wallet_open = not wallet_open
	if wallet_open:
		_refresh_wallet()
	_animate_wallet(wallet_open)

func _animate_wallet(open: bool) -> void:
	if _wallet_tween != null and _wallet_tween.is_running():
		_wallet_tween.kill()
	_wallet_tween = create_tween()
	_wallet_tween.set_trans(Tween.TRANS_QUAD)
	_wallet_tween.set_ease(Tween.EASE_OUT)

	var target_h := wallet_height_open if open else 0.0
	var target_a := 1.0 if open else 0.0
	_wallet_tween.tween_property(wallet_panel, "custom_minimum_size:y", target_h, 0.18)
	_wallet_tween.parallel().tween_property(wallet_panel, "modulate:a", target_a, 0.12)

func _refresh_wallet() -> void:
	usd_value.text = "USD: $%.2f" % PlayerBase.get_currency(PlayerBase.Currency.DOLLARS)
	btc_value.text = "BTC:  %.6f" % PlayerBase.get_currency(PlayerBase.Currency.BITCOIN)
	eth_value.text = "ETH:  %.6f" % PlayerBase.get_currency(PlayerBase.Currency.ETHEREUM)

func _on_currency_changed(_type: int, _new_amount: float) -> void:
	if wallet_open:
		_refresh_wallet()

func _remove_focus_outline(c: Control) -> void:
	var empty := StyleBoxEmpty.new()
	c.add_theme_stylebox_override("focus", empty)
	c.add_theme_stylebox_override("focus_border", empty)

func _on_overlay_gui_input(event: InputEvent) -> void:
	# If no modal, ignore overlay input (shouldn't exist anyway)
	if _modal_handler == null:
		return

	# Use overlay-local mouse position (this is the whole point)
	var local_pos := _overlay.get_local_mouse_position()

	# Hover
	if event is InputEventMouseMotion:
		if _modal_handler.has_method("handle_mouse_move"):
			_modal_handler.call("handle_mouse_move", local_pos, output, scroll)
		accept_event()
		return

	# Click
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# lock wheel while modal
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			return

		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _modal_handler.has_method("handle_mouse_click"):
				var consumed := bool(_modal_handler.call("handle_mouse_click", local_pos, output, scroll))
				if consumed:
					call_deferred("_refocus_input")
			accept_event()
			return

# --- Minigame Separate Window Functions --- #

func open_modal_window(handler: Object) -> PswdCrackOverlay:
	_modal_handler = handler
	_modal_lock_prompt = true

	modal_layer.visible = true
	modal_window.visible = true

	# Clear anything already inside ModalHost
	for child in modal_host.get_children():
		child.queue_free()

	# Spawn overlay
	_modal_overlay = OVERLAY_SCENE.instantiate() as PswdCrackOverlay
	if _modal_overlay == null:
		push_error("Overlay scene root must be PswdCrackOverlay.")
		return null

	modal_host.add_child(_modal_overlay)

	# Make overlay fill ModalHost
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.offset_left = 0
	_modal_overlay.offset_top = 0
	_modal_overlay.offset_right = 0
	_modal_overlay.offset_bottom = 0
	_modal_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_modal_overlay.setup(handler)

	# IMPORTANT: size the modal window to fit 125 cols + all lines
	_size_modal_for_grid(125, 5 + 1 + 25 + 2) # header(5) + dashed(1) + grid(25) + footer/help(2)

	return _modal_overlay


func _size_modal_for_grid(cols: int, lines: int) -> void:
	# Get font metrics from the overlay's RichTextLabel
	if _modal_overlay == null or _modal_overlay.text == null:
		return

	var rt := _modal_overlay.text
	var font := rt.get_theme_font("normal_font")
	var font_size := rt.get_theme_font_size("normal_font_size")
	if font == null:
		font = rt.get_theme_default_font()
		font_size = rt.get_theme_default_font_size()

	# Fallbacks
	if font == null:
		font_size = 16

	var char_w := 9.0
	var line_h := 18.0
	if font != null:
		char_w = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		line_h = font.get_height(font_size)

	# Add some padding from your containers/panel
	var pad_x := 40.0
	var pad_y := 40.0

	var desired := Vector2(cols * char_w + pad_x, lines * line_h + pad_y)

	# Clamp so it never goes off screen
	var vp := get_viewport_rect().size
	desired.x = min(desired.x, vp.x * 0.95)
	desired.y = min(desired.y, vp.y * 0.90)

	modal_window.size = desired
	modal_window.position = (vp - desired) * 0.5




func close_modal_window() -> void:
	_modal_handler = null
	_modal_lock_prompt = true

	if _modal_overlay != null:
		_modal_overlay.queue_free()
		_modal_overlay = null

	modal_window.visible = false
	modal_layer.visible = false

func _on_modal_window_gui_input(event: InputEvent) -> void:
	if _modal_handler == null or _modal_overlay == null:
		return

	# Convert mouse to OVERLAY local position (not modal_window local)
	var mouse_global := get_global_mouse_position()
	var overlay_local: Vector2 = _modal_overlay.get_global_transform_with_canvas().affine_inverse() * mouse_global

	if event is InputEventMouseMotion:
		if _modal_handler.has_method("handle_mouse_move"):
			_modal_handler.call("handle_mouse_move", overlay_local, _modal_overlay.text, null)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _modal_handler.has_method("handle_mouse_click"):
				_modal_handler.call("handle_mouse_click", overlay_local, _modal_overlay.text, null)
			accept_event()
			return
