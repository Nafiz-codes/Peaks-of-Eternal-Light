extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	# Days were replaced by Earth time: the Sol-skip tool is switched off and must refuse.
	check(world.get_node("MissionHUD").find_child("DeveloperSkipSols", true, false) == null, "No Sol-skip control while it is disabled.")
	check(session.start_selected_mission() == OK, "Mission starts.")
	var state: Variant = session.dashboard_state
	check(not session.developer_skip_sols(2) and state.sol == 0, "Disabled Sol skip leaves the calendar alone.")
	var rules := preload("res://src/simulation/rover_expedition.gd")
	var driver := world.get_node("RoverHull")
	var expedition := world.get_node("RoverTraining")
	# The old mission picker shares the disabled flag; DEV "Go to event" replaces it (test_developer_events).
	check(not expedition.developer_select_mission(1), "Disabled mission picker refuses.")
	driver.position.y = 25
	await driver._settle_parked()
	check(driver.position.y < 1.0, "Floating parked rover is settled onto the surface.")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	root.get_node("GameAudio").click_player.stop()
	root.get_node("GameAudio").hover_player.stop()
	await create_timer(0.1).timeout
	await process_frame
	print("Developer tools: %d failures / %d assertions." % [failures, assertions])
	quit(1 if failures else 0)

