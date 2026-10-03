extends SceneTree

const MissionSimulatorScript = preload("res://src/simulation/mission_simulator.gd")


func _init() -> void:
	var simulator := MissionSimulatorScript.new()
	_assert(simulator.call("load_contracts") == OK, "All five resource contracts should load.")
	_assert(simulator.get("sites").size() == 4, "The starter site contract should expose four sites.")
	_assert(simulator.get("crew").size() == 4, "The starter crew contract should expose four members.")
	_assert(simulator.get("events").size() == 19, "The completed event contract should expose nineteen events.")
	for site in simulator.get("sites"):
		_assert(not site.get("illumination_pct", {}).get("verified", true), "Modeled illumination must remain explicitly unverified.")
		_assert(site.get("elevation_m", {}).get("verified", false), "Every selected site has verified elevation data.")
		_assert(site.get("slope_deg", {}).get("verified", false), "Every selected site has verified slope data.")
		_assert(site.get("hydrogen_ppm", {}).get("available", true) == false, "Polar LEND hydrogen must be unavailable at these nonpolar sites.")

	var state: Object = simulator.call("begin_mission", "ridge_a", 2)
	_assert(state.get("sol") == 0, "A new mission starts at sol zero.")
	_assert(state.get("crew_size") == 4, "Mission crew size comes from bvad_constants.json.")

	var first_tick: Dictionary = simulator.call("advance_sol", state)
	_assert(state.get("sol") == 1, "A sol tick increments the mission clock exactly once.")
	_assert(not first_tick.get("completed", true), "A two-sol mission is not complete after its first tick.")
	_assert(is_equal_approx(state.get("power_generated_kwh"), 32.5), "Ridge A solar generation uses the disclosed 50% ideal-horizon model.")
	_assert(is_equal_approx(state.get("power_consumed_kwh"), 48.0), "Baseline power consumption uses crew size and the contract value.")
	_assert(is_equal_approx(state.get("power_kwh"), 104.5), "The battery reserve receives the sol power balance.")
	_assert(state.get("radiation_this_sol_msv") > 0.0, "Every sol adds a positive radiation dose.")
	_assert(state.get("radiation_this_sol_msv") > 0.80 and state.get("radiation_this_sol_msv") < 0.90, "Radiation uses the NASA lunar-surface baseline and terrain proxy.")
	_assert(state.get("terrain_shielding_factor") > 0.0, "Terrain fields produce a shielding factor.")
	_assert(is_equal_approx(state.get("water_consumed_l"), 10.0), "Water use follows the verified BVAD nominal potable-water value for all crew.")
	_assert(is_equal_approx(state.get("water_recovered_l"), 9.0), "Water recovery uses the explicitly provisional contract recycling rate.")
	_assert(is_equal_approx(state.get("water_l"), 399.0), "The reserve reflects water use and recovery.")
	_assert(is_equal_approx(state.get("oxygen_consumed_kg"), 3.264), "Oxygen use follows the verified BVAD nominal daily value.")
	_assert(is_equal_approx(state.get("food_consumed_kg"), 2.468), "Food use follows the verified BVAD nominal dry-food value.")
	_assert(first_tick.get("life_support").get("model_status") == "nasa_bvad_consumption_with_iss_eclss_recovery_proxy", "Life-support output identifies the NASA BVAD inputs and ISS ECLSS recovery proxy.")
	_assert(state.get("life_support_status").get("oxygen") == "nominal", "Life support status is available to presentation code.")
	_assert(first_tick.get("outcome").get("status") == "in_progress", "A mission remains in progress while its objective is unfinished.")

	var second_tick: Dictionary = simulator.call("advance_sol", state)
	_assert(second_tick.get("completed", false), "A two-sol mission completes after its second tick.")
	_assert(second_tick.get("outcome").get("status") == "success", "A mission that reaches its final sol with reserves succeeds.")
	_assert(state.get("history").size() == 3, "History includes the initial state and each completed tick.")

	var low_oxygen_state: Object = simulator.call("begin_mission", "ridge_a", 1)
	low_oxygen_state.set("oxygen_kg", 4.0)
	simulator.call("advance_sol", low_oxygen_state)
	_assert(low_oxygen_state.get("life_support_status").get("oxygen") == "critical", "Low oxygen produces a critical life-support warning.")

	var water_failure_state: Object = simulator.call("begin_mission", "ridge_a", 2)
	water_failure_state.set("water_l", 0.0)
	var water_failure_tick: Dictionary = simulator.call("advance_sol", water_failure_state)
	_assert(water_failure_tick.get("outcome").get("status") == "failure", "A depleted water reserve fails the mission.")
	_assert(water_failure_tick.get("outcome").get("failure_reason") == "water_depleted", "The outcome records why the mission failed.")

	var power_failure_state: Object = simulator.call("begin_mission", "shadow_zone", 5)
	power_failure_state.set("power_kwh", 0.0)
	power_failure_state.set("active_events", [{"event_id": "power_shutdown", "effects": {"power_generation_multiplier": 0.0}}])
	for _tick in range(4):
		simulator.call("advance_sol", power_failure_state)
	_assert(power_failure_state.get("mission_outcome").get("status") == "failure", "Two consecutive sols with an empty battery fail the mission.")
	_assert(power_failure_state.get("mission_outcome").get("failure_reason") == "sustained_power_depletion", "The outcome distinguishes sustained power loss from a warning.")

	for site in simulator.get("sites"):
		_run_full_mission(simulator, str(site.get("site_id", "")))

	print("MissionSimulator tests passed.")
	quit(0)


