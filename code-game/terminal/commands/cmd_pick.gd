extends CommandBase
class_name CmdPick

func get_name() -> String:
	return "pick"

func get_aliases() -> Array[String]:
	return []

func get_help() -> String:
	return "Pick a cell in the active hacking minigame grid."

func get_usage() -> String:
	return "pick <row> <col>"

func get_examples() -> Array[String]:
	return [
		"pick 3 44",
		"pick 0 0"
	]

func get_category() -> String:
	return "DEBUG"


func run(_args: Array[String], _terminal: Terminal) -> Array[String]:
	if _args.size() < 2:
		return ["pick: missing args. usage: " + get_usage()]

	var row := int(_args[0])
	var col := int(_args[1])

	# Find the minigame manager (autoload or root child)
	var mgr := _find_minigame_manager()
	if mgr == null:
		return ["pick: no active minigame manager found. Run 'minigame' first."]

	# Must support an API like: pick_cell(row, col) -> Array[String]
	if not mgr.has_method("pick_cell"):
		return ["pick: minigame manager has no pick_cell(row,col) method."]

	var res = mgr.call("pick_cell", row, col)
	if res == null:
		return []
	if res is Array:
		return res
	return [str(res)]


func _find_minigame_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.get_root()
	if root == null:
		return null

	# common autoload names
	for n in ["HackingMinigame", "PswdCrackingMinigame", "Minigame", "MiniGame"]:
		var node := root.get_node_or_null(n)
		if node != null:
			return node

	# fallback: any root child with pick_cell
	for child in root.get_children():
		if child != null and child.has_method("pick_cell"):
			return child

	return null
