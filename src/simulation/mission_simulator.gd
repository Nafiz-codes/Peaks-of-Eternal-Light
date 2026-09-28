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

const INITIAL_POWER_KWH := 120.0
const INITIAL_WATER_L := 400.0
const INITIAL_OXYGEN_KG := 45.0
const INITIAL_FOOD_KG := 30.0
const INITIAL_MATERIALS := 180.0
const BATTERY_CAPACITY_KWH := 180.0

## Gameplay calibration, pending Member 1's CRaTER source pass on Day 6.
## This is deliberately not represented as a NASA measurement.
const PROVISIONAL_SURFACE_RADIATION_MSV_PER_SOL := 0.25
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
	state.history.append(state.snapshot())
	return state


func advance_sol(state: Variant) -> Dictionary:
	assert(state != null, "A MissionState is required.")
	assert(state.sol < state.mission_length_sols, "The mission has already ended.")

	state.sol += 1
	var site: Dictionary = _find_site(state.site_id)
	var power_tick: Dictionary = _calculate_power(state, site)
	state.power_generated_kwh = power_tick.generated_kwh
	state.power_consumed_kwh = power_tick.consumed_kwh
	state.power_balance_kwh = power_tick.balance_kwh
	state.power_kwh = clampf(state.power_kwh + state.power_balance_kwh, 0.0, BATTERY_CAPACITY_KWH)

	state.terrain_shielding_factor = _terrain_shielding_factor(site)
	state.radiation_this_sol_msv = PROVISIONAL_SURFACE_RADIATION_MSV_PER_SOL * (1.0 - state.terrain_shielding_factor)
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
	state.history.append(state.snapshot())
	return {
		"state": state,
		"completed": state.sol >= state.mission_length_sols,
		"power": power_tick,
		"radiation": {
			"dose_this_sol_msv": state.radiation_this_sol_msv,
			"terrain_shielding_factor": state.terrain_shielding_factor,
			"model_status": "provisional_gameplay_calibration"
		},
		"life_support": life_support_tick,
		"active_events": state.active_events.duplicate(true)
	}


func _calculate_power(state: Variant, site: Dictionary) -> Dictionary:
	var illumination_fraction := clampf(_field_value(site, "illumination_pct") / 100.0, 0.0, 1.0)
	var active_effect_multiplier := _active_power_generation_multiplier(state.active_events)
	var generated_kwh := BASE_SOLAR_GENERATION_KWH_PER_SOL * illumination_fraction * active_effect_multiplier
	var baseline_kw_per_person := _field_value(bvad_constants, "power_baseline_kw_per_person")
	var consumed_kwh := baseline_kw_per_person * float(state.crew_size) * 24.0
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
	var water_recovered_l := water_consumed_l * clampf(_field_value(bvad_constants, "water_recycling_efficiency_pct") / 100.0, 0.0, 1.0)
	var oxygen_consumed_kg := crew_count * _field_value(bvad_constants, "o2_consumption_kg_per_person_per_day")
	var food_consumed_kg := crew_count * _field_value(bvad_constants, "food_consumption_kg_dry_per_person_per_day")
	return {
		"water_consumed_l": water_consumed_l,
		"water_recovered_l": water_recovered_l,
		"water_balance_l": water_recovered_l - water_consumed_l,
		"oxygen_consumed_kg": oxygen_consumed_kg,
		"food_consumed_kg": food_consumed_kg,
		"model_status": "unverified_contract_inputs"
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
	## Terrain is a low-strength proxy for local shielding. It is calculated from
	## LOLA-compatible elevation/slope fields and will be recalibrated when their
	## source values and the CRaTER baseline are verified.
	var depth_below_datum_fraction := clampf(-_field_value(site, "elevation_m") / 2500.0, 0.0, 1.0)
	var slope_fraction := clampf(_field_value(site, "slope_deg") / 30.0, 0.0, 1.0)
	return clampf(depth_below_datum_fraction * 0.12 + slope_fraction * 0.08, 0.0, 0.20)


func _active_power_generation_multiplier(active_events: Array) -> float:
	var multiplier := 1.0
	for event in active_events:
		if event is Dictionary:
			var effects: Variant = event.get("effects", {})
			if effects is Dictionary and effects.has("power_generation_multiplier"):
				multiplier *= float(effects.get("power_generation_multiplier", 1.0))
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