func _run_full_mission(simulator: Object, site_id: String) -> void:
	const MISSION_LENGTH := 10
	var state: Object = simulator.call("begin_mission", site_id, MISSION_LENGTH)
	_assert(state.get("site_id") == site_id, "A mission preserves its selected site identifier.")
	_assert(state.get("history").size() == 1, "A new mission records one initial snapshot.")

	for expected_sol in range(1, MISSION_LENGTH + 1):
		var tick: Dictionary = simulator.call("advance_sol", state)
		_assert(state.get("sol") == expected_sol, "%s advances exactly one sol per tick." % site_id)
		_assert(tick.get("state") == state, "%s returns the authoritative state object." % site_id)
		_assert(tick.has("power") and tick.has("radiation") and tick.has("life_support") and tick.has("outcome"), "%s keeps the shared tick interface available." % site_id)
		_assert(tick.get("radiation").get("model_status") == "nasa_lunar_surface_gcr_baseline_with_terrain_proxy", "%s retains the documented radiation model status." % site_id)
		_assert(state.get("history").size() == expected_sol + 1, "%s records every sol in its history." % site_id)
		_assert(state.get("power_kwh") >= 0.0 and state.get("water_l") >= 0.0, "%s never creates negative reserves." % site_id)
		_assert(state.get("oxygen_kg") >= 0.0 and state.get("food_kg") >= 0.0, "%s never creates negative life-support reserves." % site_id)
		_assert(state.get("radiation_this_sol_msv") > 0.0 and state.get("radiation_msv") > 0.0, "%s accumulates a positive lunar radiation dose." % site_id)
		_assert(tick.get("completed", false) == (expected_sol == MISSION_LENGTH), "%s reports completion only on its final sol." % site_id)
		while not state.get("pending_events").is_empty():
			var pending: Dictionary = state.get("pending_events")[0]
			var choices: Array = pending.get("choices", [])
			var choice_id := ""
			if not choices.is_empty():
				choice_id = str(choices[0].get("choice_id", ""))
			var resolution: Dictionary = simulator.call("resolve_event_choice", state, str(pending.get("event_id", "")), choice_id)
			_assert(resolution.get("ok", false), "%s resolves triggered event choices through the simulator." % site_id)

	_assert(state.get("mission_outcome").get("status") == "failure", "%s reports the current baseline life-support or power failure before Sol 10." % site_id)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
