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

# Gameplay start reserve tuned on Day 16 so a first-choice 10-sol route has a
# narrow recovery margin at the disclosed 50% illumination model.
const INITIAL_POWER_KWH := 170.0
const INITIAL_WATER_L := 400.0
const INITIAL_OXYGEN_KG := 45.0
const INITIAL_FOOD_KG := 30.0
const INITIAL_MATERIALS := 180.0
const BATTERY_CAPACITY_KWH := 180.0

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


func begin_mission(selected_site_id: String, mission_length: int = 10) -> Variant:
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
	var site: Dictionary = _find_site(state.site_id)
	var power_tick: Dictionary = _calculate_power(state, site)
	state.power_generated_kwh = power_tick.generated_kwh
	state.power_consumed_kwh = power_tick.consumed_kwh
	state.power_balance_kwh = power_tick.balance_kwh
	state.power_kwh = clampf(state.power_kwh + state.power_balance_kwh, 0.0, BATTERY_CAPACITY_KWH)

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
		var selected_effects: Dictionary = event.get("effects", {}).duplicate(true)
		if event.get("choices") is Array and not event.choices.is_empty():
			var found_choice := false
			for choice in event.choices:
				if str(choice.get("choice_id", "")) == choice_id:
					selected_effects = choice.get("effects", {}).duplicate(true)
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
		if event.get("choices") is Array and not event.choices.is_empty():
			state.pending_events.append(runtime_event)
		else:
			_apply_event_effects(state, event_id, event.get("effects", {}))
			state.resolved_events.append({"event_id": event_id, "choice_id": "automatic", "sol": state.sol})
		break # One new event per sol keeps authored choices legible and bounded.


func _event_condition_met(event_id: String, state: Variant) -> bool:
	var site: Dictionary = _find_site(state.site_id)
	var illumination := _field_value(site, "illumination_pct")
	match event_id:
		"solar_array_dust_accumulation": return state.sol > 3 and _has_rover_or_eva_activity(state)
		"solar_particle_event": return true
		"volatile_prospect_detected": return _has_rover_or_eva_activity(state) and not state.volatile_prospect_found
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
		state.crew_stress_avg = clampf(state.crew_stress_avg + _numeric_effect(effects.crew_stress), 0.0, 1.0)
	if effects.get("volatile_prospect_found", false):
		state.volatile_prospect_found = true
		state.volatile_prospect_status = "uninvestigated"
	if effects.has("volatile_prospect_status"):
		state.volatile_prospect_status = str(effects.volatile_prospect_status)
	if effects.get("extraction_candidate_unlocked", false):
		state.volatile_prospect_status = "extraction_candidate"
	if effects.has("battery_charge_bonus_kwh"):
		state.power_kwh = minf(BATTERY_CAPACITY_KWH, state.power_kwh + float(effects.battery_charge_bonus_kwh))
	if effects.has("power_cost_kwh"):
		state.power_kwh = maxf(0.0, state.power_kwh - float(effects.power_cost_kwh))
	if effects.has("radiation_dose_spike"):
		var spike := 0.45 if str(effects.radiation_dose_spike) == "low" else 1.8
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
	var illumination_fraction := clampf(_field_value(site, "illumination_pct") / 100.0, 0.0, 1.0)
	var active_effect_multiplier := _active_power_generation_multiplier(state.active_events)
	var generated_kwh := BASE_SOLAR_GENERATION_KWH_PER_SOL * illumination_fraction * active_effect_multiplier
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
	var water_recovered_l := water_consumed_l * recycling_efficiency * _active_effect_multiplier_for(state.active_events, "water_recovery_multiplier")
	var oxygen_consumed_kg := crew_count * _field_value(bvad_constants, "o2_consumption_kg_per_person_per_day")
	var food_consumed_kg := crew_count * _field_value(bvad_constants, "food_consumption_kg_dry_per_person_per_day")
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
