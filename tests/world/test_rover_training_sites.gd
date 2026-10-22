extends SceneTree
var failures := 0
var assertions := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var session := root.get_node("MissionSession")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.sites:
		session.select_landing_site(site.site_id)
		var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await physics_frame
		await physics_frame
		var driver := world.get_node("RoverHull")
		var training := world.get_node("RoverTraining")
		driver.set_physics_process(false)
		training.set_physics_process(false)
		driver.active = true
		driver.power_state = driver.Power.READY
		driver.heading = 0
		for id in training.targets:
			var target: Area3D = training.targets[id]
			var approach := target.global_position + Vector3(0, 20, -4)
			var ray := PhysicsRayQueryParameters3D.create(approach, approach - Vector3.UP * 40, 1, [driver.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty(), "%s / %s has an existing terrain approach" % [site.site_id, id])
			if hit.is_empty(): continue
			driver.global_position = hit.position + Vector3.UP * 0.65
			check(training.scanner.validate(driver, target) == "", "%s / %s reachable from actual terrain height" % [site.site_id, id])
		driver.active = false
		world.queue_free()
		await process_frame
	print("ROVER TRAINING SITES: %d failures / %d assertions" % [failures, assertions])
	quit(failures)
