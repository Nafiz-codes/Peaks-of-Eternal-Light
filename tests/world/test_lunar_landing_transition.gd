extends SceneTree

const SELECTOR_SCENE := preload("res://scenes/lunar_landing_selector.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selector := SELECTOR_SCENE.instantiate()
	root.add_child(selector)
	await process_frame
	selector.call("select_site", "ridge_a")
	await process_frame
	await process_frame
	_assert(current_scene != null and current_scene.name == "LunarOutpost", "A landing-site selection opens the walkable lunar outpost.")
	var session := root.get_node_or_null("MissionSession")
	_assert(session != null and session.get("selected_site_id") == "ridge_a", "The selected site survives the scene transition.")
	print("LunarLanding transition tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
