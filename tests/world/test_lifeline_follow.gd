extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func run():
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.dashboard_state.sol = 6
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var escort := world.get_node("RoverTraining")
	var driver := world.get_node("RoverHull")
	escort.set_physics_process(false)
	escort.data.missing = true # Lifeline is open: outpost fieldwork leaves the lost astronaut alone.
	# As _restore_crew does: the walking follower carries them, so their standing body must not block it.
	escort.crew.get_node("CrewBody").collision_layer = 0
	driver.set_physics_process(false)
	var start := Vector3(4000,0.02,12)
	escort.crew.global_position = start
	escort.follower.global_position = start
	escort.follower.velocity = Vector3.ZERO
	driver.global_position = Vector3(4000,0.7,0)
	escort.data.stabilized = true
	escort.data.relay = true
	escort.data.route = PackedVector3Array([start, driver.global_position])
	for frame in range(540):
		await physics_frame
		escort._escort(1.0/60)
	var distance: float = Vector2(escort.crew.position.x-driver.position.x,escort.crew.position.z-driver.position.z).length()
	if distance > 5.3:
		failures += 1
		push_error("Escort stops after consuming the first breadcrumb instead of catching up: %.2f m" % distance)
	if escort.crew.position.distance_to(start) < 6:
		failures += 1
		push_error("Astronaut must sustain walking, not merely move for one frame")
	if escort.crew.global_position.distance_to(escort.extraction.global_position) > 9:
		failures += 1
		push_error("Astronaut must reach the extraction acceptance radius")
	escort.data.mission = 2
	escort.data.completed = [0,1]
	escort.data.discovered = true
	escort.data.location = "expedition"
	escort.data.phase = "active"
	var waiting: Vector3 = escort.crew.global_position
	driver.global_position = waiting+Vector3(0,0.7,-22)
	escort._escort(1.0/60)
	check(escort.data.get("escort_lost",false),"Pulling ahead loses the astronaut")
	check(escort.speed_limit(1) == driver.MAX_SPEED and escort.speed_limit(-1) == driver.MAX_SPEED,"No forced slowdown in either direction")
	for frame in range(60):
		await physics_frame
		escort._escort(1.0/60)
	check(escort.crew.global_position.is_equal_approx(waiting) and escort.follower.velocity == Vector3.ZERO,"Lost astronaut waits instead of catching up automatically")
	check(escort.crew_player.current_animation == "idle","Lost astronaut stands still")
	check(escort.data.route.is_empty(),"Abandoned route is discarded")
	var view := {}
	escort.hud_changed.connect(func(value: Dictionary): view.merge(value,true))
	escort._publish()
	check(str(view.objective).contains("lost the rover"),"Objective tells the player the astronaut is lost")
	check(escort._navigation().destination.is_equal_approx(waiting),"Navigation returns to the waiting astronaut")
	var save = preload("res://src/runtime/mission_save.gd")
	var decoded: Dictionary = save.decode(save.capture(session))
	check(not decoded.is_empty() and decoded.state.rover_expedition.get("escort_lost",false),"Lost state persists in saves")
	driver.global_position = waiting+Vector3(0,0.7,-10)
	escort._escort(1.0/60)
	check(escort.data.escort_lost,"Astronaut waits until the rover returns close enough")
	driver.global_position = waiting+Vector3(0,0.7,-7)
	for frame in range(120):
		await physics_frame
		escort._escort(1.0/60)
	check(not escort.data.escort_lost and escort.escort_link,"Returning within eight metres resumes escort")
	check(escort.crew.global_position.distance_to(waiting) > 0.5,"Astronaut walks again after reunion")
	escort._publish()
	check(not str(view.objective).contains("lost the rover"),"Reunion restores the extraction objective")
	world.queue_free()
	await process_frame
	print("Lifeline sustained escort: %d failures" % failures)
	quit(1 if failures else 0)
