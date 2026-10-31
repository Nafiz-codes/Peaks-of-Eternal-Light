class_name MissionSimulator
extends RefCounted

## Deterministic simulation entry point. Resource outcomes are calculated here,
## never in the UI.

const SITES_PATH := "res://Resources/sites.json"
const BVAD_PATH := "res://Resources/bvad_constants.json"
const CREW_PATH := "res://Resources/crew.json"
const CONSTRUCTION_PATH := "res://Resources/construction.json"
const EVENTS_PATH := "res://Resources/events.json"
const MissionStateScript = preload("res://src/simulation/mission_state.gd")
const PolarSolar = preload("res://src/simulation/polar_solar.gd")

# Five-person provisioning: retain the previous ten-sol reserve margin while
# accounting for the player (12 kWh/sol extra baseline, 25% more consumables).
const INITIAL_POWER_KWH := 290.0
const INITIAL_WATER_L := 500.0
const INITIAL_OXYGEN_KG := 56.25
const INITIAL_FOOD_KG := 37.5
const INITIAL_MATERIALS := 180.0
const BATTERY_CAPACITY_KWH := 300.0

## NASA NESC Table 8.4-2: unshielded lunar-surface GCR effective dose during
## the 2009 solar minimum. CRaTER supplies the observational radiation context;
## this site-independent modeled value is not a geographic CRaTER reading.
const LUNAR_SURFACE_GCR_MSV_PER_SOL := 0.90
## Member 2's construction contract: the completed shielding wall reduces
## remaining crew dose by 25%; when combined with terrain this applies to the
## dose left after the terrain proxy (multiplicative stacking).
const SHIELDING_WALL_DOSE_MULTIPLIER := 0.75
## Terrain has no direct local dose measurement in the selected products. These
## documented gameplay weights turn LOLA topography into a bounded sky-view proxy.
const TERRAIN_DEPTH_REFERENCE_M := 2500.0
const TERRAIN_SLOPE_REFERENCE_DEG := 30.0
const TERRAIN_DEPTH_WEIGHT := 0.12
const TERRAIN_SLOPE_WEIGHT := 0.08
const BASE_SOLAR_GENERATION_KWH_PER_SOL := 65.0
const SOLAR_ARRAY_GENERATION_KWH_PER_SOL := 18.0

var sites: Array[Dictionary] = []
var bvad_constants: Dictionary = {}
var crew: Array[Dictionary] = []
var construction: Dictionary = {}
var events: Array[Dictionary] = []


func load_contracts() -> Error:
	var sites_document := _read_json(SITES_PATH)
	var bvad_document := _read_json(BVAD_PATH)
	var crew_document := _read_json(CREW_PATH)
	var construction_document := _read_json(CONSTRUCTION_PATH)
	var events_document := _read_json(EVENTS_PATH)

	if sites_document.is_empty() or bvad_document.is_empty() or crew_document.is_empty() or construction_document.is_empty() or events_document.is_empty():
		return ERR_FILE_CANT_READ

	sites = _dictionary_array(sites_document.get("sites", []))
	bvad_constants = bvad_document
	crew = _dictionary_array(crew_document.get("crew", []))
	construction = construction_document
	events = _dictionary_array(events_document.get("events", []))

	if sites.is_empty() or crew.is_empty() or events.is_empty():
		return ERR_INVALID_DATA
	return OK


func begin_mission(selected_site_id: String, mission_length: int = 7) -> Variant:
	assert(not sites.is_empty(), "Call load_contracts() before begin_mission().")
	assert(_find_site(selected_site_id) != null, "Unknown site_id: %s" % selected_site_id)

	var state := MissionStateScript.new()
	state.site_id = selected_site_id
	state.mission_length_sols = mission_length
	state.crew_size = int(bvad_constants.get("crew_size", crew.size()))
	state.power_kwh = INITIAL_POWER_KWH
	state.water_l = INITIAL_WATER_L
	state.oxygen_kg = INITIAL_OXYGEN_KG
	state.food_kg = INITIAL_FOOD_KG
	state.materials = INITIAL_MATERIALS
	state.crew_productivity = _crew_productivity_baseline()
	state.terrain_shielding_factor = _terrain_shielding_factor(_find_site(selected_site_id))
	state.life_support_status = _life_support_status(state, 0.0, 0.0, 0.0)
	state.mission_outcome = _evaluate_mission_outcome(state)
	_update_report_data(state)
	state.history.append(state.snapshot())
	return state


