extends Node
## Uppercase presentation for existing and dynamically created game UI.
var controls: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	get_tree().node_added.connect(_track)
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	_track(node)
	for child in node.get_children():
		_scan(child)

func _track(node: Node) -> void:
	if node is Label or node is Label3D:
		node.uppercase = true
	if node is Control or node is PopupMenu:
		controls[node.get_instance_id()] = weakref(node)

func _process(_delta: float) -> void:
	for id in controls.keys():
		var node: Node = controls[id].get_ref()
		if not is_instance_valid(node):
			controls.erase(id)
			continue
		if node is Control:
			var tip: String = node.tooltip_text.to_upper()
			if node.tooltip_text != tip:
				node.tooltip_text = tip
		if node is Label:
			node.uppercase = true
		elif node is OptionButton or node is PopupMenu:
			for index in range(node.item_count):
				var caption: String = node.get_item_text(index)
				if caption != caption.to_upper():
					node.set_item_text(index, caption.to_upper())
		elif node is Button:
			if node.text != node.text.to_upper():
				node.text = node.text.to_upper()
		elif node is LineEdit:
			node.placeholder_text = node.placeholder_text.to_upper()
			if node.text != node.text.to_upper() and not node.has_ime_text():
				var caret: int = node.caret_column
				node.text = node.text.to_upper()
				node.caret_column = caret
