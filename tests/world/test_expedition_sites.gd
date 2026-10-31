extends SceneTree
var failures := 0
var assertions := 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func run():
	var session := root.get_node("MissionSession")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.sites:
		session.select_landing_site(site.site_id)
		session.start_selected_mission()
		session.dashboard_state.sol = 6 # Geometry fixture, scheduling tested separately.
		var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await physics_frame
		await physics_frame
		var driver := world.get_node("RoverHull")
		var controller := world.get_node("RoverTraining")
		driver.set_physics_process(false)
		controller.set_physics_process(false)
		driver.active = true
		driver.power_state = driver.Power.READY
		driver.heading = 0
		for id in controller.targets:
			var target: Area3D = controller.targets[id]
			var approach := target.global_position + Vector3(0,30,-2.4 if id.begins_with("ice") else -4)
			var query := PhysicsRayQueryParameters3D.create(approach,approach-Vector3.UP*60,1,[driver.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),site.site_id+" / "+id+" grounded approach")
			if hit.is_empty(): continue
			driver.position = hit.position+Vector3.UP*0.65
			check(controller.scanner.validate(driver,target) == "",site.site_id+" / "+id+" unobstructed interaction")
		check(controller.departure.ring.mesh is ArrayMesh,"Circle follows actual outpost ground")
		for sample in range(16):
			var angle := TAU * sample / 16.0
			var point: Vector3 = controller.departure.position + Vector3(cos(angle), 0, sin(angle)) * 5.0
			check(absf(controller.ground_y(point) - 1.0) < 0.02, "Departure footprint is flat: " + site.site_id)
		check(controller.crew.get_meta("crew_id") == "CREW_02","Maya identity used for rescue")
		check(world.find_children("StationAstronaut","Node3D",true,false).size() == 3,"No duplicate crew")
		driver.active = false
		world.queue_free()
		await process_frame
	print("EXPEDITION SITES: %d failures / %d assertions" % [failures,assertions])
	quit(1 if failures else 0)