func advance_sol(state: Variant) -> Dictionary:
	assert(state != null, "A MissionState is required.")
	assert(state.pending_events.is_empty(), "Resolve pending event decisions before advancing the mission.")
	assert(state.sol < state.mission_length_sols, "The mission has already ended.")

	state.sol += 1
	state.rover_distance_this_sol_km = 0.0
	_advance_construction(state)
	var site: Dictionary = _find_site(state.site_id)
	var power_tick: Dictionary = _calculate_power(state, site)
	state.power_generated_kwh = power_tick.generated_kwh
	state.power_consumed_kwh = power_tick.consumed_kwh
	state.power_balance_kwh = power_tick.balance_kwh
	state.power_kwh = clampf(state.power_kwh + state.power_balance_kwh, 0.0, _battery_capacity(state))

	state.terrain_shielding_factor = _terrain_shielding_factor(site)
	var structural_dose_multiplier := SHIELDING_WALL_DOSE_MULTIPLIER if state.built_structures.has("shielding_wall") else 1.0
	state.radiation_this_sol_msv = LUNAR_SURFACE_GCR_MSV_PER_SOL * (1.0 - state.terrain_shielding_factor) * structural_dose_multiplier
	state.radiation_msv += state.radiation_this_sol_msv

	var life_support_tick: Dictionary = _calculate_life_support(state)
	state.water_consumed_l = life_support_tick.water_consumed_l
	state.water_recovered_l = life_support_tick.water_recovered_l
	state.water_balance_l = life_support_tick.water_balance_l
	state.water_l = maxf(0.0, state.water_l + state.water_balance_l)
	state.oxygen_consumed_kg = life_support_tick.oxygen_consumed_kg
	state.oxygen_kg = maxf(0.0, state.oxygen_kg - state.oxygen_consumed_kg)
	state.food_consumed_kg = life_support_tick.food_consumed_kg
	state.food_kg = maxf(0.0, state.food_kg - state.food_consumed_kg)
	state.life_support_status = _life_support_status(state, -state.water_balance_l, state.oxygen_consumed_kg, state.food_consumed_kg)
	state.consecutive_power_depleted_sols = state.consecutive_power_depleted_sols + 1 if state.power_kwh <= 0.0 else 0
	_evaluate_event_triggers(state)
	_expire_effects(state)
	state.mission_outcome = _evaluate_mission_outcome(state)
	_update_report_data(state)
	state.history.append(state.snapshot())
	return {
		"state": state,
		"completed": state.sol >= state.mission_length_sols,
		"power": power_tick,
		"radiation": {
			"dose_this_sol_msv": state.radiation_this_sol_msv,
			"terrain_shielding_factor": state.terrain_shielding_factor,
			"built_structure_dose_multiplier": structural_dose_multiplier,
			"model_status": "nasa_lunar_surface_gcr_baseline_with_terrain_proxy"
		},
		"life_support": life_support_tick,
		"active_events": state.active_events.duplicate(true),
		"pending_events": state.pending_events.duplicate(true),
		"outcome": state.mission_outcome.duplicate(true)
	}


