extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	check(session.start_selected_mission() == OK, "Mission starts.")
	var state: Variant = session.dashboard_state
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	var player := world.get_node("Outpost/Astronaut")
	player.position = Vector3(6.5, 0.0, 5)
	player.camera_yaw = 0.5
	var position: Vector3 = player.position
	session.open_dashboard(world.scene_file_path)
	await scene_changed
	check(current_scene.state == state, "Dashboard resumes the world state.")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dashboard releases the mouse.")
	session.return_to_game()
	await scene_changed
	check(current_scene.get_node("Outpost/Astronaut").position.is_equal_approx(position), "Returning restores the astronaut's location.")
	check(is_equal_approx(current_scene.get_node("Outpost/Astronaut").camera_yaw, 0.5), "Returning restores camera heading.")
	# Test a valid short mission to exercise the success UI independently of balance.
	session.dashboard_state = session.dashboard_simulator.begin_mission("ridge_a", 1)
	session.state_changed.emit()
	session.advance_mission()
	await process_frame
	check(session.dashboard_state.mission_outcome.status == "success", "Short mission succeeds through the simulator.")
	check(current_scene.get_node("MissionHUD").run_button.disabled, "Success disables turn controls.")
	session.open_dashboard(current_scene.scene_file_path)
	await scene_changed
	check(current_scene.screen == "report", "Successful mission opens its report.")
	current_scene.reset_mission()
	current_scene.select_site("crater_rim_b")
	current_scene.start_mission()
	session.return_to_game()
	await scene_changed
	check(current_scene.site_record.site_id == "crater_rim_b" and session.dashboard_state.site_id == "crater_rim_b", "Dashboard site change reaches the matching 3D scene.")
	session.reduce_motion = true
	change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
	await scene_changed
	current_scene.select_site("plateau_d")
	await scene_changed
	check(current_scene.name == "LunarOutpost" and current_scene.get_node("Outpost/Astronaut").process_mode == Node.PROCESS_MODE_INHERIT, "Reduced-motion landing reaches an immediately playable outpost.")
	print("Outpost navigation: %d failures; scene return, pose, success report, restart and site change checked." % failures)
	quit(1 if failures else 0)

