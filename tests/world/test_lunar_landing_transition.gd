extends SceneTree

const SELECTOR_SCENE := preload("res://scenes/lunar_landing_selector.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selector := SELECTOR_SCENE.instantiate()
	root.add_child(selector)
	current_scene = selector
	await process_frame
	var camera := selector.get_node("SelectorCamera") as Camera3D
	var initial_size := camera.size
	selector.call("select_site", "ridge_a")
	selector.call("select_site", "crater_rim")
	_assert(selector.get("selected_site_id") == "ridge_a", "Repeated clicks cannot change the destination during landing.")
	await create_timer(0.9).timeout
	_assert(current_scene == selector and camera.size < initial_size, "The map zooms before switching scenes.")
	var locked_size := camera.size
	selector.call("_zoom_by", 1.25)
	_assert(camera.size == locked_size, "Manual zoom cannot interrupt landing.")
	await create_timer(1.3).timeout
	_assert(current_scene != null and current_scene.name == "LunarOutpost", "A landing-site selection opens the walkable lunar outpost.")
	var session := root.get_node_or_null("MissionSession")
	_assert(session != null and session.get("selected_site_id") == "ridge_a", "The selected site survives the scene transition.")
	await create_timer(1.4).timeout
	_assert(root.get_viewport().get_camera_3d().name == "ThirdPersonCamera", "Arrival returns control to the gameplay camera.")
	_assert(current_scene.get_node("Outpost/Astronaut").process_mode == Node.PROCESS_MODE_INHERIT, "Player control is restored after arrival.")
	print("LunarLanding transition tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
