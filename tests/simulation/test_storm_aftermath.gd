extends SceneTree
## After the dust storm: aftermath stages, storm damage, reduced output and repair.
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const Rules = preload("res://src/simulation/rover_expedition.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	# Stages: nothing before the storm ends, then briefing -> repairs -> alert -> done.
	var data := Rules.fresh()
	check(Rules.aftermath(data) == "", "No aftermath before the storm")
	data.completed = [0, 1]
	check(Rules.aftermath(data) == "", "No aftermath while the storm is still pending")
	data["dust_storm_complete"] = true
	check(Rules.aftermath(data) == "briefing", "Maya's damage briefing follows the storm")
	for stage in ["repairs", "alert", "done"]:
		data["aftermath"] = stage
		check(Rules.aftermath(data) == stage and Rules.valid_save(data), "Stage %s is kept and saves" % stage)
	data["aftermath"] = "nonsense"
	check(not Rules.valid_save(data), "Unknown stages are rejected in saves")
	data["aftermath"] = "done"
	data.mission = 2
	check(Rules.aftermath(data) == "", "No aftermath once Lifeline is under way")

	var simulator := Simulator.new()
	check(simulator.load_contracts() == OK, "Contracts load")
	var state: Variant = simulator.begin_mission("ridge_a")
	check(simulator.apply_storm_damage(state).is_empty(), "Nothing to damage on an empty outpost")
	state.placed_panel_kwh_per_sol = 40.0
	state.built_structures["greenhouse"] = 0
	state.built_structures["water_extractor"] = 0
	state.built_structures["comms_relay"] = 0
	var damaged: Array = simulator.apply_storm_damage(state)
	check(damaged.size() >= 1 and damaged.size() <= 3, "The storm damages one to three structures")
	for id in damaged:
		check(id in ["solar_panel", "greenhouse", "water_extractor"] and state.damaged_structures.has(id), "Only working structures that exist are damaged")

	# A damaged structure keeps a share of its output; repairing restores all of it.
	state.damaged_structures = {"solar_panel": true, "greenhouse": true}
	var site: Dictionary = simulator._find_site("ridge_a")
	var hurt: float = simulator._calculate_power(state, site).generated_kwh
	var hungry: float = simulator._calculate_life_support(state).food_consumed_kg
	check(simulator.repair_structure(state, "solar_panel") and simulator.repair_structure(state, "greenhouse"), "Damaged structures can be repaired")
	check(not simulator.repair_structure(state, "solar_panel"), "Repairing an undamaged structure does nothing")
	var healthy: float = simulator._calculate_power(state, site).generated_kwh
	check(is_equal_approx(healthy - hurt, 40.0 * (1.0 - Simulator.DAMAGED_OUTPUT_SHARE)), "A damaged panel gives only its reduced share")
	check(simulator._calculate_life_support(state).food_consumed_kg < hungry, "A repaired greenhouse grows more food again")

	print("STORM AFTERMATH: %d failures" % failures)
	quit(failures)