func resolve_event_choice(state: Variant, event_id: String, choice_id: String = "") -> Dictionary:
	if state == null:
		return {"ok": false, "error": "missing_mission_state"}
	for index in range(state.pending_events.size()):
		var event: Dictionary = state.pending_events[index]
		if str(event.get("event_id", "")) != event_id:
			continue
		# Event-level effects describe the default outcome; a selected choice
		# overrides only the keys it specifies. This preserves shared duration,
		# hazard, and discovery effects while allowing choices to mitigate them.
		var selected_effects: Dictionary = event.get("effects", {}).duplicate(true)
		if event.get("choices") is Array and not event.choices.is_empty():
			var found_choice := false
			for choice in event.choices:
				if str(choice.get("choice_id", "")) == choice_id:
					var choice_effects: Dictionary = choice.get("effects", {})
					for key in choice_effects:
						selected_effects[key] = choice_effects[key]
					found_choice = true
					break
			if not found_choice:
				return {"ok": false, "error": "unknown_choice"}
		_apply_event_effects(state, event_id, selected_effects)
		state.pending_events.remove_at(index)
		state.resolved_events.append({"event_id": event_id, "choice_id": choice_id, "sol": state.sol})
		# Choices can change reserves between ticks; publish current statuses/report.
		state.life_support_status = _life_support_status(state, maxf(0.0, -state.water_balance_l), state.oxygen_consumed_kg, state.food_consumed_kg)
		state.mission_outcome = _evaluate_mission_outcome(state)
		_update_report_data(state)
		if not state.history.is_empty():
			state.history[state.history.size() - 1] = state.snapshot()
		return {"ok": true, "state": state, "event_id": event_id, "choice_id": choice_id}
	return {"ok": false, "error": "event_not_pending"}


func queue_construction(state: Variant, structure_id: String) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "missing_mission_state"}
	if state.mission_outcome.get("status", "") != "in_progress" or not state.pending_events.is_empty():
		return {"ok": false, "error": "mission_not_ready"}
	if state.built_structures.has(structure_id) or _construction_is_queued(state, structure_id):
		return {"ok": false, "error": "structure_already_started"}
	var structure := _find_structure(structure_id)
	if structure.is_empty():
		return {"ok": false, "error": "unknown_structure"}
	var cost: Dictionary = structure.get("build_cost", {})
	var materials_cost := maxf(0.0, float(cost.get("materials", 0.0)) - _structure_material_discount(state, structure_id))
	var power_cost := float(cost.get("power", 0.0))
	if state.materials < materials_cost:
		return {"ok": false, "error": "insufficient_materials"}
	if state.power_kwh < power_cost:
		return {"ok": false, "error": "insufficient_power"}
	state.materials -= materials_cost
	state.power_kwh -= power_cost
	state.construction_queue.append({"structure_id": structure_id, "remaining_work": float(structure.get("build_time_sols", 1)), "started_sol": state.sol})
	_publish_action_state(state)
	return {"ok": true, "structure_id": structure_id, "materials_cost": materials_cost, "power_cost": power_cost}


func dispatch_rover(state: Variant, action_id: String, distance_km: float) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "missing_mission_state"}
	if state.mission_outcome.get("status", "") != "in_progress" or not state.pending_events.is_empty():
		return {"ok": false, "error": "mission_not_ready"}
	if action_id not in ["traverse", "survey", "prospecting", "return", "haul_regolith"] or not is_finite(distance_km) or distance_km <= 0.0:
		return {"ok": false, "error": "invalid_rover_action"}
	var rover: Dictionary = construction.get("vehicles", {}).get("rover", {})
	var range := float(rover.get("max_distance_per_sol_km", 0.0)) * _active_effect_multiplier_for(state.active_events, "rover_range_multiplier")
	if distance_km > range - state.rover_distance_this_sol_km:
		return {"ok": false, "error": "rover_range_exceeded"}
	var energy_cost := distance_km * float(rover.get("move_cost_power_per_km", 0.0)) * _active_effect_multiplier_for(state.active_events, "rover_power_multiplier")
	if state.power_kwh < energy_cost:
		return {"ok": false, "error": "insufficient_power"}
	state.power_kwh -= energy_cost
	state.rover_distance_this_sol_km += distance_km
	state.rover_total_distance_km += distance_km
	state.last_rover_action = action_id
	if action_id in ["survey", "traverse"] and not state.volatile_prospect_found:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("rover:%s:%d:%.3f" % [state.site_id, state.sol, state.rover_total_distance_km])
		var discovery_chance := float(rover.get("discovery_chance_pct_per_km", 0.0)) * distance_km / 100.0
		if rng.randf() < discovery_chance:
			state.volatile_prospect_found = true
			state.volatile_prospect_status = "uninvestigated"
	if action_id == "prospecting" and state.volatile_prospect_found:
		state.volatile_prospect_status = "investigated"
	_publish_action_state(state)
	return {"ok": true, "action_id": action_id, "distance_km": distance_km, "power_cost_kwh": energy_cost}


