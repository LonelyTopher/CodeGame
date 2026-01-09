extends Control
class_name PswdCrackOverlay

@onready var text: RichTextLabel = $Text

var _lines: Array[String] = []
var _handler: Object = null

func setup(handler: Object) -> void:
	_handler = handler
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Make overlay fill its parent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# RichTextLabel behavior
	text.bbcode_enabled = true
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.fit_content = false
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# IMPORTANT: stop the "spread out across the whole line" look
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.justification_flags = 0  # <- disables Word/Kashida justification

	# Default soup color (regular terminal green, NOT lime)
	# Tokens you wrap in [color=lime] will still pop.
	text.add_theme_color_override("default_color", Color(0.0, 0.75, 0.0))

	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()

func append_line(t: String) -> int:
	_lines.append(t)
	_rebuild()
	return _lines.size() - 1

func replace_line(index: int, t: String) -> void:
	if index < 0 or index >= _lines.size():
		return
	_lines[index] = t
	_rebuild()

func replace_last_line(t: String) -> void:
	if _lines.is_empty():
		append_line(t)
		return
	_lines[_lines.size() - 1] = t
	_rebuild()

func clear_all() -> void:
	_lines.clear()
	_rebuild()

func _rebuild() -> void:
	if text == null:
		return
	text.clear()
	for l in _lines:
		text.append_text(l + "\n")

func _gui_input(event: InputEvent) -> void:
	if _handler == null:
		return

	# Lock wheel while overlay is up (prevents scroll desync)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			return

	var local_pos := get_local_mouse_position()

	if event is InputEventMouseMotion:
		if _handler.has_method("handle_mouse_move"):
			_handler.call("handle_mouse_move", local_pos, text, null)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mb2 := event as InputEventMouseButton
		if mb2.pressed and mb2.button_index == MOUSE_BUTTON_LEFT:
			if _handler.has_method("handle_mouse_click"):
				_handler.call("handle_mouse_click", local_pos, text, null)
			accept_event()
			return
