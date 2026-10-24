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
	check(world.get_node("MissionHUD").find_child("DeveloperSkipSols", true, false) != null, "Debug skip control exists in mission panel.")
	world.get_node("MissionHUD").find_child("DeveloperSolCount", true, false).value = 2
	world.get_node("MissionHUD").find_child("DeveloperSkipSols", true, false).pressed.emit()
	check(session.dashboard_state != null, "Skip button starts selected mission.")
	await process_frame
	var state: Variant = session.dashboard_state
	check(state.sol == 2, "Calendar is Sol 2.")
	var power: float = state.power_kwh
	var food: float = state.food_kg
	var rules := preload("res://src/simulation/rover_expedition.gd")
	check(rules.assigned(state.rover_expedition, state.sol) == 0, "Survey unlock follows calendar.")
	check(session.developer_skip_sols(4) and state.sol == 6, "Can jump to rescue unlock Sol.")
	check(state.power_kwh == power and state.food_kg == food, "Developer jump does not consume supplies.")
	check(rules.assigned(state.rover_expedition, state.sol) == 0, "Overdue incomplete survey is preserved.")
	check(not session.developer_skip_sols(-1), "Backward skips rejected.")
	var driver := world.get_node("RoverHull")
	driver.active = true
	check(not session.developer_skip_sols(1), "Cannot skip during rover control.")
	driver.active = false
	paused = true
	check(not session.developer_skip_sols(1), "Paused game cannot jump.")
	paused = false
	state.rover_expedition.location = "expedition"
	check(not session.developer_skip_sols(1), "Cannot skip with rover away.")
	state.rover_expedition.location = "outpost"
	check(session.developer_skip_sols(100) and state.sol == 9, "Jump clamps before final simulated Sol.")
	check(not session.developer_skip_sols(1), "Final outcome cannot be bypassed.")
	check(not preload("res://src/runtime/mission_save.gd").decode(session.sol_checkpoint).is_empty(), "Skipped calendar checkpoint remains loadable.")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	root.get_node("GameAudio").click_player.stop()
	root.get_node("GameAudio").hover_player.stop()
	await create_timer(0.1).timeout
	await process_frame
	print("Developer Sol skip: %d failures / %d assertions." % [failures, assertions])
	quit(1 if failures else 0)