func _publish_action_state(state: Variant) -> void:
	# Build and rover actions happen between sol ticks. Keep the current-sol
	# snapshot and report aligned with any immediately spent resources/state.
	state.life_support_status = _life_support_status(state, maxf(0.0, -state.water_balance_l), state.oxygen_consumed_kg, state.food_consumed_kg)
	state.mission_outcome = _evaluate_mission_outcome(state)
	_update_report_data(state)
	if not state.history.is_empty():
		state.history[state.history.size() - 1] = state.snapshot()


func _evaluate_event_triggers(state: Variant) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [state.site_id, state.sol])
	for event in events:
		var event_id := str(event.get("event_id", ""))
		if event_id.is_empty() or state.triggered_event_ids.has(event_id) or not _event_condition_met(event_id, state):
			continue
		if not _event_roll_succeeds(event_id, rng):
			continue
		state.triggered_event_ids.append(event_id)
		var runtime_event: Dictionary = event.duplicate(true)
		if event_id == "solar_particle_event" and state.event_warning_disabled:
			_apply_event_effects(state, event_id, event.get("effects", {}))
			state.resolved_events.append({"event_id": event_id, "choice_id": "unwarned_automatic", "sol": state.sol})
			break
		if event.get("choices") is Array and not event.choices.is_empty():
			state.pending_events.append(runtime_event)
		else:
			_apply_event_effects(state, event_id, event.get("effects", {}))
			state.resolved_events.append({"event_id": event_id, "choice_id": "automatic", "sol": state.sol})
		break # One new event per sol keeps authored choices legible and bounded.


func _event_condition_met(event_id: String, state: Variant) -> bool:
	var site: Dictionary = _find_site(state.site_id)
	var illumination := 100.0 * PolarSolar.daily_fraction(site, maxi(0, state.sol - 1))
	match event_id:
		"solar_array_dust_accumulation": return state.sol > 3 and _has_rover_or_eva_activity(state)
		"solar_particle_event": return true
		"volatile_prospect_detected": return state.volatile_prospect_found and state.volatile_prospect_status == "uninvestigated" and state.last_rover_action in ["survey", "traverse"]
		"equipment_malfunction": return state.sol >= 3 and not state.built_structures.is_empty()
		"crew_conflict": return state.crew_stress_avg > 0.6
		"greenhouse_bloom": return _structure_age(state, "greenhouse") >= 2
		"micrometeorite_strike": return true
		"water_recycler_clog": return state.sol > 2
		"rover_mobility_hazard": return state.last_rover_action == "traverse"
		"battery_thermal_alert": return state.power_kwh / BATTERY_CAPACITY_KWH * 100.0 < 35.0
		"regolith_stockpile": return state.last_rover_action == "survey" and not state.built_structures.has("shielding_wall")
		"extended_illumination_window": return illumination >= 50.0
		"crew_process_improvement": return state.sol >= 4 and state.crew_stress_avg < 0.45
		"comms_blackout": return not state.built_structures.has("comms_relay")
		"greenhouse_nutrient_imbalance": return _structure_age(state, "greenhouse") >= 0
		"radiation_shelter_drill": return state.sol >= 2
		"prospect_confirmation": return state.volatile_prospect_found and state.last_rover_action == "prospecting"
		"rover_sample_cache": return state.volatile_prospect_status == "investigated" and state.last_rover_action == "prospecting"
		"crew_recovery_window": return state.crew_stress_avg >= 0.5 and state.sol >= 3
		"solar_array_alignment": return state.built_structures.has("solar_array") and illumination >= 50.0
		"resupply_window": return state.sol == 5
	return false


