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
	check(player.get_node("CameraPivot/FirstPersonCamera").global_position.distance_to(access.seat_eye) < 0.01, "Camera arrives at the seated eye")
	var seat_position: Vector3 = player.global_position
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.pressed = true
	player._unhandled_input(jump)
	check(not player.jump_requested, "Jump input is disabled while seated")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/lander_interior.png")
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
	check(player.global_position.distance_to(access.landing) < 0.35, "Exit returns to the exterior landing")
	print("Lander interior tests: %d failures." % failures)
	quit(1 if failures else 0)
