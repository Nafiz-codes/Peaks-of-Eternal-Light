extends SceneTree
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0
var temporary := "res://.tools/menu_test_%d" % Time.get_ticks_usec()

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func esc() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)

func _run() -> void:
	root.size = Vector2i(1360, 820)
	DirAccess.make_dir_recursive_absolute(temporary)
	var session := root.get_node("MissionSession")
	var menu := root.get_node("GameMenu")
	var settings := root.get_node("GameSettings")
	menu.save_directory = temporary
	settings.settings_path = temporary.path_join("settings.cfg")
	var previous_settings: Dictionary = settings.values.duplicate()
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	check(session.start_selected_mission() == OK, "Mission starts.")
	await process_frame
	var player := world.get_node("Outpost/Astronaut")
	var before: Dictionary = Save.state_data(session.dashboard_state)
	var position: Vector3 = player.position
	esc()
	check(menu.opened and paused, "Esc pauses the scene and opens the menu.")
	for frame in range(3):
		await physics_frame
	check(player.position == position and Save.state_data(session.dashboard_state) == before, "Movement and mission state stay frozen while paused.")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	for frame in range(3):
		await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause menu keeps the mouse available if gameplay recaptures it.")
	for button in menu.overlay.find_children("*", "Button", true, false):
		if button.text == "Settings":
			click_at(button.get_global_rect().get_center())
	check(menu.page == "settings", "Mouse click navigates to Settings while paused.")
	for frame in range(3):
		await process_frame
	var slider: HSlider = menu.body.find_children("*", "HSlider", true, false)[0]
	var old_volume: float = settings.values.master
	click_at(slider.global_position + Vector2(slider.size.x * 0.25, slider.size.y * 0.5))
	check(not is_equal_approx(settings.values.master, old_volume), "Mouse changes the volume slider while paused.")
	click_at(menu.resume_button.get_global_rect().get_center())
	check(not menu.opened and not paused, "Mouse Resume returns to gameplay.")
	esc()
	menu.show_page("settings")
	esc()
	check(menu.opened and menu.page == "home", "Esc returns from a submenu without resuming.")
	menu.confirm("Test", "Cancel test", func(): failures += 1)
	esc()
	check(menu.page == "home" and not menu.pending_action.is_valid(), "Esc cancels destructive confirmation.")
	esc()
	check(not menu.opened and not paused, "Esc resumes from the home page.")
	for key in ["objectives", "controls", "help", "science", "settings", "saves"]:
		menu.open_menu()
		menu.show_page(key)
		check(menu.body.get_child_count() > 1, "Page renders: " + key)
		menu.close_menu()
	settings.change("sensitivity", 1.5)
	settings.change("brightness", 1.1)
	settings.change("effects", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "Effects volume controls its real audio bus.")
	check(settings.brightness_rect.visible, "Brightness screen adjustment is active.")
	var config := ConfigFile.new()
	check(config.load(settings.settings_path) == OK and config.get_value("settings", "sensitivity") == 1.5, "Settings persist on disk.")
	settings.values = previous_settings
	settings.apply()
	# Save a mission with a pending decision; its resolution and future events must survive.
	if session.dashboard_state.pending_events.is_empty():
		session.dashboard_state.pending_events.append(session.dashboard_simulator.events[1].duplicate(true))
		session.state_changed.emit()
		session.capture_sol_checkpoint()
		await process_frame
	before = Save.state_data(session.dashboard_state)
	var slot: String = menu.slot_path(1)
	check(session.save_slot(slot) == OK, "Full mission saves successfully.")
	check(session.save_slot(slot) == OK, "Existing save can be atomically overwritten.")
	var saved := Save.read_file(slot)
	check(saved.state == before, "Save includes every state property, including history and triggered IDs.")
	if not session.dashboard_state.pending_events.is_empty():
		var event: Dictionary = session.dashboard_state.pending_events[0]
		check(session.resolve_decision(event.event_id, event.choices[0].choice_id).get("ok", false), "Pending decision resolves.")
		check(session.restart_current_sol() == OK and Save.state_data(session.dashboard_state) == before, "Restart current sol restores its unresolved decisions and resource state.")
	session.dashboard_state.power_kwh = 1.0
	check(session.load_slot(slot) == OK and Save.state_data(session.dashboard_state) == before, "Load restores the whole mission, not only resource meters.")
	var clone: Dictionary = Save.decode(saved)
	while not session.dashboard_state.pending_events.is_empty():
		var event: Dictionary = session.dashboard_state.pending_events[0]
		var choice: String = event.choices[0].choice_id
		session.resolve_decision(event.event_id, choice)
		clone.simulator.resolve_event_choice(clone.state, event.event_id, choice)
	session.advance_mission()
	clone.simulator.advance_sol(clone.state)
	check(Save.state_data(session.dashboard_state) == Save.state_data(clone.state), "Loaded mission produces identical future outcomes.")
	await process_frame
	var invalid := saved.duplicate(true)
	invalid.state.erase("triggered_event_ids")
	var corrupt := temporary.path_join("corrupt.save")
	Save.write_file(corrupt, invalid)
	before = Save.state_data(session.dashboard_state)
	check(session.load_slot(corrupt) == ERR_INVALID_DATA and Save.state_data(session.dashboard_state) == before, "Incomplete saves are rejected without touching current progress.")
	menu.open_menu()
	menu._load(1)
	await scene_changed
	check(not paused and not menu.opened and current_scene.scene_file_path == "res://scenes/lunar_outpost_3d.tscn", "Loading exits pause and opens the restored outpost.")
	check(Save.state_data(session.dashboard_state) == saved.state, "Scene reload keeps saved mission data intact.")
	menu.open_menu()
	menu._restart_mission()
	await scene_changed
	check(session.dashboard_state.sol == 0 and session.dashboard_state.resolved_events.is_empty(), "Restart mission returns to a fresh Sol 0.")
	var sites: Array = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json")).sites
	for site in sites:
		if site.site_id == session.selected_site_id:
			continue
		menu.open_menu()
		menu.show_page("outposts")
		var travel_button: Button
		for label in menu.body.find_children("*", "Label", true, false):
			if label.text == site.name:
				travel_button = label.get_parent().get_child(1)
		check(travel_button != null, "Outpost destination has a travel button.")
		var original_site: String = session.selected_site_id
		travel_button.pressed.emit()
		check(menu.page == "confirm" and session.selected_site_id == original_site, "Travel waits for confirmation.")
		esc()
		check(menu.page == "outposts" and session.selected_site_id == original_site, "Cancel travel keeps the current outpost.")
		menu._travel_to_outpost(site.site_id)
		await scene_changed
		await process_frame
		check(session.selected_site_id == site.site_id and not paused and not menu.opened, "Travel reaches the requested outpost and resumes gameplay.")
		check(current_scene.scene_file_path == "res://scenes/lunar_outpost_3d.tscn" and current_scene.has_node("Outpost/Astronaut"), "Travel creates the playable outpost.")
		check(session.dashboard_state == null and session.sol_checkpoint.is_empty(), "Travel does not carry another outpost's mission into the destination.")
	check(Save.read_file(slot).state == saved.state, "Outpost travel preserves saved slots.")
	menu.open_menu()
	menu._landing()
	await scene_changed
	check(not paused and current_scene.scene_file_path == "res://scenes/lunar_landing_selector.tscn", "Return to landing selection unpauses safely.")
	esc()
	check(menu.opened, "Esc also opens the menu at landing selection.")
	esc()
	for file in ["mission_slot_1.save", "corrupt.save", "settings.cfg"]:
		DirAccess.remove_absolute(temporary.path_join(file))
	DirAccess.remove_absolute(temporary)
	print("Game menu and persistence: %d failures." % failures)
	quit(1 if failures else 0)
