extends SceneTree
var failures := 0
var assertions := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func drive(driver: Node, frames: int, throttle: float, steer: float, brake := false) -> void:
	for i in range(frames):
		await physics_frame
		driver.step_drive(1.0 / 60, throttle, steer, brake)
func run() -> void:
	root.size = Vector2i(1360, 820)
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var driver := world.get_node("RoverHull")
	var tires := world.get_node("Outpost/Rover/Wheels")
	check(tires.wheels.size() == 6, "Six independent tire pivots.")
	tires.update_motion(0.01, 0.0, driver.WHEELBASE)
	for wheel in tires.wheels:
		check(is_equal_approx(wheel.angle * wheel.radius, 0.01), "Roll matches distance / radius.")
	tires.update_motion(-0.01, 0.0, driver.WHEELBASE)
	check(is_zero_approx(tires.wheels[0].angle), "Reverse unwinds tire rotation.")
	tires.update_motion(0.0, driver.MAX_STEER, driver.WHEELBASE)
	check(is_zero_approx(tires.wheels[0].angle), "Stationary steering does not roll tires.")
	check(absf(tires.wheels[4].pivot.rotation.y) > absf(tires.wheels[5].pivot.rotation.y), "Inside front tire steers more sharply.")
	tires.reset()
	var player := world.get_node("Outpost/Astronaut")
	var access := world.get_node("LanderAccess")
	var hud := world.get_node("MissionHUD")
	check(not driver.start_control(), "Surface astronaut cannot control rover.")
	check(not session.send_rover("traverse", 1.0).ok, "Session rejects external rover commands.")
	check(world.get_node_or_null("Outpost/Rover/InteractionArea") == null, "No exterior control interaction.")
	hud.open_operations("rover")
	var has_dispatch := false
	for button in hud.operations.content.find_children("*", "Button", true, false):
		has_dispatch = has_dispatch or button.text.contains("3 km") or button.text == "Start mission"
	check(not has_dispatch, "Exterior rover panel has no dispatch or start controls.")
	hud.operations.hide()
	player.global_position = access.landing
	await process_frame
	access.transfer()
	await create_timer(2.1).timeout
	check(access.inside and player.seated, "Astronaut enters real lander seat.")
	var seated_position: Vector3 = player.position
	var remote_key := InputEventKey.new()
	remote_key.keycode = KEY_R
	remote_key.pressed = true
	root.push_input(remote_key)
	check(driver.active, "R key starts mission and remote control from lander.")
	driver.set_physics_process(false)
	check(driver.takeover.running and player.ui_blocked, "Takeover cinematic owns input.")
	var state: Variant = session.dashboard_state
	var initial_power: float = state.power_kwh
	var initial_position: Vector3 = driver.position
	var initial_heading: float = driver.heading
	driver.step_drive(1.0 / 60, 1.0, 0.0, false)
	check(driver.power_state == driver.Power.STARTING and driver.position == initial_position, "Rover stays still during power-on.")
	await create_timer(root.get_node("GameAudio").rover_player.stream.get_length() + 0.2).timeout
	check(driver.power_state == driver.Power.READY, "Actual startup playback completes before driving.")
	await drive(driver, 30, 0, 1)
	check(is_equal_approx(driver.heading, initial_heading), "Stationary steering cannot spin rover.")
	await drive(driver, 30, 1, 0)
	check(driver.speed > 0 and driver.speed < driver.MAX_SPEED, "Gradual acceleration.")
	await drive(driver, 90, 1, 1)
	check(driver.position.distance_to(initial_position) > 0.2 and driver.heading != initial_heading, "Curved forward steering.")
	check(player.position.is_equal_approx(seated_position), "Astronaut stays seated.")
	check(state.rover_total_distance_km > 0 and state.power_kwh < initial_power, "Movement spends energy and range.")
	check(is_equal_approx(initial_power - state.power_kwh, state.rover_total_distance_km * 0.55), "Authored energy rate per actual km.")
	check(driver.start_control(), "Control remains available from lander.")
	await drive(driver, 120, 0, 0, true)
	check(is_zero_approx(driver.speed), "Brake stops rover.")
	var brake_position: Vector3 = driver.position
	var brake_angle: float = tires.wheels[0].angle
	await drive(driver, 30, 0, 0, true)
	check(is_equal_approx(tires.wheels[0].angle, brake_angle), "Parked tires stop rolling.")
	check(Vector2(driver.position.x - brake_position.x, driver.position.z - brake_position.z).length() < 0.001, "No stopped drift.")
	await drive(driver, 60, -1, 0)
	check(driver.speed < 0 and absf(driver.speed) <= driver.REVERSE_SPEED, "Slower reverse travel.")
	await drive(driver, 90, 0, 0, true)
	var paused_position: Vector3 = driver.position
	paused = true
	driver.step_drive(1.0, 1, 1, false)
	paused = false
	check(driver.position == paused_position, "Pause freezes driving.")
	var barrier := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(8, 4, 0.5)
	barrier.add_child(shape)
	world.add_child(barrier)
	var forward := Vector3(sin(driver.heading), 0, cos(driver.heading))
	barrier.global_position = driver.global_position + forward * 2.5
	barrier.rotation.y = driver.heading
	var approach: Vector3 = driver.position
	var health_before: float = state.rover_health
	await drive(driver, 240, 1, 0)
	check(driver.position.distance_to(approach) < 2.0, "Obstacle blocks kinematic hull.")
	check(state.rover_health < health_before, "Crashing into a hard barrier damages rover health.")
	check(driver.health_bar.value == state.rover_health, "Health bar reflects collision damage.")
	var contact_health: float = state.rover_health
	await drive(driver, 60, 1, 0)
	check(state.rover_health == contact_health, "Holding throttle against an obstacle does not repeatedly damage rover.")
	check(not driver.repair(), "Cannot repair remotely from lander.")
	barrier.queue_free()
	await physics_frame
	state.power_kwh = 0.0
	var depleted_position: Vector3 = driver.position
	var depleted_angle: float = tires.wheels[0].angle
	await drive(driver, 40, 1, 0)
	check(is_equal_approx(tires.wheels[0].angle, depleted_angle), "Rejected movement does not roll tires.")
	check(Vector2(driver.position.x - depleted_position.x, driver.position.z - depleted_position.z).length() < 0.001, "No free travel without energy.")
	check(driver.status.text.contains("insufficient power"), "Visible resource rejection.")
	state.power_kwh = 150.0
	var damaged_health: float = state.rover_health
	state.rover_health = 0.0
	var disabled_position: Vector3 = driver.position
	await drive(driver, 30, 1, 0)
	check(driver.position == disabled_position and driver.speed == 0.0, "Zero health disables driving.")
	state.rover_health = damaged_health
	var saved_pose: Dictionary = state.rover_pose.duplicate(true)
	driver.stop_control()
	check(not driver.active and player.get_node("CameraPivot/FirstPersonCamera").current and not player.ui_blocked, "Release restores cockpit input/camera.")
	var save := preload("res://src/runtime/mission_save.gd")
	var snapshot: Dictionary = save.capture(session)
	check(save.decode(snapshot).state.rover_health == state.rover_health, "Damaged health survives saving.")
	snapshot.state.erase("rover_health")
	check(save.decode(snapshot).state.rover_health == 100.0, "Old saves default to full rover health.")
	check(save.decode(snapshot).state.rover_pose == saved_pose, "Saved rover pose survives decode.")
	snapshot.state.erase("rover_pose")
	check(not save.decode(snapshot).is_empty(), "Older saves remain compatible.")
	# Repeat engagement through keyboard; the physics callback reads real WASD state.
	root.push_input(remote_key)
	driver.set_physics_process(true)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(root.get_node("GameAudio").rover_player.stream.get_length() + 0.5).timeout
	var training := world.get_node("RoverTraining")
	check(training.rules.data.status == "failed" and is_zero_approx(driver.speed), "Critical damage remains a failed training attempt after repair.")
	training.handle_key(KEY_ENTER)
	await create_timer(0.5).timeout
	check(driver.speed > 0, "W key reaches the physics driving path.")
	key.pressed = false
	Input.parse_input_event(key)
	root.push_input(remote_key)
	check(not driver.active, "R key returns to lander.")
	driver.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args():
		driver.start_control()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/rover_remote.png")
		driver.stop_control()
	access.transfer()
	await create_timer(2.1).timeout
	check(not access.inside and not driver.start_control(), "Leaving lander prevents control.")
	state.rover_health = 0.0
	check(not driver.repair(), "Astronaut cannot repair from far away.")
	player.global_position = driver.rover.global_position + Vector3(2.0, 0.8, 0)
	await physics_frame
	world._on_player_interaction("rover_repair")
	check(state.rover_health == 100.0 and driver.health_bar.value == 100.0, "Nearby astronaut repairs rover and health bar.")
	check(not driver.repair(), "Full health rover needs no repair.")
	check(session.reset_current_mission() == OK, "Reset succeeds.")
	check(driver.position.is_equal_approx(Vector3(5.2, 0.65, -2.8)), "Reset restores parking pose.")
	print("Lander rover driving: %d failures / %d assertions." % [failures, assertions])
	quit(1 if failures else 0)
