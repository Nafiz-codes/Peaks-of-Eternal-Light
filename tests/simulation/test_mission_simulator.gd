extends SceneTree

const MissionSimulatorScript = preload("res://src/simulation/mission_simulator.gd")


func _init() -> void:
	var simulator := MissionSimulatorScript.new()
	_assert(simulator.call("load_contracts") == OK, "All five resource contracts should load.")
	_assert(simulator.get("sites").size() == 4, "The starter site contract should expose four sites.")
	_assert(simulator.get("crew").size() == 4, "The starter crew contract should expose four members.")
	_assert(simulator.get("events").size() == 8, "The starter event contract should expose eight events.")

	var state: Object = simulator.call("begin_mission", "ridge_a", 2)
	_assert(state.get("sol") == 0, "A new mission starts at sol zero.")
	_assert(state.get("crew_size") == 4, "Mission crew size comes from bvad_constants.json.")

	var first_tick: Dictionary = simulator.call("advance_sol", state)
	_assert(state.get("sol") == 1, "A sol tick increments the mission clock exactly once.")
	_assert(not first_tick.get("completed", true), "A two-sol mission is not complete after its first tick.")

	var second_tick: Dictionary = simulator.call("advance_sol", state)
	_assert(second_tick.get("completed", false), "A two-sol mission completes after its second tick.")
	_assert(state.get("history").size() == 3, "History includes the initial state and each completed tick.")

	print("MissionSimulator tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
