extends SceneTree
var failures := 0
var assertions := 0
var training: Node
var driver: Node3D
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func position_for(id: String) -> void:
	var target: Area3D = training.targets[id]
	driver.global_position = target.global_position + Vector3(0, 0.65, -4)
	driver.heading = 0
	driver.rotation.y = 0
	driver.speed = 0
	driver.velocity = Vector3.ZERO
	driver._sync_visual(1)
	driver._update_camera()
	await physics_frame
func scan(id: String) -> void:
	await position_for(id)
	check(training.scanner.validate(driver, training.targets[id]) == "", "World target reachable: " + id)
	Input.action_press("rover_scan")
	await process_frame
	training._physics_process(3.1)
	Input.action_release("rover_scan")
	await process_frame
	check(training.rules.data.scans.has(id), "World scan recorded: " + id)
func interact(id: String) -> void:
	await position_for(id)
	training.handle_key(KEY_E)
	check(training.busy_id == id, "Contextual action starts: " + id)
	training._physics_process(2.0)
	if DisplayServer.get_name() != "headless":
		training._publish()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://.tools/rover_training_%s.png" % training.rules.data.stage)
	training._physics_process(4.1)
func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await process_frame
	driver = world.get_node("RoverHull")
	training = world.get_node("RoverTraining")
	var access := world.get_node("LanderAccess")
	var player := world.get_node("Outpost/Astronaut")
	access.inside = true
	player.global_position = access.seat_eye - Vector3(0, 1.1, 0)
	player.set_seated(true, access.seat_eye)
	check(driver.start_control(), "Existing remote connection starts")
	driver.set_physics_process(false)
	training.set_physics_process(false)
	training._physics_process(0.01)
	check(training.rules.data.scans.is_empty(), "Startup cannot scan")
	training.handle_key(KEY_E)
	check(training.busy_id == "", "Startup cannot use tools")
	check(driver.takeover.video.volume == 0, "Video embedded sound muted")
	check(absf(root.get_node("GameAudio").rover_player.stream.get_length() - 10) < 0.2, "Dedicated startup sound is ten seconds")
	await create_timer(10.5).timeout
	check(driver.power_state == driver.Power.READY, "Actual playback completion unlocks control")
	for id in ["alpha", "beta", "gamma"]: await scan(id)
	await interact("uplink")
	check(training.rules.data.status == "success", "Survey completes through world adapter")
	training.handle_key(KEY_ENTER)
	check(training.rules.data.mission == 1, "Next mission in sequence")
	training.handle_key(KEY_L)
	await interact("perimeter")
	for id in ["ice_a", "ice_b", "ice_c"]: await scan(id)
	await interact("ice_b")
	check(training.rules.data.stage == "ice_upload", "Sample and analysis finish")
	await interact("uplink")
	check(training.rules.data.status == "success", "Science mission completes")
	training.handle_key(KEY_ENTER)
	training._physics_process(1)
	check(training.rules.data.remaining < training.life_support_seconds, "Rescue clock starts on ready remote")
	var reserve: float = training.rules.data.remaining
	paused = true
	await create_timer(0.15).timeout
	check(training.rules.data.remaining == reserve, "Pause freezes reserve")
	paused = false
	await scan("astronaut")
	await interact("astronaut")
	await interact("astronaut")
	check(training.rules.data.stabilized and training.kit.visible, "Package deployed and stabilization committed")
	await interact("astronaut")
	check(training.relay.visible, "Relay displayed")
	await interact("astronaut")
	check(training.rules.data.status == "success" and not training.astronaut.visible, "Independent pickup completed")
	check(player.seated and player.get_parent() != driver, "Astronaut remains separate from uncrewed rover")
	training._restart(0)
	await position_for("alpha")
	driver.speed = 0.8
	check(training.scanner.validate(driver, training.targets.alpha) != "", "Physics validation rejects moving rover")
	driver.speed = 0
	driver.heading = PI
	check(training.scanner.validate(driver, training.targets.alpha) != "", "Scanner rejects target behind rover")
	driver.heading = 0
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 4, 0.4)
	collision.shape = shape
	obstacle.add_child(collision)
	world.add_child(obstacle)
	obstacle.global_position = training.targets.alpha.global_position + Vector3(0, 1, -2)
	await physics_frame
	await physics_frame
	check(training.scanner.validate(driver, training.targets.alpha).contains("blocked"), "Physics ray rejects obstruction")
	obstacle.queue_free()
	await physics_frame
	training.rules.fail("test retry")
	training.handle_key(KEY_ENTER)
	check(training.rules.data.status == "active" and training.rules.data.scans.is_empty() and not training.kit.visible, "Retry restores tools and scan state")
	await position_for("alpha")
	driver.global_position.z -= 20.0
	check(training.scanner.validate(driver, training.targets.alpha).contains("Approach"), "Out-of-range scan rejected")
	training._restart(1)
	training.rules.data.lights = true
	await position_for("perimeter")
	training.handle_key(KEY_E)
	training._physics_process(1.0)
	driver.global_position.x += 20.0
	training._physics_process(3.0)
	check(training.busy_id == "" and training.rules.data.stage == "perimeter", "Leaving interaction range cancels without advancing")
	training._restart(2)
	training.rules.data.clock_started = true
	reserve = training.rules.data.remaining
	driver.power_state = driver.Power.STARTING
	training._physics_process(10)
	check(training.rules.data.remaining == reserve, "Reconnection cinematic also freezes rescue clock")
	driver.power_state = driver.Power.READY
	training._publish()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://.tools/rover_training_hud.png")
		root.size = Vector2i(960, 540)
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://.tools/rover_training_hud_small.png")
	driver.stop_control()
	print("ROVER TRAINING WORLD: %d failures / %d assertions" % [failures, assertions])
	quit(failures)
