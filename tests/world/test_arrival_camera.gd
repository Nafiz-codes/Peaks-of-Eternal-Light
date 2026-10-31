extends SceneTree
var failures := 0
var samples := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("MissionSession")
	session.reduce_motion = false
	for scenario in ["ridge_a", "crater_rim_b", "shadow_zone", "plateau_d", "blocked"]:
		var site: String = "ridge_a" if scenario == "blocked" else scenario
		# Arrival camera is the established-mission return path; new missions plan first.
		session.select_landing_site(site)
		session.start_selected_mission()
		session.outpost_pose = {}
		change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
		await scene_changed
		current_scene.select_site(site)
		await scene_changed
		var world := current_scene
		var player := world.get_node("Outpost/Astronaut")
		if scenario == "blocked":
			var wall := StaticBody3D.new()
			world.add_child(wall)
			wall.global_position = player.global_position + Vector3(0, 1.5, 1.0)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2, 3, 0.3)
			shape.shape = box
			wall.add_child(shape)
			# The cover hides the orbit search; inspect only the revealed sequence.
			await create_timer(0.7).timeout
		var probe := preload("res://src/world/safe_arrival_camera.gd").new()
		await physics_frame
		await physics_frame
		await process_frame
		probe.configure(player, player.get_node("CameraPivot/SpringArm/ThirdPersonCamera").global_transform)
		var began := Time.get_ticks_msec()
		var captured := false
		while Time.get_ticks_msec() - began < 1900:
			await process_frame
			var camera := root.get_camera_3d()
			samples += 1
			if camera.global_position.distance_to(probe.center) <= probe.body_radius:
				failures += 1
				push_error("Arrival camera entered astronaut clearance: " + site)
			if not captured and Time.get_ticks_msec() - began > 500 and DisplayServer.get_name() != "headless":
				captured = true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.tools/arrival-" + site + ".png")
		if player.ui_blocked or not player.is_physics_processing():
			failures += 1
			push_error("Arrival failed to release astronaut: " + site)
	print("ARRIVAL CAMERA: %d failures / %d rendered clearance samples across four sites and an obstructed spawn" % [failures, samples])
	quit(failures)
