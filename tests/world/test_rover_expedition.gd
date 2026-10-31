extends SceneTree
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0
var assertions := 0
var controller: Node
var driver: Node3D
var session: Node
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func position_for(id: String):
	var target: Node3D = controller.targets[id]
	driver.position = target.position+Vector3(0,0.7,-2.4 if id.begins_with("ice") else -4)
	driver.heading = 0
	driver.speed = 0
	driver.velocity = Vector3.ZERO
	driver.rotation.y = 0
	driver._sync_visual(1)
	driver._update_camera()
	await physics_frame
func capture(label: String):
	if DisplayServer.get_name() == "headless": return
	controller._publish()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://.tools/expedition_"+label+".png")
func advance_to(sol: int):
	while session.dashboard_state.sol < sol:
		# Keep this fixture focused on expedition progression, resolving pending choices.
		for event in session.dashboard_state.pending_events.duplicate():
			var event_id: String = event.get("id",event.get("event_id",""))
			var choices: Array = event.get("choices",[])
			if not choices.is_empty(): session.resolve_decision(event_id,choices[0].get("id",choices[0].get("choice_id","")))
		if not session.dashboard_state.pending_events.is_empty(): session.dashboard_state.pending_events.clear()
		session.dashboard_state.power_kwh = 10000
		session.dashboard_state.water_l = 10000
		session.dashboard_state.oxygen_kg = 10000
		session.dashboard_state.food_kg = 10000
		check(session.advance_mission(),"Sol uses existing advance_mission")
		await process_frame
		if session.dashboard_state.sol >= sol: break
		if not session.can_advance() and session.dashboard_state.pending_events.is_empty(): break
	session.dashboard_state.pending_events.clear()
	controller._physics_process(0.01)
