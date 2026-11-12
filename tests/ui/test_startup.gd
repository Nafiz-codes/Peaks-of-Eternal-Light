extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(name_: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/startup-" + name_ + ".png")
func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event)
func run() -> void:
	root.size = Vector2i(1920, 1080)
	var boot = load("res://scenes/startup.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await create_timer(0.9).timeout
	check(boot.state == boot.State.INTRO, "Intro first")
	check(boot.credits[0].get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "Scaled credit stays centered at fullscreen resolution")
	await capture("intro")
	root.size = Vector2i(1360, 820)
	await create_timer(7.3).timeout
	check(boot.state == boot.State.MENU_IDLE, "Automatic menu entrance completes")
	var deadline := Time.get_ticks_msec() + 60000
	while not boot.ready_for_mission and not boot.load_failed and Time.get_ticks_msec() < deadline:
		await process_frame
	check(boot.ready_for_mission, "Existing Moon loaded")
	if not boot.ready_for_mission:
		quit(1)
		return
	await capture("menu")
	click(boot.buttons[1])
	check(boot.dialog.visible and boot.dialog_body.get_child_count() >= 4, "Load Game lists the three save slots")
	boot._close_dialog()
	click(boot.buttons[2])
	check(boot.dialog.visible and boot.buttons[0].disabled, "Briefing gates mission input")
	boot._start_mission()
	check(boot.state == boot.State.MENU_IDLE, "Modal blocks starts")
	boot._close_dialog()
	click(boot.buttons[3])
	check(boot.dialog_body.find_children("*", "HSlider", true, false).size() == 3, "Master, music and mission ambience controls exist")
	boot._close_dialog()
	root.size = Vector2i(960, 720)
	await process_frame
	await capture("narrow")
	root.size = Vector2i(1360, 820)
	var world = boot.world
	var moon = world.get_node("SouthPoleMap")
	var original_transform: Transform3D = moon.transform
	var original_material = moon.material_override
	click(boot.buttons[0])
	check(boot.state == boot.State.SELECTING_COMMANDER, "Start opens character selection first")
	check(not is_instance_valid(boot.opening_slideshow), "Slideshow waits for character confirmation")
	check(boot.commander_menu.busy, "Character controls wait for the menu fade")
	await create_timer(1.0).timeout
	check(not boot.commander_menu.busy and not boot.navigation.visible, "Character selection becomes interactive after the fade")
	boot.commander_menu.select_appearance("commander-02", false)
	boot.commander_menu._open_name()
	boot.commander_menu.name_input.text = "Arham"
	boot.commander_menu._validate()
	boot.commander_menu._confirm()
	await create_timer(0.7).timeout
	check(boot.state == boot.State.PLAYING_OPENING, "Start plays image opening")
	await create_timer(2.6).timeout
	var opening = boot.opening_slideshow
	check(opening.slide_index == 0, "First image opens the sequence")
	await capture("opening-first")
	var first_tween = opening.sequence
	boot._start_mission()
	check(first_tween == opening.sequence, "Repeated start ignored")
	await create_timer(7.4).timeout
	check(opening.slide_index == 1, "Armstrong image and quote follow")
	await capture("opening-armstrong")
	await create_timer(9.4).timeout
	check(opening.slide_index == 2, "Ambition image follows")
	await capture("opening-ambition")
	await create_timer(9.4).timeout
	check(opening.slide_index == 3 and not opening.shade.visible, "Title image has no added caption or shading")
	await capture("opening-title")
	deadline = Time.get_ticks_msec() + 15000
	while current_scene != world and Time.get_ticks_msec() < deadline:
		await process_frame
	check(current_scene == world, "Same world is handed off")
	check(root.get_node("MissionSession").player_character.get("appearance_id") == "commander-02", "Slideshow preserves confirmed character")
	check(moon.transform == original_transform and moon.material_override == original_material, "Original Moon preserved")
	check(world.menu_layer.visible and world.process_mode == Node.PROCESS_MODE_INHERIT, "Gameplay restored")
	check(world.navigation_controller.mode == world.navigation_controller.Mode.OVERVIEW, "Planetary overview reached")
	await capture("gameplay")
	world.queue_free()
	await process_frame
	var skipped = load("res://scenes/startup.tscn").instantiate()
	root.add_child(skipped)
	current_scene = skipped
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	await create_timer(1.5).timeout
	check(skipped.state == skipped.State.MENU_IDLE, "Escape skips smoothly")
	check(not root.get_node("GameMenu").opened, "Escape does not open pause menu")
	skipped.queue_free()
	await process_frame
	await process_frame
	print("STARTUP TEST: %d failures" % failures)
	quit(failures)
