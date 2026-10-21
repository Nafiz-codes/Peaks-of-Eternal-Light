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
	check(boot.ready_for_mission, "Existing Moon loaded")
	await capture("menu")
	click(boot.buttons[1])
	check(boot.dialog.visible and boot.buttons[0].disabled, "Briefing gates mission input")
	boot._start_mission()
	check(boot.state == boot.State.MENU_IDLE, "Modal blocks starts")
	boot._close_dialog()
	click(boot.buttons[2])
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
	var first_tween = boot.sequence
	boot._start_mission()
	check(first_tween == boot.sequence, "Repeated start ignored")
	await create_timer(1.2).timeout
	check(boot.astronaut_departure > 0 and boot.planetary.moon_entry > 0 and boot.planetary.moon_entry < 1, "Overlapping motion")
	await capture("exchange")
	await create_timer(2.5).timeout
	check(current_scene == world, "Same world is handed off")
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
