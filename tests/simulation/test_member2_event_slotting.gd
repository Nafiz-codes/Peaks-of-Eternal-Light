extends SceneTree

const MissionSimulator = preload("res://src/simulation/mission_simulator.gd")
const MissionSave = preload("res://src/runtime/mission_save.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var simulator := MissionSimulator.new()
	check(simulator.load_contracts() == OK, "Event and resource contracts load.")
	check(simulator.events.size() == 21, "All twenty-one authored events are available to the runtime.")

	var state: Object = simulator.begin_mission("ridge_a", 10)
	var initial_radiation: float = state.radiation_msv
	check(_resolve(simulator, state, "solar_particle_event", "shelter_now"), "Shelter choice resolves.")
	check(is_equal_approx(state.radiation_msv, initial_radiation + 0.45), "Shelter choice applies the authored low radiation outcome.")

	state = simulator.begin_mission("ridge_a", 10)
	var initial_stress: float = state.crew_stress_avg
	check(_resolve(simulator, state, "solar_particle_event", "keep_working"), "Keep-working choice resolves.")
	check(is_equal_approx(state.radiation_msv, 1.8) and is_equal_approx(state.crew_stress_avg, initial_stress + 0.1), "Keep-working choice applies authored radiation and stress outcomes.")

	state = simulator.begin_mission("ridge_a", 10)
	check(_resolve(simulator, state, "volatile_prospect_detected", "mark_for_later"), "Prospect choice resolves.")
	check(state.volatile_prospect_status == "deferred", "Prospect choice uses the authored status value.")
	var full_event_table: Array[Dictionary] = simulator.events.duplicate(true)
	state = simulator.begin_mission("ridge_a", 10)
	state.volatile_prospect_found = true
	state.volatile_prospect_status = "uninvestigated"
	state.last_rover_action = "survey"
	simulator.events = [_event(simulator, "volatile_prospect_detected")]
	simulator.call("_evaluate_event_triggers", state)
	check(not state.pending_events.is_empty() and state.pending_events[0].event_id == "volatile_prospect_detected", "A successfully found, uninvestigated survey prospect can trigger its decision event.")
	check(_resolve(simulator, state, "volatile_prospect_detected", "investigate_prospect"), "Prospect investigation choice resolves.")
	check(state.volatile_prospect_found and state.volatile_prospect_status == "uninvestigated" and state.last_rover_action == "prospecting", "Scheduling prospecting preserves the default found prospect state.")
	simulator.events = full_event_table

	state = simulator.begin_mission("ridge_a", 10)
	initial_stress = state.crew_stress_avg
	check(_resolve(simulator, state, "water_recycler_clog", "service_recycler"), "Recycler-service choice resolves.")
	check(is_equal_approx(state.crew_stress_avg, initial_stress + 0.03), "Recycler-service choice applies its authored stress cost.")

	state = simulator.begin_mission("ridge_a", 10)
	var initial_power: float = state.power_kwh
	check(_resolve(simulator, state, "extended_illumination_window", "charge_reserves"), "Charge-reserves choice resolves.")
	check(is_equal_approx(state.power_kwh, initial_power + 10.0), "Charge-reserves choice applies its authored battery bonus.")

	state = simulator.begin_mission("ridge_a", 10)
	var initial_materials: float = state.materials
	initial_stress = state.crew_stress_avg
	check(_resolve(simulator, state, "extended_illumination_window", "run_high_draw_task"), "High-draw choice resolves.")
	check(is_equal_approx(state.materials, initial_materials + 8.0) and is_equal_approx(state.crew_stress_avg, initial_stress + 0.02), "High-draw choice applies authored materials and stress outcomes.")

	state = simulator.begin_mission("ridge_a", 10)
	initial_power = state.power_kwh
	check(_resolve(simulator, state, "greenhouse_nutrient_imbalance", "recalibrate_nutrients"), "Nutrient recalibration resolves.")
	check(is_equal_approx(state.power_kwh, initial_power - 8.0), "Nutrient recalibration applies its authored power cost.")

	state = simulator.begin_mission("ridge_a", 10)
	initial_stress = state.crew_stress_avg
	check(_resolve(simulator, state, "radiation_shelter_drill", "run_drill"), "Shelter-drill choice resolves.")
	check(is_equal_approx(state.crew_stress_avg, initial_stress + 0.01), "Shelter-drill choice applies its authored stress cost.")

	state = simulator.begin_mission("ridge_a", 10)
	check(_resolve(simulator, state, "prospect_confirmation", "flag_extraction_candidate"), "Prospect-confirmation choice resolves.")
	check(state.volatile_prospect_status == "extraction_candidate", "Prospect-confirmation choice applies its authored status.")

	state = simulator.begin_mission("ridge_a", 10)
	initial_materials = state.materials
	check(_resolve(simulator, state, "resupply_window"), "Automatic resupply resolves.")
	check(is_equal_approx(state.materials, initial_materials + 30.0), "Automatic resupply applies its authored materials grant.")

	state = simulator.begin_mission("ridge_a", 10)
	check(_resolve(simulator, state, "regolith_stockpile", "stockpile_regolith"), "Regolith stockpile choice resolves.")
	check(state.shielding_wall_material_discount == 20.0, "Regolith opportunity stores its shielding-wall discount.")
	var wall_discount := simulator.queue_construction(state, "shielding_wall")
	check(wall_discount.ok and wall_discount.materials_cost == 35.0, "The stored stockpile discount is applied to the later shielding-wall build.")
	state = simulator.begin_mission("ridge_a", 10)
	check(_resolve(simulator, state, "regolith_stockpile", "continue_survey"), "Continue-survey choice resolves.")
	check(state.shielding_wall_material_discount == 0.0, "Declining to stockpile does not grant the default discount.")

	state = simulator.begin_mission("ridge_a", 10)
	state.built_structures["habitat_module"] = 0
	state.built_structures["solar_array"] = 1
	simulator.call("_apply_event_effects", state, "equipment_malfunction", {"structural_damage": true, "affected_structure": "solar_array"})
	check(state.damaged_structures.has("solar_array") and not state.damaged_structures.has("habitat_module"), "Structural damage honors the authored target.")
	state.damaged_structures.clear()
	simulator.call("_apply_event_effects", state, "equipment_malfunction", {"structural_damage": true, "affected_structure": "random"})
	var first_random_target: String = state.damaged_structures.keys()[0]
	state.damaged_structures.clear()
	simulator.call("_apply_event_effects", state, "equipment_malfunction", {"structural_damage": true, "affected_structure": "random"})
	check(state.damaged_structures.keys()[0] == first_random_target, "Random structure damage is deterministic for the mission event.")

	state = simulator.begin_mission("ridge_a", 10)
	var old_state_data: Dictionary = MissionSave.state_data(state)
	old_state_data.erase("shielding_wall_material_discount")
	var decoded := MissionSave.decode({"version": 1, "site_id": "ridge_a", "state": old_state_data, "pose": {}, "last_tick": {}})
	check(not decoded.is_empty() and decoded.state.shielding_wall_material_discount == 0.0, "Existing version-one saves default the newly persisted discount to zero.")

	print("Member 2 Day 12 event slotting: %d failures; supported authored resolutions checked." % failures)
	quit(1 if failures else 0)

func _resolve(simulator: RefCounted, state: Object, event_id: String, choice_id: String = "") -> bool:
	for event in simulator.events:
		if str(event.get("event_id", "")) == event_id:
			state.pending_events.append(event.duplicate(true))
			var result: Dictionary = simulator.resolve_event_choice(state, event_id, choice_id)
			return result.get("ok", false)
	push_error("Missing authored event: " + event_id)
	return false

func _event(simulator: RefCounted, event_id: String) -> Dictionary:
	for event in simulator.events:
		if str(event.get("event_id", "")) == event_id:
			return event.duplicate(true)
	return {}