func run():
	session = root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world = preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await process_frame
	driver = world.get_node("RoverHull")
	controller = world.get_node("RoverTraining")
	var player = world.get_node("Outpost/Astronaut")
	var access = world.get_node("LanderAccess")
	access.inside = true
	player.global_position = access.seat_eye-Vector3(0,1.1,0)
	player.set_seated(true,access.seat_eye)
	check(driver.start_control(),"Existing lander remote control starts")
	driver.set_physics_process(false)
	controller.set_physics_process(false)
	controller._physics_process(0.01)
	check(not controller.remote_ready(),"Startup gates tools and travel")
	await create_timer(10.5).timeout
	check(controller.remote_ready(),"Actual startup completes")
	check(Rules.assigned(controller.data,1) == -1,"Sol 1 locked")
	check(controller.arm.triangle_count > 0,"Existing instrument geometry articulated")
	check(controller.droplets.size() == 3,"Exactly three supplied droplet instances")
	check(world.find_children("StationAstronaut","Node3D",true,false).size() == 3,"Exactly three NPCs plus player")
	await capture("outpost")
	var camera_pose: Transform3D = driver.camera.global_transform
	driver.camera.global_position = Vector3(25,7,17)
	driver.camera.look_at(controller.departure.position)
	await capture("circle")
	driver.camera.global_position = Vector3(-10,5,-12)
	driver.camera.look_at(Vector3(-6,1,-5.5))
	await capture("solar")
	driver.camera.global_transform = camera_pose
	for mission in range(3):
		await advance_to(Rules.SOLS[mission])
		check(Rules.assigned(controller.data,session.dashboard_state.sol) == mission,"Correct assignment")
		driver.active = true
		driver.power_state = driver.Power.READY
		driver.position = controller.departure.position+Vector3.UP*0.7
		controller.armed = true
		controller._check_circle(1)
		await create_timer(1.5).timeout
		check(controller.data.location == "expedition","Circle enters expedition")
		check(not session.advance_mission(),"Cannot advance Sol while rover is away")
		check(player.seated,"Player stays in lander")
		check(world.find_children("RoverHull","CharacterBody3D",true,false).size() == 1,"One rover hull")
		if mission == 0:
			var start: Vector3 = driver.position
			var energy: float = session.dashboard_state.power_kwh
			for i in range(180): driver.step_drive(1.0/60,1,0,false)
			check(driver.position.distance_to(start)>0.5,"Existing driver travels on expedition collision terrain")
			check(session.dashboard_state.power_kwh < energy,"Expedition driving charges actual energy")
			for id in ["alpha","beta","gamma"]:
				await position_for(id)
				check(controller.scanner.validate(driver,controller.targets[id]) == "","Survey physics accessible: "+id)
				Input.action_press("rover_scan")
				controller._physics_process(3.1)
				Input.action_release("rover_scan")
				check(id in controller.data.surveys,"Survey committed: "+id)
			await capture("survey")
		elif mission == 1:
			for id in ["ice_a","ice_b","ice_c"]:
				await position_for(id)
				controller.handle_key(KEY_E)
				check(controller.busy_id == id,"Sampling starts: "+id)
				controller._physics_process(2)
				check(not controller.arm.transform.is_equal_approx(controller.arm.rest),"Original arm moves")
				if id == "ice_a":
					paused = true
					await create_timer(0.1).timeout
					check(controller.busy_elapsed == 2,"Pause freezes sampling")
					paused = false
					driver.active = false
					controller._physics_process(0.01)
					check(controller.busy_id == "" and controller.arm.transform.is_equal_approx(controller.arm.rest),"Disconnect restores original arm rest")
					check(id not in controller.data.samples,"Interrupted sample earns no progress")
					driver.active = true
					controller.handle_key(KEY_E)
					controller._physics_process(2)
				await capture(id)
				if id == "ice_a":
					camera_pose = driver.camera.global_transform
					driver.camera.global_position = driver.position+Vector3(3,1.7,3)
					driver.camera.look_at(driver.position)
					await capture("arm")
					driver.camera.global_transform = camera_pose
				controller._physics_process(4.1)
				check(id in controller.data.samples and not controller.targets[id].visible,"Sample committed and droplet hidden")
		else:
			check(controller.data.missing,"Stable crew identity missing")
			check(not controller.targets.astronaut.marker.visible and not controller.targets.astronaut.caption.visible,"No exact astronaut marker")
			await position_for("astronaut")
			controller._physics_process(0.01)
			check(controller.data.discovered,"Proximity and visibility discovery")
			await capture("rescue")
			controller.handle_key(KEY_E)
			check(controller.data.stabilized and controller.data.relay,"Immediate supplies and comms, no delivery animation")
			controller.dialogue = 0
			driver.position.z -= 20
			check(controller.speed_limit() == 0,"Hard separation limit")
			check(controller.speed_limit(1)>0,"At separation limit rover can close the gap")
			var before: Vector3 = controller.crew.position
			controller._escort(1)
			check(controller.crew.position.distance_to(before)>0,"Astronaut follows recorded route")
			driver.position = controller.extraction.position+Vector3.UP*0.7
			controller.armed = true
			controller._check_circle(1)
			check(not controller.transitioning,"Cannot extract without crew")
			controller.crew.position = controller.extraction.position+Vector3(0,0,5)
		check(Rules.ready_to_return(controller.data),"Objectives ready, not prematurely completed")
		check(not controller.data.completed.has(mission),"Completion waits for outpost")
		var saved: Dictionary = Save.capture(session)
		check(not Save.decode(saved).is_empty(),"Active mission save validates")
		check(Save.restore(session,saved) == OK,"Actual save restore succeeds")
		driver.sync_state()
		world.get_node("CrewFieldwork").sync()
		controller._sync()
		check(driver.start_control(),"Remote control reconnects after load")
		await create_timer(10.5).timeout
		check(driver.camera.current,"Restored rover uses remote camera")
		check(Rules.ready_to_return(controller.data),"Objectives survive restoration")
		check(controller.data.location == "expedition","Restored location is expedition")
		if mission == 2:
			controller.crew.position = controller.extraction.position+Vector3(0,0,5)
		driver.position = controller.extraction.position+Vector3.UP*0.7
		controller.armed = true
		controller._check_circle(1)
		if mission == 2:
			await create_timer(5).timeout
			await capture("arrival")
		await create_timer(20 if mission == 2 else 1.5).timeout
		check(controller.data.location == "outpost" and controller.data.completed.has(mission),"Return commits mission")
		check(not controller.armed,"Return marker disarmed")
		check(not Save.decode(Save.capture(session)).is_empty(),"Completed mission save validates")
	check(not controller.data.missing,"Rescued crew restored")
	var crew_phase: String = world.get_node("CrewFieldwork").data.crew.crew_briefing.phase
	check(controller.crew.get_node("InteractionArea").monitoring and controller.crew.get_node("CrewBody").collision_layer == 1 and crew_phase in ["Available","Preparing","Traveling","Working","Recording results","Returning"],"Rescued Maya resumes normal fieldwork: "+crew_phase)
	check(world.find_children("StationAstronaut","Node3D",true,false).size() == 3,"Four unique crew after cinematic")
	await capture("completed")
	print("EXPEDITION: %d failures / %d assertions" % [failures,assertions])
	quit(1 if failures else 0)
