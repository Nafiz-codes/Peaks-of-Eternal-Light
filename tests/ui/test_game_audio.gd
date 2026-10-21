extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = Vector2(100, 30)
	root.push_input(event)
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event)
func run() -> void:
	var audio := root.get_node("GameAudio")
	var scene := Control.new()
	root.add_child(scene)
	current_scene = scene
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(200, 60)
	button.text = "Dynamic test button"
	scene.add_child(button)
	await process_frame
	await process_frame
	check(audio.hover_count == 0, "Creating UI does not trigger hover")
	motion(Vector2(150, 125))
	await process_frame
	await process_frame
	check(audio.hover_count == 1, "Actual mouse enter triggers one hover")
	motion(Vector2(155, 126))
	await process_frame
	check(audio.hover_count == 1, "Motion inside same button stays quiet")
	check(audio.hover_pitch(0) < 1.0 and audio.hover_pitch(1800) > 1.0 and audio.hover_pitch(99999) <= 1.14, "Hover pitch is bounded and speed responsive")
	var count: int = audio.click_count
	click(Vector2(150, 125))
	check(audio.click_count == count + 1, "Mouse activation triggers one click")
	await process_frame
	button.grab_focus()
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key)
	check(audio.click_count == count + 2, "Keyboard activation triggers same click")
	await process_frame
	button.disabled = true
	click(Vector2(150, 125))
	check(audio.click_count == count + 2, "Disabled button stays silent")
	motion(Vector2(20, 20))
	await process_frame
	motion(Vector2(150, 125))
	await process_frame
	check(audio.hover_count == 1, "Disabled hover suppressed")
	button.disabled = false
	var cover := ColorRect.new()
	cover.position = button.position
	cover.size = button.size
	scene.add_child(cover)
	motion(Vector2(20, 20))
	await process_frame
	motion(Vector2(150, 125))
	await process_frame
	check(audio.hover_count == 1, "Obscured button hover suppressed")
	click(Vector2(20, 20))
	check(audio.click_count == count + 2, "Empty space has no click")
	cover.queue_free()
	await process_frame
	paused = true
	click(Vector2(150, 125))
	# Typical pause UI has ALWAYS mode, just like the existing GameMenu.
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	await process_frame
	click(Vector2(150, 125))
	check(audio.click_player.playing, "UI audio is available while paused")
	paused = false
	change_scene_to_file("res://scenes/lunar_outpost_3d.tscn")
	await scene_changed
	check(audio.click_player.is_inside_tree(), "Click player survives scene changes")
	var world := current_scene
	var access := world.get_node("LanderAccess")
	var astronaut := world.get_node("Outpost/Astronaut")
	astronaut.global_position = access.landing
	await process_frame
	access.transfer()
	await create_timer(2.1).timeout
	var driver := world.get_node("RoverHull")
	check(driver.start_control(), "Rover control begins from seat")
	await process_frame
	driver.set_physics_process(false)
	var position: Vector3 = driver.position
	driver.step_drive(0.016, 1, 0, false)
	check(driver.power_state == driver.Power.STARTING and driver.position == position, "Takeover holds rover stationary")
	var starts: int = audio.startup_count
	driver.step_drive(0.016, 1, 0, false)
	check(audio.startup_count == starts, "Held input does not restart startup")
	paused = true
	await create_timer(0.15).timeout
	check(driver.power_state == driver.Power.STARTING, "Pause cannot advance rover readiness")
	paused = false
	driver.stop_control()
	check(not audio.rover_player.playing and driver.power_state == driver.Power.INACTIVE, "Exit cancels startup")
	check(driver.start_control(), "Reentry permits a new startup")
	driver.step_drive(0.016, 1, 0, false)
	check(audio.startup_count == starts + 1, "Reentry starts exactly once")
	await create_timer(audio.rover_player.stream.get_length() + 0.2).timeout
	check(driver.power_state == driver.Power.READY, "Actual sound completion unlocks rover")
	driver.step_drive(0.016, 0, 0, false)
	check(is_zero_approx(driver.speed), "Released input never forces movement")
	for frame in range(60):
		await physics_frame
		driver.step_drive(1.0 / 60, 1, 0, false)
	check(driver.speed > 0 and audio.startup_count == starts + 1, "Existing acceleration runs without replay")
	driver.stop_control()
	print("GAME AUDIO TEST: %d failures" % failures)
	quit(failures)
