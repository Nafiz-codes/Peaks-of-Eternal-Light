extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("MissionSession").select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var camera := world.get_node("DeveloperFreeCamera")
	var player := world.get_node("Outpost/Astronaut")
	var original := root.get_camera_3d()
	var pose: Transform3D = player.global_transform
	var mouse_mode := Input.mouse_mode
	world.get_node("MissionHUD").find_child("DeveloperFreeCameraButton", true, false).pressed.emit()
	check(camera.active and not paused, "Spectator leaves gameplay running.")
	check(world.get_node("OrbitalMotion").can_process(), "World simulation continues while spectating.")
	check(root.get_camera_3d() == camera, "Free camera owns the view.")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var start: Vector3 = camera.global_position
	camera._process(1.0)
	check(camera.global_position.distance_to(start) > 20.0, "Spectator flies freely through the live world.")
	check(player.global_transform.is_equal_approx(pose), "Astronaut stays in place.")
	key.pressed = false
	Input.parse_input_event(key)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not camera.active and not paused, "Escape returns without opening pause menu.")
	check(player.process_mode == Node.PROCESS_MODE_INHERIT, "Player controls are restored.")
	check(root.get_camera_3d() == original, "Previous camera is restored.")
	check(Input.mouse_mode == mouse_mode, "Mouse mode is restored.")
	player.ui_blocked = true
	camera.toggle()
	check(not camera.active, "Modal gameplay cannot enter free camera.")
	player.ui_blocked = false
	camera.toggle()
	world.queue_free()
	await process_frame
	check(not paused, "Removing the world leaves gameplay unpaused.")
	root.get_node("GameAudio").click_player.stop()
	root.get_node("GameAudio").hover_player.stop()
	await create_timer(0.3).timeout
	print("Developer free camera: %d failures." % failures)
	quit(1 if failures else 0)
