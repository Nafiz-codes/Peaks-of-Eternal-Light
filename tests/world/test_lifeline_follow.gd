extends SceneTree
var failures := 0
func _init(): call_deferred("run")
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
	world.queue_free()
	await process_frame
	print("Lifeline sustained escort: %d failures" % failures)
	quit(1 if failures else 0)
