extends SceneTree

const SELECTOR_SCENE := preload("res://scenes/lunar_landing_selector.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selector := SELECTOR_SCENE.instantiate()
	selector.set("launch_outpost_on_selection", false)
	root.add_child(selector)
	await process_frame
	_assert(selector.get("site_records").size() == 4, "The selector loads all four sourced landing sites.")
	_assert(selector.get_node_or_null("ridge_a_ClickArea") != null, "Ridge A has a clickable map location.")
	_assert(selector.is_processing_unhandled_input(), "The selector listens for mouse input while its scene is active.")
	var camera := selector.get_node("SelectorCamera") as Camera3D
	var marker := selector.get_node("ridge_a") as MeshInstance3D
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(marker.global_position)
	selector.call("_unhandled_input", click)
	_assert(selector.get("selected_site_id") == "ridge_a", "Selecting a map marker preserves its site identifier.")
	print("LunarLandingSelector tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