func _event_roll_succeeds(event_id: String, rng: RandomNumberGenerator) -> bool:
	var chance_pct := 100.0
	match event_id:
		"solar_array_dust_accumulation": chance_pct = 8.0
		"solar_particle_event": chance_pct = 4.0
		"equipment_malfunction": chance_pct = 6.0
		"micrometeorite_strike": chance_pct = 3.0
		"water_recycler_clog": chance_pct = 6.0
		"rover_mobility_hazard": chance_pct = 10.0
		"battery_thermal_alert": chance_pct = 8.0
		"extended_illumination_window": chance_pct = 12.0
		"crew_process_improvement": chance_pct = 10.0
		"comms_blackout": chance_pct = 7.0
		"greenhouse_nutrient_imbalance": chance_pct = 7.0
		"radiation_shelter_drill": chance_pct = 9.0
		"solar_array_alignment": chance_pct = 10.0
	return rng.randf() * 100.0 < chance_pct


func _apply_event_effects(state: Variant, event_id: String, effects: Dictionary) -> void:
	if effects.has("materials"):
		state.materials = maxf(0.0, state.materials + _numeric_effect(effects.materials))
	if effects.has("crew_stress"):
		var stress_change := _numeric_effect(effects.crew_stress)
		if stress_change > 0.0 and state.built_structures.has("habitat_module"):
			stress_change *= 0.85
		state.crew_stress_avg = clampf(state.crew_stress_avg + stress_change, 0.0, 1.0)
	if effects.has("rover_task"):
		state.last_rover_action = str(effects.rover_task)
	if effects.has("shielding_wall_material_discount"):
		state.shielding_wall_material_discount = maxf(state.shielding_wall_material_discount, float(effects.shielding_wall_material_discount))
	if effects.has("event_warning_disabled"):
		state.event_warning_disabled = bool(effects.event_warning_disabled)
	if effects.get("structural_damage", false):
		var damaged := _choose_undamaged_structure(state, event_id, str(effects.get("affected_structure", "random")))
		if not damaged.is_empty():
			state.damaged_structures[damaged] = true
	if effects.get("volatile_prospect_found", false):
		state.volatile_prospect_found = true
		state.volatile_prospect_status = "uninvestigated"
	if effects.has("volatile_prospect_status"):
		state.volatile_prospect_status = str(effects.volatile_prospect_status)
	if effects.get("extraction_candidate_unlocked", false):
		state.volatile_prospect_status = "extraction_candidate"
	if effects.has("battery_charge_bonus_kwh"):
		state.power_kwh = minf(_battery_capacity(state), state.power_kwh + float(effects.battery_charge_bonus_kwh))
	if effects.has("power_cost_kwh"):
		state.power_kwh = maxf(0.0, state.power_kwh - float(effects.power_cost_kwh))
	if effects.has("radiation_dose_spike"):
		var spike := 0.45 if str(effects.radiation_dose_spike) == "low" else 1.8
		if str(effects.radiation_dose_spike) == "low":
			spike *= maxf(0.0, 1.0 - _active_effect_additive(state.active_events, "shelter_response_bonus"))
		state.radiation_msv += spike
		state.radiation_this_sol_msv += spike
	var duration := int(effects.get("duration_sols", 0))
	if duration > 0:
		state.active_events.append({
			"event_id": event_id,
			"effects": effects.duplicate(true),
			"remaining_sols": duration,
			"started_sol": state.sol
		})


