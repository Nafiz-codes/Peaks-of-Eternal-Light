extends RefCounted
## Explicit focus paths keep navigation independent of animation and screen layout.
static func configure(options: Array[Button], extra_controls: Array[Button] = []) -> void:
	var tab_order: Array[Button] = options.duplicate()
	tab_order.append_array(extra_controls)
	for i in range(tab_order.size()):
		var button := tab_order[i]
		button.focus_mode = Control.FOCUS_ALL
		button.focus_next = button.get_path_to(tab_order[(i + 1) % tab_order.size()])
		button.focus_previous = button.get_path_to(tab_order[posmod(i - 1, tab_order.size())])
	for group in [options, extra_controls]:
		for i in range(group.size()):
			var button: Button = group[i]
			var previous := button.get_path_to(group[posmod(i - 1, group.size())])
			var next := button.get_path_to(group[(i + 1) % group.size()])
			button.focus_neighbor_top = previous
			button.focus_neighbor_bottom = next
			button.focus_neighbor_left = previous
			button.focus_neighbor_right = next
