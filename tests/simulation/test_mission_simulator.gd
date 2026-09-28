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
	_assert(is_equal_approx(state.get("power_generated_kwh"), 43.536935), "Ridge A solar generation uses its verified illumination value.")
	_assert(is_equal_approx(state.get("power_consumed_kwh"), 48.0), "Baseline power consumption uses crew size and the contract value.")
	_assert(is_equal_approx(state.get("power_kwh"), 115.536935), "The battery reserve receives the sol power balance.")
	_assert(state.get("radiation_this_sol_msv") > 0.0, "Every sol adds a positive radiation dose.")
	_assert(state.get("terrain_shielding_factor") > 0.0, "Terrain fields produce a shielding factor.")
	_assert(is_equal_approx(state.get("water_consumed_l"), 46.4), "Water use includes potable and hygiene consumption for all crew.")
	_assert(is_equal_approx(state.get("water_recovered_l"), 41.76), "Water recovery uses the contract recycling rate.")
	_assert(is_equal_approx(state.get("water_l"), 395.36), "The reserve reflects water use and recovery.")
	_assert(is_equal_approx(state.get("oxygen_consumed_kg"), 3.36), "Oxygen use follows the per-crew daily contract value.")
	_assert(is_equal_approx(state.get("food_consumed_kg"), 2.48), "Food use follows the per-crew daily contract value.")
	_assert(state.get("life_support_status").get("oxygen") == "nominal", "Life support status is available to presentation code.")

	var second_tick: Dictionary = simulator.call("advance_sol", state)
	_assert(second_tick.get("completed", false), "A two-sol mission completes after its second tick.")
	_assert(state.get("history").size() == 3, "History includes the initial state and each completed tick.")

	var low_oxygen_state: Object = simulator.call("begin_mission", "ridge_a", 1)
	low_oxygen_state.set("oxygen_kg", 4.0)
	simulator.call("advance_sol", low_oxygen_state)
	_assert(low_oxygen_state.get("life_support_status").get("oxygen") == "critical", "Low oxygen produces a critical life-support warning.")

	print("MissionSimulator tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
