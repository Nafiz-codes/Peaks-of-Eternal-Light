extends SceneTree

const DashboardScene = preload("res://scenes/mission_dashboard.tscn")


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var dashboard: Control = DashboardScene.instantiate()
	root.add_child(dashboard)
	await process_frame
	var labels := PackedStringArray()
	var buttons: Array[Button] = []
	_collect(dashboard, labels, buttons)
	for required in ["Peaks of Eternal Light", "by TRIARCHY", "SOL 00 / 10", "ENERGY RESERVE", "WATER", "OXYGEN", "FOOD", "ACCUMULATED DOSE", "MATERIALS", "Names pending · live health unavailable", "SITE DATA UNVERIFIED     ·     PRESENTATION PREVIEW"]:
		if not labels.has(required):
			push_error("Missing dashboard label: " + required)
			quit(1)
			return
	if buttons.size() != 3:
		push_error("Expected exactly three planned action buttons")
		quit(1)
		return
	for button in buttons:
		if not button.disabled:
			push_error("A planned action is enabled: " + button.text)
			quit(1)
			return
	print("Mission dashboard shell tests passed.")
	quit(0)


func _collect(node: Node, labels: PackedStringArray, buttons: Array[Button]) -> void:
	if node is Label:
		labels.append(node.text)
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		_collect(child, labels, buttons)