func _expire_effects(state: Variant) -> void:
	for index in range(state.active_events.size() - 1, -1, -1):
		# Events triggered during this sol become active next sol, so do not
		# consume duration on the same sol that created the timed effect.
		if int(state.active_events[index].get("started_sol", -1)) >= state.sol:
			continue
		state.active_events[index].remaining_sols = int(state.active_events[index].get("remaining_sols", 1)) - 1
		if state.active_events[index].remaining_sols <= 0:
			state.active_events.remove_at(index)


func _numeric_effect(value: Variant) -> float:
	var text := str(value)
	if text.begins_with("+") or text.begins_with("-"):
		return float(text)
	return float(value)


func _has_rover_or_eva_activity(state: Variant) -> bool:
	return not str(state.last_rover_action).is_empty()


func _structure_age(state: Variant, structure_id: String) -> int:
	return int(state.built_structures.get(structure_id, -1000))


func _find_structure(structure_id: String) -> Dictionary:
	for structure in construction.get("structures", []):
		if structure is Dictionary and str(structure.get("structure_id", "")) == structure_id:
			return structure
	return {}


func _construction_is_queued(state: Variant, structure_id: String) -> bool:
	for item in state.construction_queue:
		if str(item.get("structure_id", "")) == structure_id:
			return true
	return false


func _advance_construction(state: Variant) -> void:
	var work_rate: float = float(state.crew_productivity) * _active_effect_multiplier_for(state.active_events, "productivity_multiplier")
	for index in range(state.construction_queue.size() - 1, -1, -1):
		var job: Dictionary = state.construction_queue[index]
		job.remaining_work = float(job.get("remaining_work", 0.0)) - work_rate
		if job.remaining_work <= 0.0:
			state.built_structures[str(job.get("structure_id", ""))] = state.sol
			state.construction_queue.remove_at(index)
		else:
			state.construction_queue[index] = job


func _structure_material_discount(state: Variant, structure_id: String) -> float:
	if structure_id != "shielding_wall":
		return 0.0
	return maxf(0.0, state.shielding_wall_material_discount)


func _choose_undamaged_structure(state: Variant, event_id: String, requested: String) -> String:
	var candidates: Array[String] = []
	for structure_id in state.built_structures:
		if not state.damaged_structures.has(structure_id):
			candidates.append(str(structure_id))
	candidates.sort()
	if candidates.is_empty():
		return ""
	if requested != "random":
		return requested if candidates.has(requested) else ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("structure_damage:%s:%d:%s" % [state.site_id, state.sol, event_id])
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _battery_capacity(state: Variant) -> float:
	return BATTERY_CAPACITY_KWH * _active_effect_multiplier_for(state.active_events, "battery_available_capacity_multiplier")


func _crew_productivity_baseline() -> float:
	if crew.is_empty():
		return 1.0
	var total := 0.0
	for member in crew:
		total += float(member.get("base_productivity", 1.0))
	return total / float(crew.size())


func _update_report_data(state: Variant) -> void:
	var history: Array = state.history
	var initial: Dictionary = history[0] if not history.is_empty() else state.snapshot()
	var depletion_reason := str(state.mission_outcome.get("failure_reason", ""))
	state.report_data = {
		"sols_survived": state.sol,
		"mission_length_sols": state.mission_length_sols,
		"survival_pct": 100.0 * float(state.sol) / maxf(1.0, float(state.mission_length_sols)),
		"failure_reason": depletion_reason,
		"failure_sol": state.mission_outcome.get("failure_sol", 0),
		"initial_reserves": {"power_kwh": initial.get("power_kwh", 0.0), "water_l": initial.get("water_l", 0.0), "oxygen_kg": initial.get("oxygen_kg", 0.0), "food_kg": initial.get("food_kg", 0.0), "materials": initial.get("materials", 0.0)},
		"final_reserves": {"power_kwh": state.power_kwh, "water_l": state.water_l, "oxygen_kg": state.oxygen_kg, "food_kg": state.food_kg, "materials": state.materials},
		"events_resolved": state.resolved_events.size(),
		"event_history": state.resolved_events.duplicate(true),
		"radiation_total_msv": state.radiation_msv,
		"volatile_prospect_status": state.volatile_prospect_status
	}


