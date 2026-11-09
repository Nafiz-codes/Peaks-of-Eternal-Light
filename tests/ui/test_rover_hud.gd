extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func key(held: bool):
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	root.size = Vector2i(1360, 820)
	var session = root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await process_frame
	var controller = world.get_node("RoverTraining")
	var driver = world.get_node("RoverHull")
	check(controller.developer_jump_event(1), "Jump to ice mission")
	driver.set_physics_process(false)
	controller.set_physics_process(false)
	var target = controller.targets.ice_a
	driver.position = target.position + Vector3(0,1.6,-2.8)
	driver.heading = 0
	driver.rotation.y = 0
	driver.speed = 0
	driver._sync_visual(1)
	driver._update_camera()
	await physics_frame
	controller._publish()
	check(controller.hud.extraction_popup.visible, "Nearby extraction popup")
	check(not controller.hud.panel.visible, "Operation panel hidden")
	key(true)
	controller._physics_process(2)
	check(controller.busy_id == "ice_a" and controller.busy_elapsed >= 2, "Holding E advances extraction")
	controller._publish()
	check(controller.hud.progress.visible, "Progress bar visible while holding")
	key(false)
	controller._physics_process(0.01)
	check(controller.busy_id == "" and controller.busy_elapsed == 0, "Release cancels extraction")
	check("ice_a" not in controller.data.samples, "Interrupted hold earns no sample")
	key(true)
	controller._physics_process(2)
	controller._publish()
	await process_frame
	await process_frame
	driver.step_drive(0, 0, 0, true)
	check(not driver.status.text.is_empty(), "Driving hints present")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/rover-hud-preview.png")
	controller._physics_process(4.1)
	key(false)
	check("ice_a" in controller.data.samples and not target.visible, "Full hold awards and hides sample")
	# Surface Survey uses the same displayed E interaction (F remains compatible).
	controller.data.mission = 0
	controller.data.surveys.clear()
	controller._refresh_targets()
	var survey = controller.targets.alpha
	driver.position = survey.position + Vector3(0, 0.7, -4)
	driver.speed = 0
	driver.heading = 0
	await physics_frame
	controller._publish()
	check(controller.hud.extraction_popup.visible, "Survey prompt appears before holding")
	check(controller.hud.extraction_prompt.text.to_upper().contains("SURVEY"), "Survey prompt describes current mission")
	key(true)
	controller._physics_process(3.1)
	key(false)
	check("alpha" in controller.data.surveys, "Holding E completes surface survey")
	controller.feedback = "EXPEDITION SUSPENDED. ROVER RECOVERED TO OUTPOST."
	controller._publish()
	await process_frame
	await process_frame
	var tracker = world.get_node("MissionTracker")
	check(controller.hud.result.position.y > tracker.detail.position.y, "Status below objective")
	check(driver.health_title.position.y >= controller.hud.result.position.y + controller.hud.result.get_minimum_size().y, "Health below status without overlap")
	print("Rover HUD / hold extraction failures: ", failures)
	quit(failures)
