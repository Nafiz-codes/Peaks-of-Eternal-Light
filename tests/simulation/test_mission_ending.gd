extends SceneTree
## Maya's end-of-mission review: debrief stages, the reserve check and a lasting success.
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var data := Rules.fresh()
	check(Rules.debrief(data) == "", "No review before Lifeline is complete")
	data.completed = [0, 1, 2]
	check(Rules.debrief(data) == "pending", "Maya comes to review once Lifeline is complete")
	for stage in ["retry", "done"]:
		data["debrief"] = stage
		check(Rules.debrief(data) == stage and Rules.valid_save(data), "Review stage %s is kept and saves" % stage)
	data["debrief"] = "nonsense"
	check(not Rules.valid_save(data), "Unknown review stages are rejected in saves")

	var simulator := Simulator.new()
	check(simulator.load_contracts() == OK, "Contracts load")
	# Short on power: the review lists it and the mission stays in progress.
	var state: Variant = simulator.begin_mission("ridge_a")
	# Every reserve at its goal line except power.
	for key in Simulator.MISSION_GOALS: state.set(key, Simulator.MISSION_GOALS[key])
	state.power_kwh = 10.0
	var shortfalls: Array = simulator.complete_mission(state)
	check(shortfalls == ["power"] and state.mission_outcome.status == "in_progress", "Low power fails the review without ending the mission")
	check(state.milestones.size() == 1 and state.milestones[0].label == "Landing", "Landing reserves are recorded as the first milestone")
	# Enough of everything: success, and it survives later actions and a save round trip.
	state.power_kwh = 290.0
	check(simulator.complete_mission(state).is_empty() and state.mission_outcome.status == "success", "A well-supplied base passes the review")
	simulator._publish_action_state(state)
	check(state.mission_outcome.status == "success", "Success is not wiped by later updates")
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.dashboard_simulator = simulator
	session.dashboard_state = state
	var decoded := Save.decode(Save.capture(session))
	check(not decoded.is_empty() and decoded.state.mission_outcome.status == "success", "Success survives saving and loading")
	check(state.milestones[-1].label == "Mission review" and decoded.state.milestones.size() == state.milestones.size(), "The review is recorded as a milestone and milestones survive saving")
	simulator.record_milestone(state, "Landing")
	check(state.milestones.size() == 2, "A milestone is recorded only once (replays add nothing)")
	check(simulator.complete_mission(state).is_empty(), "Reviewing a confirmed mission again still confirms it")
	var failed: Variant = simulator.begin_mission("ridge_a")
	failed.food_kg = 0.0
	failed.mission_outcome = simulator._evaluate_mission_outcome(failed)
	check(simulator.complete_mission(failed) == ["mission"] and failed.mission_outcome.status == "failure", "A failed mission cannot pass the review")

	# Continue playing: the mission reopens, stays open, and Surface Survey can be replayed.
	var played: Variant = simulator.begin_mission("ridge_a")
	for key in Simulator.MISSION_GOALS: played.set(key, Simulator.MISSION_GOALS[key])
	check(simulator.complete_mission(played).is_empty(), "Base passes the review")
	played.rover_expedition = Rules.fresh()
	played.rover_expedition.completed = [0, 1, 2]
	played.rover_expedition["debrief"] = "done"
	check(Rules.assigned(played.rover_expedition) == -1, "No operation is offered after the ending")
	session.dashboard_simulator = simulator
	session.dashboard_state = played
	check(session.continue_after_ending(), "Continue playing reopens the mission")
	simulator._publish_action_state(played)
	check(played.mission_outcome.status == "in_progress", "The reopened mission stays open")
	check(Rules.assigned(played.rover_expedition) == 0, "Surface Survey can be flown again")
	var reloaded := Save.decode(Save.capture(session))
	check(not reloaded.is_empty() and reloaded.state.mission_outcome.status == "in_progress" and reloaded.state.rover_expedition.free_play, "Free play survives saving and loading")
	check(not session.continue_after_ending(), "Continue only applies to a completed mission")

	# DEV resources top up every reserve, with power capped at the battery size.
	var topped: Variant = simulator.begin_mission("ridge_a")
	simulator.developer_add_resources(topped)
	check(is_equal_approx(topped.power_kwh, Simulator.BATTERY_CAPACITY_KWH) and is_equal_approx(topped.water_l, Simulator.INITIAL_WATER_L + 150.0), "DEV resources fill reserves and cap power")
	for drain in 6: simulator.developer_add_resources(topped, -1.0)
	check(topped.power_kwh == 0.0 and topped.water_l == 0.0 and topped.oxygen_kg == 0.0 and topped.food_kg == 0.0, "DEV drain stops at zero")

	print("MISSION ENDING: %d failures" % failures)
	quit(failures)