func _evaluate_mission_outcome(state: Variant) -> Dictionary:
	var existing_outcome: Dictionary = state.mission_outcome
	var failure_reason := str(existing_outcome.get("failure_reason", ""))
	if failure_reason.is_empty():
		if state.oxygen_kg <= 0.0:
			failure_reason = "oxygen_depleted"
		elif state.water_l <= 0.0:
			failure_reason = "water_depleted"
		elif state.food_kg <= 0.0:
			failure_reason = "food_depleted"
		elif state.consecutive_power_depleted_sols >= 2:
			failure_reason = "sustained_power_depletion"

	var failure_sol := int(existing_outcome.get("failure_sol", 0))
	if not failure_reason.is_empty() and failure_sol == 0:
		failure_sol = state.sol
	var mission_finished: bool = state.sol >= state.mission_length_sols
	var status := "in_progress"
	if not failure_reason.is_empty():
		status = "failure"
	elif mission_finished and state.pending_events.is_empty():
		status = "success"
	return {
		"status": status,
		"mission_finished": mission_finished,
		"failure_reason": failure_reason,
		"failure_sol": failure_sol,
		"primary_objective": "Sustain the crew through Sol %d." % state.mission_length_sols
	}


func _calculate_power(state: Variant, site: Dictionary) -> Dictionary:
	var illumination_fraction := PolarSolar.daily_fraction(site, maxi(0, state.sol - 1))
	var solar_yield := PolarSolar.daily_fraction(site, maxi(0, state.sol - 1), true)
	var active_effect_multiplier := _active_power_generation_multiplier(state.active_events)
	var solar_array_output := SOLAR_ARRAY_GENERATION_KWH_PER_SOL if state.built_structures.has("solar_array") and not state.damaged_structures.has("solar_array") else 0.0
	var generated_kwh := (BASE_SOLAR_GENERATION_KWH_PER_SOL + solar_array_output) * solar_yield * active_effect_multiplier * _active_effect_multiplier_for(state.active_events, "output_multiplier")
	var baseline_kw_per_person := _field_value(bvad_constants, "power_baseline_kw_per_person")
	var consumed_kwh := baseline_kw_per_person * float(state.crew_size) * 24.0 * _active_effect_multiplier_for(state.active_events, "power_consumption_multiplier")
	return {
		"generated_kwh": generated_kwh,
		"consumed_kwh": consumed_kwh,
		"balance_kwh": generated_kwh - consumed_kwh,
		"illumination_fraction": illumination_fraction,
		"generation_multiplier": active_effect_multiplier
	}


func _calculate_life_support(state: Variant) -> Dictionary:
	var crew_count := float(state.crew_size)
	var water_consumed_l := crew_count * (
		_field_value(bvad_constants, "potable_water_consumption_l_per_person_per_day")
		+ _field_value(bvad_constants, "hygiene_water_consumption_l_per_person_per_day")
	)
	var recycling_efficiency := clampf(_field_value(bvad_constants, "water_recycling_efficiency_pct") / 100.0, 0.0, 1.0)
	var structure_output_multiplier := _active_effect_multiplier_for(state.active_events, "output_multiplier")
	var extractor_output := 16.0 * structure_output_multiplier if state.built_structures.has("water_extractor") and not state.damaged_structures.has("water_extractor") and state.volatile_prospect_status == "extraction_candidate" else 0.0
	var water_recovered_l := water_consumed_l * recycling_efficiency * _active_effect_multiplier_for(state.active_events, "water_recovery_multiplier") + extractor_output
	var oxygen_consumed_kg := crew_count * _field_value(bvad_constants, "o2_consumption_kg_per_person_per_day")
	var greenhouse_output := 1.2 * structure_output_multiplier * _active_effect_multiplier_for(state.active_events, "food_production_multiplier") if state.built_structures.has("greenhouse") and not state.damaged_structures.has("greenhouse") else 0.0
	var food_consumed_kg := maxf(0.0, crew_count * _field_value(bvad_constants, "food_consumption_kg_dry_per_person_per_day") - greenhouse_output)
	return {
		"water_consumed_l": water_consumed_l,
		"water_recovered_l": water_recovered_l,
		"water_balance_l": water_recovered_l - water_consumed_l,
		"oxygen_consumed_kg": oxygen_consumed_kg,
		"food_consumed_kg": food_consumed_kg,
		"model_status": "nasa_bvad_consumption_with_iss_eclss_recovery_proxy"
	}


