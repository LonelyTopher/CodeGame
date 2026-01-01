extends RefCounted
class_name Terminal

# Maps command name -> Callable (the function to run)
var commands: Dictionary = {}

func register_command(name: String, action: Callable) -> void:
	commands[name] = action
	
func execute(line: String) -> Array[String]:
	var text := line.strip_edges()
	if text.is_empty():
		return []
		
	var parts := text.split(" ", false)
	var cmd := parts[0]
	var args := parts.slice(1)
	
	if not commands.has(cmd):
		return ["Unknown command: " + cmd]
		
	var action: Callable = commands[cmd]
	# We call the function and expect it to return Array[String] #
	return action.call(args)
