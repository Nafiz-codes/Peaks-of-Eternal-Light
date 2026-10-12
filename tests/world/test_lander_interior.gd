extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var access = world.get_node("LanderAccess")
	var player = world.get_node("Outpost/Astronaut")
	var habitat = world.get_node("Outpost/Habitat")
	var collider: CollisionShape3D = habitat.get_node("CapsuleHull").get_child(0)
	check(collider.shape is ConvexPolygonShape3D and collider.shape.points.size() <= 48, "Capsule uses a lightweight convex collision hull")
	check(habitat.get_node("ApolloCommandModule").scale.is_equal_approx(Vector3.ONE), "Capsule uses the enlarged astronaut-relative scale")
	var outdoor_fov: float = player.get_node("CameraPivot/FirstPersonCamera").fov
	player.set_physics_process(false)
	check(not access.door_available(), "Door is unavailable from the initial surface position")
	player.global_position = access.landing
	await process_frame
	check(access.button.visible and access.button.text == "Get inside  [E]", "Get inside is offered at the capsule hatch")
	access.button.pressed.emit()
	await create_timer(0.4).timeout
	check(access.busy and access.fade.modulate.a > 0 and access.fade.modulate.a < 1, "Entry gradually darkens the screen")
	check(player.global_position.distance_to(access.landing) < 0.1, "Teleport waits for blackout")
	await create_timer(1.65).timeout
	check(access.inside and not access.busy and player.first_person and player.seated, "Entry finishes in the crew seat")
	var visual: Node3D = player.get_node("AnimatedAstronaut")
	check(visual.visible and player.seated_pose != null, "The seated suit stays visible with a seated bone pose")
	check(player.get_node("CameraPivot/FirstPersonCamera").global_position.distance_to(access.seat_eye) < 0.01, "Camera arrives at the seated eye")
	check(is_equal_approx(player.get_node("CameraPivot/FirstPersonCamera").fov, outdoor_fov), "Cockpit retains the outdoor first-person field of view")
	check(is_equal_approx(player.camera_pitch, -0.22), "Cockpit opens at the outdoor first-person viewing angle")
	var seat_position: Vector3 = player.global_position
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.pressed = true
	player._unhandled_input(jump)
	check(not player.jump_requested, "Jump input is disabled while seated")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/lander_interior.png")
		for view in [["down", -0.85, PI], ["steep", -1.45, PI], ["left", -0.6, PI + 1.2], ["right", -0.6, PI - 1.2], ["back", 0.0, 0.0]]:
			player.camera_pitch = view[1]
			player.camera_yaw = view[2]
			player._sync_camera_rig()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/seated_%s.png" % view[0])
		player.camera_pitch = -0.22
		player.camera_yaw = PI
		player._sync_camera_rig()
	# Headless Godot cannot capture the OS cursor; exercise the shared look path.
	player._apply_mouse_look(Vector2(450, 500))
	check(player.camera_pitch < -1.0, "Cockpit allows looking down like outdoor first person")
	check(absf(wrapf(player.camera_yaw - PI, -PI, PI)) > 0.9, "Cockpit no longer restricts horizontal mouse look")
	check(player.get_node("CameraPivot/FirstPersonCamera").global_position.distance_to(access.seat_eye) < 0.01, "Looking around keeps the eye fixed in the seat")
	check(is_equal_approx(player.rotation.y, PI), "Mouse look does not swivel the seated body into the camera")
	for i in range(45):
		await physics_frame
	check(player.velocity.is_zero_approx(), "Seated astronaut stays fixed instead of falling or walking")
	check(player.global_position.is_equal_approx(seat_position), "Seat position remains stable")
	await process_frame
	await process_frame
	check(access.button.visible, "Seat offers an exit")
	access.button.pressed.emit()
	await create_timer(2.05).timeout
	check(not access.inside and not access.busy and not player.seated, "Exit restores walking")
	check(visual.visible and visual.position.is_equal_approx(Vector3(0, -0.04, 0)), "Exit restores the visible standing suit and its offset")
	check(player.seated_pose == null and player.animation_player.is_playing(), "Exit clears the seated pose and resumes animation")
	check(player.global_position.distance_to(access.landing) < 0.35, "Exit returns to the exterior landing")
	print("Lander interior tests: %d failures." % failures)
	quit(1 if failures else 0)