func _life_support_status(state: Variant, water_daily_draw_l: float, oxygen_daily_draw_kg: float, food_daily_draw_kg: float) -> Dictionary:
	return {
		"water": _resource_status(state.water_l, water_daily_draw_l),
		"oxygen": _resource_status(state.oxygen_kg, oxygen_daily_draw_kg),
		"food": _resource_status(state.food_kg, food_daily_draw_kg)
	}


func _resource_status(available: float, daily_draw: float) -> String:
	if available <= 0.0:
		return "depleted"
	if daily_draw <= 0.0:
		return "nominal"
	var days_remaining := available / daily_draw
	if days_remaining < 1.0:
		return "critical"
	if days_remaining < 3.0:
		return "warning"
	return "nominal"


func _terrain_shielding_factor(site: Dictionary) -> float:
	## Derived gameplay proxy: topographic depression and slope can reduce sky view,
	## but LOLA elevation/slope are not radiation measurements. The 0.20 cap keeps
	## terrain secondary to built shielding and recorded radiation events.
	var depth_below_datum_fraction := clampf(-_field_value(site, "elevation_m") / TERRAIN_DEPTH_REFERENCE_M, 0.0, 1.0)
	var slope_fraction := clampf(_field_value(site, "slope_deg") / TERRAIN_SLOPE_REFERENCE_DEG, 0.0, 1.0)
	return clampf(depth_below_datum_fraction * TERRAIN_DEPTH_WEIGHT + slope_fraction * TERRAIN_SLOPE_WEIGHT, 0.0, TERRAIN_DEPTH_WEIGHT + TERRAIN_SLOPE_WEIGHT)


func _active_power_generation_multiplier(active_events: Array) -> float:
	return _active_effect_multiplier_for(active_events, "power_generation_multiplier")


func _active_effect_multiplier_for(active_events: Array, effect_key: String) -> float:
	var multiplier := 1.0
	for event in active_events:
		if event is Dictionary:
			var effects: Variant = event.get("effects", {})
			if effects is Dictionary and effects.has(effect_key):
				multiplier *= float(effects.get(effect_key, 1.0))
	return maxf(0.0, multiplier)


func _active_effect_additive(active_events: Array, effect_key: String) -> float:
	var total := 0.0
	for event in active_events:
		if event is Dictionary:
			var effects: Variant = event.get("effects", {})
			if effects is Dictionary and effects.has(effect_key):
				total += float(effects.get(effect_key, 0.0))
	return total


func _field_value(record: Dictionary, field_name: String) -> float:
	var field: Variant = record.get(field_name, {})
	if field is Dictionary:
		return float(field.get("value", 0.0))
	return float(field)


func _find_site(selected_site_id: String) -> Variant:
	for site in sites:
		if site.get("site_id", "") == selected_site_id:
			return site
	return null


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to read resource contract: %s" % path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Invalid JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("Expected a JSON object in %s" % path)
		return {}
	return json.data


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if item is Dictionary:
			result.append(item)
	return result
