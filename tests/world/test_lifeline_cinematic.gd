extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func run():
	root.size = Vector2i(1280,800)
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.dashboard_state.sol = 6
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var controller := world.get_node("RoverTraining")
	var driver := world.get_node("RoverHull")
	controller.set_physics_process(false)
	driver.set_physics_process(false)
	controller._arrival()
	check(controller.cinematic_bars[0].visible and controller.cinematic_bars[1].visible, "Letterbox bars appear for arrival")
	var captured := false
	var elapsed := 0.0
	var clearance := true
	var front := true
	while controller.cinematic_motion and elapsed < 20:
		await physics_frame
		elapsed += 1.0/60.0
		if not controller.cinematic_motion: break
		var camera: Camera3D = controller.cinematic_camera
		clearance = clearance and camera.global_position.y >= controller.ground_y(camera.global_position)+4.4
		front = front and (camera.global_position-driver.global_position).dot(Vector3(-14,0,-8).normalized()) >= 16.9
		if not captured and elapsed > 4 and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/lifeline_front_cinematic.png")
			captured = true
	check(clearance, "Camera stays above terrain for entire shot")
	check(front, "Camera remains ahead of rover at a distance")
	check(not controller.cinematic_motion, "Arrival finishes")
	check(not controller.cinematic_bars[0].visible and not controller.cinematic_bars[1].visible, "Letterbox bars clear after arrival")
	controller._arrival()
	session.reset_current_mission()
	controller._sync()
	check(not controller.cinematic_bars[0].visible and not controller.cinematic_bars[1].visible, "Reset clears letterbox bars during an interrupted cinematic")
	world.queue_free()
	await process_frame
	print("Lifeline cinematic: %d failures" % failures)
	quit(1 if failures else 0)
