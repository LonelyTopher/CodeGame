extends Control

# I hate this script #
# however. it gave me a hella good Dr. Frankenstein "IT'S ALIVE" feeling #

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

var saves := SaveSystem.new()
var term: Terminal
var wallet_open := false
var wallet_height_open := 120.0 # tweak after you see it
var _wallet_tween: Tween = null

const SAVE_SLOT := "save1"
const SLOT_AUTO := "autosave"
const SLOT_MANUAL := "save1"

# -------------------------------------------------
# NEW: We keep an internal copy of every printed line
# so we can replace a specific line later (progress bar).
# -------------------------------------------------
var _lines: Array[String] = []

func _ready() -> void:
	var popup := menu_btn.get_popup()

	term = Terminal.new()
	term.load_commands_from_dir("res://terminal/commands")
	term.screen = self

	# IMPORTANT:
	# World.current_device might not be ready yet depending on load order.
	# So we defer one frame to be safe.
	await get_tree().process_frame

	# Use the real device + its filesystem (DO NOT create a new FileSystem here)
	term.set_active_device(World.current_device, true)

	_update_prompt()

	input.text_submitted.connect(_on_input_submitted)
	input.grab_focus()

	_print_line("[color=lime]Terminal ready:[/color] Type 'help' for a list of commands. . .")

	# Autosave (FULL state: terminal + device + player + stats)
	if not saves.exists(SLOT_AUTO):
		saves.save_game(SLOT_AUTO, term)

	popup.clear()
	popup.add_item("Save Game", 0)
	popup.add_item("Load Save", 1)
	popup.add_item("Delete Save", 2)

	popup.id_pressed.connect(_on_menu_item_pressed)

	# ---- Wallet Function for _ready() --- #
	wallet_btn.pressed.connect(_on_wallet_pressed)

	# start closed
	wallet_panel.custom_minimum_size.y = 0
	wallet_panel.modulate.a = 0.0
	PlayerBase.currency_changed.connect(_on_currency_changed)
	_refresh_wallet()

# -------------------------------------------------
# NEW: Public API for commands to animate output
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

	# echo the command line with prompt
	_print_line("[color=lime]%s %s[/color]" % [_prompt_text(), line])

	# run the command through your Terminal
	# Godot 4: just await execute() (sync commands return immediately)
	var results: Array[String] = await term.execute(line)

	for r in results:
		if r == "__CLEAR__":
			output.clear()
			_lines.clear()
			_print_line("Type 'help' for a list of commands")
			scroll.scroll_vertical = 0
			continue
		if line.begins_with("/"):
			line = line.trim_prefix("/")

		_print_line(r)

	input.clear()
	_update_prompt()
	call_deferred("_refocus_input")

	# optional: keep the output pinned to bottom after commands
	call_deferred("_scroll_to_bottom")


# -------------------------------------------------
# OUTPUT HELPERS
# -------------------------------------------------

func _print_line(t: String) -> void:
	_lines.append(t)

	# If the line already has BBCode tags (like [color=lime]), don't wrap it.
	# Otherwise wrap in [code] so spacing is preserved like a terminal.
	if t.find("[") != -1 and t.find("]") != -1:
		output.append_text(t + "\n")
	else:
		output.append_text("[code]%s[/code]\n" % t)


func _rebuild_output_keep_scroll() -> void:
	var was_near_bottom := _is_near_bottom()

	output.clear()
	for l in _lines:
		if l.find("[") != -1 and l.find("]") != -1:
			output.append_text(l + "\n")
		else:
			output.append_text("[code]%s[/code]\n" % l)

	if was_near_bottom:
		call_deferred("_scroll_to_bottom")


	output.clear()
	for l in _lines:
		output.append_text(l + "\n")

	if was_near_bottom:
		call_deferred("_scroll_to_bottom")

func _is_near_bottom() -> bool:
	# Simple heuristic: if you're within ~40px of bottom, treat as pinned.
	var max_scroll := int(output.get_content_height())
	return (scroll.scroll_vertical >= (max_scroll - 40))

func _scroll_to_bottom() -> void:
	scroll.scroll_vertical = int(output.get_content_height())

func _refocus_input() -> void:
	input.grab_focus()

func _update_prompt() -> void:
	prompt.text = _prompt_text()

func _prompt_text() -> String:
	# Matches the look you have: C://home>
	# If you want it to show the real path formatting, tweak here.
	return "C:%s> " % term.cwd


# -------------------------------------------------
# MENU / SAVE LOAD (unchanged)
# -------------------------------------------------
func _on_save_pressed() -> void:
	if term == null:
		_print_line("[color=red]Save failed:[/color] Terminal not initialized.")
		return

	var success := saves.save_game(SLOT_MANUAL, term)

	if success:
		_print_line("[color=lime]Game saved successfully.[/color]")
	else:
		_print_line("[color=red]Save failed.[/color]")

func _on_load_pressed() -> void:
	if term == null:
		_print_line("[color=red]Load failed:[/color] Terminal not initialized.")
		return

	# Prefer manual save if it exists, otherwise fall back to autosave
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
	# Only delete the manual save slot, never delete autosave
	if not saves.exists(SLOT_MANUAL):
		_print_line("No manual save to delete.")
		return

	var ok := saves.delete(SLOT_MANUAL)
	if ok:
		_print_line("[color=lime]Deleted save:[/color] %s" % SLOT_MANUAL)
	else:
		_print_line("[color=red]Delete failed.[/color]")

func _on_menu_item_pressed(id: int) -> void:
	match id:
		0:
			_on_save_pressed()
		1:
			_on_load_pressed()
		2:
			_on_delete_pressed()

func _on_menu_pressed() -> void:
	var popup := menu_btn.get_popup()

	# Make sure popup has its final size
	popup.reset_size()
	await get_tree().process_frame  # ensures size/rect updates

	var btn_rect := menu_btn.get_global_rect()
	var popup_size := popup.size

	var popup_x := btn_rect.position.x + (btn_rect.size.x - popup_size.x) / 2.0
	var popup_y := btn_rect.position.y + btn_rect.size.y

	popup.position = Vector2(popup_x, popup_y)
	popup.popup()

# -------------------------------------------------
# Wallet Stuff
# -------------------------------------------------

func _on_wallet_pressed() -> void:
	wallet_open = not wallet_open

	# update numbers when opening
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
