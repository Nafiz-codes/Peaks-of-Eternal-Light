extends SceneTree

const MissionSimulator = preload("res://src/simulation/mission_simulator.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulator := MissionSimulator.new()
	check(simulator.load_contracts() == OK, "Member 2 contracts load.")
	var solar_particle := _event(simulator, "solar_particle_event")
	simulator.events.clear()
	var state: Object = simulator.begin_mission("ridge_a", 20)
	check(is_equal_approx(state.crew_productivity, 1.095), "Crew productivity is the average of the authored four-person crew values.")

	var solar := simulator.queue_construction(state, "solar_array")
	check(solar.ok, "A structure can be queued when its authored costs are affordable.")
	check(is_equal_approx(state.power_kwh, MissionSimulator.INITIAL_POWER_KWH - 8.0) and is_equal_approx(state.water_l, MissionSimulator.INITIAL_WATER_L - 4.0) and is_equal_approx(state.oxygen_kg, MissionSimulator.INITIAL_OXYGEN_KG - 0.8) and is_equal_approx(state.food_kg, MissionSimulator.INITIAL_FOOD_KG - 0.5), "Construction pays its power and the crew's water, oxygen and food once.")
	simulator.advance_sol(state)
	check(not state.built_structures.has("solar_array"), "A two-sol authored build does not complete in one sol.")
	simulator.advance_sol(state)
	check(state.built_structures.has("solar_array"), "Construction completes using aggregate crew productivity.")
	# Same sols without the array: the difference is the array's rating scaled by the same sunlight.
	var unbuilt: Object = simulator.begin_mission("ridge_a", 20)
	simulator.advance_sol(unbuilt)
	simulator.advance_sol(unbuilt)
	var sunlight: float = unbuilt.power_generated_kwh / simulator.BASE_SOLAR_GENERATION_KWH_PER_SOL
	check(is_equal_approx(state.power_generated_kwh - unbuilt.power_generated_kwh, simulator.SOLAR_ARRAY_GENERATION_KWH_PER_SOL * sunlight), "A completed solar array adds its authored generation, scaled by the same sunlight.")
	check(not simulator.queue_construction(state, "solar_array").ok, "Completed structures cannot be queued twice.")
	var water_before: float = state.water_l
	check(simulator.demolish_structure(state, "solar_array").ok and not state.built_structures.has("solar_array"), "A built structure can be deleted.")
	check(is_equal_approx(state.water_l, water_before + 4.0), "Deleting refunds what was used to build it.")
	check(simulator.demolish_structure(state, "solar_array").error == "structure_not_built", "Only built structures can be deleted.")
	check(simulator.queue_construction(state, "solar_array").ok, "A deleted structure can be rebuilt.")
	var clear_sky: Object = simulator.begin_mission("ridge_a", 20)
	var storm_sky: Object = simulator.begin_mission("ridge_a", 20)
	clear_sky.placed_panel_kwh_per_sol = 10.0
	storm_sky.placed_panel_kwh_per_sol = 10.0
	check(simulator.apply_dust_storm(storm_sky) and not simulator.apply_dust_storm(storm_sky), "A dust storm is charged once per sol.")
	simulator.advance_sol(clear_sky)
	simulator.advance_sol(storm_sky)
	check(is_equal_approx(storm_sky.power_generated_kwh, clear_sky.power_generated_kwh * simulator.DUST_STORM_LIGHT_MULTIPLIER), "A dust storm cuts all solar generation, including the placed panel, for that sol.")
	simulator.advance_sol(clear_sky)
	simulator.advance_sol(storm_sky)
	check(is_equal_approx(storm_sky.power_generated_kwh, clear_sky.power_generated_kwh), "Sunlight returns the sol after the storm.")
	var without_panel: Object = simulator.begin_mission("ridge_a", 20)
	var with_panel: Object = simulator.begin_mission("ridge_a", 20)
	with_panel.placed_panel_kwh_per_sol = 4.3
	for sol in range(3):
		simulator.advance_sol(without_panel)
		simulator.advance_sol(with_panel)
		check(is_equal_approx(with_panel.power_generated_kwh - without_panel.power_generated_kwh, 4.3), "The placed panel adds exactly its shown kWh every sol.")

	var rover_state: Object = simulator.begin_mission("ridge_a", 20)
	var survey := simulator.dispatch_rover(rover_state, "survey", 6.0)
	check(survey.ok and is_equal_approx(survey.power_cost_kwh, 3.3), "A six-kilometre rover survey pays the authored 0.55 kWh/km cost.")
	check(not simulator.dispatch_rover(rover_state, "traverse", 0.1).ok, "Rover movement respects the authored per-sol distance cap.")
	simulator.advance_sol(rover_state)
	check(simulator.dispatch_rover(rover_state, "traverse", 1.0).ok, "The rover distance allowance resets on the next sol.")

	var extractor_state: Object = simulator.begin_mission("ridge_a", 20)
	extractor_state.volatile_prospect_found = true
	extractor_state.volatile_prospect_status = "extraction_candidate"
	check(simulator.queue_construction(extractor_state, "water_extractor").ok, "The water extractor can be constructed.")
	for _step in range(3):
		simulator.advance_sol(extractor_state)
	check(extractor_state.built_structures.has("water_extractor"), "The authored three-sol extractor build completes.")
	check(is_equal_approx(extractor_state.water_recovered_l, 25.0), "An extraction candidate plus extractor adds the authored 16 L/sol recovery output.")

	var greenhouse_state: Object = simulator.begin_mission("ridge_a", 20)
	check(simulator.queue_construction(greenhouse_state, "greenhouse").ok, "The greenhouse can be constructed.")
	for _step in range(3):
		simulator.advance_sol(greenhouse_state)
	check(greenhouse_state.built_structures.has("greenhouse"), "The authored greenhouse build completes.")
	check(is_equal_approx(greenhouse_state.food_consumed_kg, 1.268), "The greenhouse offsets food draw by its authored 1.2 kg/sol output.")

	var effects_state: Object = simulator.begin_mission("ridge_a", 200)
	effects_state.active_events.append({"event_id": "thermal", "effects": {"battery_available_capacity_multiplier": 0.8}, "remaining_sols": 2, "started_sol": effects_state.sol})
	effects_state.power_kwh = 290.0
	simulator.advance_sol(effects_state)
	check(effects_state.power_kwh <= 240.0, "Battery-capacity effects constrain stored energy.")
	effects_state.active_events.clear()
	effects_state.event_warning_disabled = true
	effects_state.triggered_event_ids.clear()
	simulator.events = [solar_particle]
	for sol in range(1, 101):
		effects_state.sol = sol
		simulator.call("_evaluate_event_triggers", effects_state)
		if effects_state.triggered_event_ids.has("solar_particle_event"):
			break
	check(effects_state.pending_events.is_empty() and effects_state.triggered_event_ids.has("solar_particle_event") and effects_state.resolved_events.back().choice_id == "unwarned_automatic", "A communications blackout removes the solar-particle warning choice.")

	print("Member 2 systems: %d failures; construction, rover, crew, and event handlers checked." % failures)
	quit(1 if failures else 0)


func _event(simulator: Object, event_id: String) -> Dictionary:
	for event in simulator.events:
		if str(event.get("event_id", "")) == event_id:
			return event.duplicate(true)
	return {}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
