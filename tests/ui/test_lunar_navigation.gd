extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(name_: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/navigation-" + name_ + ".png")
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event)
func key(code: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		root.push_input(event)
func esc() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
func check_layout(world: Node, nav: Node) -> void:
	var rect := root.get_visible_rect()
	check(rect.encloses(nav.zoom_in.get_global_rect()) and rect.encloses(nav.zoom_out.get_global_rect()), "Zoom controls stay in viewport")
	check(nav.zoom_out.position.x > rect.size.x * 0.8 and nav.zoom_out.position.y < rect.size.y * 0.12, "Zoom controls are top-right")
	world._update_site_callouts()
	for callout in world.site_callouts:
		if not callout.button.visible: continue
		var coordinates: Dictionary = world._site_by_id(callout.site_id).coordinates
		var anchor: Vector3 = world._globe_position(coordinates.latitude_deg, coordinates.longitude_deg)
		check(callout.button.get_global_rect().get_center().distance_to(world.camera.unproject_position(anchor)) < 0.2, "Name is at exact geographic projection")
func run() -> void:
	root.size = Vector2i(1366, 768)
	var boot = load("res://scenes/startup.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	boot._enter_menu()
	await create_timer(1.6).timeout
	while not boot.ready_for_mission: await process_frame
	var world = boot.world
	var moon = world.get_node("SouthPoleMap")
	var material = moon.material_override
	var transform: Transform3D = moon.transform
	check(root.gui_get_focus_owner() in boot.buttons, "Main menu starts with keyboard focus")
	# While assets load, focus may start on Briefing because Start is disabled.
	for step in range(4):
		if root.gui_get_focus_owner() == boot.buttons[0]: break
		key(KEY_UP)
	check(root.gui_get_focus_owner() == boot.buttons[0], "Start is reachable after loading")
	key(KEY_UP)
	check(root.gui_get_focus_owner() == boot.buttons[3], "Up wraps main menu")
	key(KEY_DOWN)
	key(KEY_TAB)
	check(root.gui_get_focus_owner() == boot.buttons[1], "Tab navigates main menu")
	key(KEY_ENTER)
	check(boot.dialog.visible, "Enter opens briefing")
	esc()
	key(KEY_DOWN)
	check(root.gui_get_focus_owner() == boot.buttons[2], "Arrow reaches Settings")
	key(KEY_SPACE)
	check(boot.dialog.visible, "Space opens Settings")
	esc()
	key(KEY_TAB, true)
	check(root.gui_get_focus_owner() == boot.buttons[0], "Shift Tab returns to Start")
	key(KEY_ENTER)
	var nav = boot.planetary
	await create_timer(1.0).timeout
	check(nav.moon_entry > 0 and nav.moon_entry < 1 and nav.earth_entry > 0 and nav.earth_entry < 1, "Independent planet entrances overlap")
	await capture("entrance")
	await create_timer(2.0).timeout
	check(current_scene == world and nav.mode == nav.Mode.OVERVIEW, "Startup hands off to overview")
	check(nav.sidebar.visible and nav.sidebar.modulate.a > 0.99, "Sidebar remains visible")
	check(nav.sidebar_buttons.size() == 4, "Four real outposts")
	for i in range(4): check(nav.sidebar_buttons[i].text == world.site_records[i].name, "Data-driven outpost name")
	for dimensions in [Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		check_layout(world, nav)
		check(root.get_visible_rect().encloses(nav.sidebar.get_global_rect()), "Sidebar fits viewport")
		await capture("overview-%d" % dimensions.x)
	var moon_center: Vector2 = world.camera.unproject_position(Vector3.ZERO)
	check(nav.moon_hit(moon_center), "Visible Moon is target")
	var earth_position: Vector3 = nav.earth.global_position
	nav.earth.global_position = world.camera.project_position(moon_center, 28.0)
	check(not nav.moon_hit(moon_center), "Foreground Earth occludes Moon hit testing")
	nav.earth.global_position = earth_position
	check(not nav.moon_hit(Vector2(20, 20)), "Empty space is not target")
	check(not nav.moon_hit(Vector2(root.size.x * 0.71, root.size.y * 0.9)), "Earth is not Moon target")
	click(Vector2(root.size.x * 0.71, root.size.y * 0.9))
	check(nav.mode == nav.Mode.OVERVIEW, "Earth click ignored")
	click(Vector2(20, 20))
	check(nav.mode == nav.Mode.OVERVIEW, "Background click ignored")
	click(moon_center)
	check(nav.mode == nav.Mode.APPROACH, "Actual Moon click starts approach")
	var sequence = nav.sequence
	click(moon_center)
	check(sequence == nav.sequence, "Repeated input cannot restart approach")
	await create_timer(1.0).timeout
	await capture("approach")
	await create_timer(1.1).timeout
	check(nav.mode == nav.Mode.EXPLORE and world.selected_site_id.is_empty(), "Direct Moon click does not select outpost")
	check(not nav.sidebar.visible and not nav.earth.visible, "Overview removed from exploration")
	check(moon.material_override == material and moon.transform == transform, "Same Moon material and coordinates")
	for dimensions in [Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		check_layout(world, nav)
		await capture("explore-%d" % dimensions.x)
	var initial_size: float = world.camera.size
	nav.zoom_by(0.8)
	await create_timer(0.35).timeout
	check(world.camera.size < initial_size, "Smooth zoom in")
	nav.zoom_by(1.25)
	await create_timer(0.35).timeout
	check(is_equal_approx(world.camera.size, initial_size), "Smooth zoom out")
	var position: Vector3 = world.camera.position
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(20, 10)
	nav._unhandled_input(motion)
	check(not world.camera.position.is_equal_approx(position), "Orbit still works")
	if DisplayServer.get_name() != "headless":
		var old_mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await create_timer(0.8).timeout
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Actual fullscreen enabled")
		check_layout(world, nav)
		await capture("fullscreen")
		DisplayServer.window_set_mode(old_mode)
		await create_timer(0.4).timeout
	esc()
	await create_timer(2.3).timeout
	check(nav.mode == nav.Mode.OVERVIEW and nav.sidebar.visible, "Escape restores overview")
	check(not root.get_node("GameMenu").opened, "Escape does not open unrelated pause panel")
	click(world.camera.unproject_position(Vector3.ZERO))
	await create_timer(2.1).timeout
	# A left drag starting on a name must not launch a mission.
	var label: Button = world.site_callouts[0].button
	var point := label.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press)
	motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(30, 0)
	motion.relative = Vector2(30, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	press.pressed = false
	press.position = point + Vector2(30, 0)
	root.push_input(press)
	check(not world.landing_in_progress, "Dragging from a label never selects")
	# Focused geographic label retains the original landing route.
	world._update_site_callouts()
	click(label.get_global_rect().get_center())
	check(world.selected_site_id == "ridge_a" and world.landing_in_progress, "Surface name launches correct outpost")
	await create_timer(3.8).timeout
	check(current_scene != null and current_scene.name == "MissionPlanning", "Pre-landing planning entry succeeds")
	# Every sidebar choice must deploy without a second surface click.
	for index in range(4):
		change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
		await scene_changed
		world = current_scene
		nav = world.enable_cinematic_navigation()
		nav.begin_entrance()
		await create_timer(2.8).timeout
		var site: Dictionary = world.site_records[index]
		check(root.gui_get_focus_owner() == nav.sidebar_buttons[0], "Outpost menu acquires keyboard focus")
		key(KEY_UP)
		check(root.gui_get_focus_owner() == nav.sidebar_buttons[3], "Up wraps outpost options")
		key(KEY_DOWN)
		key(KEY_TAB, true)
		check(root.gui_get_focus_owner() == nav.zoom_out, "Zoom is keyboard accessible")
		key(KEY_TAB)
		check(root.gui_get_focus_owner() == nav.sidebar_buttons[0], "Tab returns to outposts")
		if index % 2 == 0:
			for step in range(index): key(KEY_DOWN)
			check(root.gui_get_focus_owner() == nav.sidebar_buttons[index], "Keyboard selects intended outpost")
			key(KEY_ENTER if index == 0 else KEY_SPACE)
		else:
			click(nav.sidebar_buttons[index].get_global_rect().get_center())
		check(nav.mode == nav.Mode.APPROACH and nav.pending_site == site.site_id, "Keyboard or mouse begins chosen deployment")
		var active_sequence = nav.sequence
		key(KEY_ENTER)
		click(nav.sidebar_buttons[(index + 1) % 4].get_global_rect().get_center())
		check(nav.sequence == active_sequence and nav.pending_site == site.site_id, "Repeated input cannot change deployment")
		await create_timer(3.55).timeout
		check(world.landing_in_progress and world.selected_site_id == site.site_id, "Focus automatically continues into landing")
		await create_timer(3.7).timeout
		check(current_scene != null and current_scene.name == "MissionPlanning", "Sidebar arrives in actual location scene")
		check(root.get_node("MissionSession").selected_site_id == site.site_id, "Actual location matches sidebar choice")
		check(root.get_camera_3d() == null, "Planning has no astronaut arrival or surface camera")
	print("LUNAR NAVIGATION TEST: %d failures" % failures)
	quit(failures)
