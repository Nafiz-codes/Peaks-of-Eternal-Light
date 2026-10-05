extends SceneTree

const MissionSimulator = preload("res://src/simulation/mission_simulator.gd")

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
	check(simulator.events.size() == 19, "All nineteen authored events are available to the runtime.")

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
