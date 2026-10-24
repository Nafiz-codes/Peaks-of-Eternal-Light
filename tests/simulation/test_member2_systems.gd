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
	check(is_equal_approx(state.crew_productivity, 1.086), "Crew productivity is the average of the authored crew values.")

	var solar := simulator.queue_construction(state, "solar_array")
	check(solar.ok, "A structure can be queued when its authored costs are affordable.")
	check(is_equal_approx(state.materials, 145.0) and is_equal_approx(state.power_kwh, 282.0), "Construction pays the authored material and power cost once.")
	simulator.advance_sol(state)
	check(not state.built_structures.has("solar_array"), "A two-sol authored build does not complete in one sol.")
	simulator.advance_sol(state)
	check(state.built_structures.has("solar_array"), "Construction completes using aggregate crew productivity.")
	check(is_equal_approx(state.power_generated_kwh, 41.5), "A completed solar array adds its authored 18 kWh potential generation before illumination.")
	check(not simulator.queue_construction(state, "solar_array").ok, "Completed structures cannot be queued twice.")

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
	check(is_equal_approx(extractor_state.water_recovered_l, 27.25), "An extraction candidate plus extractor adds the authored 16 L/sol recovery output.")

	var greenhouse_state: Object = simulator.begin_mission("ridge_a", 20)
	check(simulator.queue_construction(greenhouse_state, "greenhouse").ok, "The greenhouse can be constructed.")
	for _step in range(3):
		simulator.advance_sol(greenhouse_state)
	check(greenhouse_state.built_structures.has("greenhouse"), "The authored greenhouse build completes.")
	check(is_equal_approx(greenhouse_state.food_consumed_kg, 1.885), "The greenhouse offsets food draw by its authored 1.2 kg/sol output.")

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
