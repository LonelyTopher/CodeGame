extends Control

@onready var output: RichTextLabel = $VBox/Scroll/Output
@onready var scroll: ScrollContainer = $VBox/Scroll
@onready var input: LineEdit = $VBox/InputRow/Input
@onready var prompt: Label = $VBox/InputRow/Prompt

var term: Terminal

func _ready() -> void:
	term = Terminal.new()
	term.load_commands_from_dir("res://terminal/commands")
	
	term.fs = FileSystem.new()
	term.cwd = "/home"
	_update_prompt()
	
	# Try load saved FS; if none exists, it stays default #
	term.fs.load_from_user()
	
	input.text_submitted.connect(_on_input_submitted)
	input.grab_focus()
	_print_line("[color=lime]Terminal ready:[/color] Type 'help' for a list of commands. . .")

func _on_input_submitted(text: String) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		call_deferred("_refocus_input")
		return

# Print the typed command #
	_print_line("[color=lime]%s%s[/color]" % [prompt.text, line])
	
# Clear and refocus input #
	input.clear()
	call_deferred("_refocus_input")

# Run the command #
	var results: Array[String] = term.execute(line)

	for r in results:
		if r == "__CLEAR__":
			output.clear()
			_print_line("Type 'help' for a list of commands. . .")
		else:
			_print_line(r)
			
	_update_prompt()

	await get_tree().process_frame
	_scroll_to_bottom()
	input.grab_focus()

func _print_line(line: String) -> void:
	output.append_text(line + "\n")

func _scroll_to_bottom() -> void:
	scroll.scroll_vertical = int(output.get_content_height())

func _refocus_input() -> void:
	input.grab_focus()

func _update_prompt() -> void:
	var display_path := term.cwd
	if display_path.begins_with("/"):
		display_path = display_path.substr(1) # remove leading "/"
		
	prompt.text = "C://" + display_path + "> "
