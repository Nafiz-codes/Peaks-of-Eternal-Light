extends SceneTree
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/lifeline-" + label + ".png")
func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var controller := world.get_node("RoverTraining")
	var driver := world.get_node("RoverHull")
	var orbit := world.get_node("OrbitalMotion")
	var sun := world.get_node("LowPolarSun")
	var environment: Environment = world.get_node("LunarEnvironment").environment
	check(controller.developer_jump_event(3), "Enter Lifeline through mission setup")
	await physics_frame
	controller.set_physics_process(false)
	driver.set_physics_process(false)
	orbit.apply_sky()
	check(orbit.is_lifeline_shadowed() and is_zero_approx(sun.light_energy), "Lifeline blocks direct sun")
	check(environment.ambient_light_energy >= 0.1 and environment.ambient_light_energy < orbit.daylight_ambient_energy, "Ambient fill remains navigable but dimmer than daylight")
	check(not controller.lights.visible, "Headlights start off and remain optional")
	await capture("lights-off")
	controller.handle_key(KEY_L)
	check(controller.lights.visible, "L turns on headlights in dark zone")
	await capture("lights-on")
	controller.handle_key(KEY_L)
	check(not controller.lights.visible, "L can turn headlights off again")
	var saved := Save.capture(session)
	check(Save.restore(session, saved) == OK, "Lifeline save restores")
	driver.sync_state()
	controller._sync()
	orbit.apply_sky()
	check(not orbit.is_lifeline_shadowed(), "Loading returns the player to the normally lit outpost")
	driver.active = true
	driver.camera.make_current()
	driver._update_camera()
	orbit.apply_sky()
	check(orbit.is_lifeline_shadowed(), "Restored mission retains darkness")
	for mission in [0, 1]:
		controller.data.mission = mission
		orbit.apply_sky()
		check(not orbit.is_lifeline_shadowed() and is_equal_approx(environment.ambient_light_energy, orbit.daylight_ambient_energy), "Earlier mission retains ambient daylight")
	controller.data.mission = 2
	controller.data.location = "outpost"
	orbit.apply_sky()
	check(not orbit.is_lifeline_shadowed(), "Recall clears darkness")
	controller.data.location = "expedition"
	# Arrival moves the camera before expedition location is committed to outpost.
	controller._place_rover(Vector3(38, 1, 26))
	orbit.apply_sky()
	check(not orbit.is_lifeline_shadowed() and is_equal_approx(environment.ambient_light_energy, orbit.daylight_ambient_energy), "Outpost arrival camera restores ambient light before mission completion")
	check(sun.light_energy > 0, "Outpost direct sunlight is restored")
	world.queue_free()
	await process_frame
	print("LIFELINE LIGHTING: %d failures" % failures)
	quit(failures)
