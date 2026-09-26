class_name MissionSimulator
extends RefCounted

## Deterministic simulation entry point. Day 2 establishes the contract-loading
## and state-transition boundary; resource formulas are added in subsequent tasks.

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
	state.history.append(state.snapshot())
	return state


func advance_sol(state: Variant) -> Dictionary:
	assert(state != null, "A MissionState is required.")
	assert(state.sol < state.mission_length_sols, "The mission has already ended.")

	state.sol += 1
	state.history.append(state.snapshot())
	return {
		"state": state,
		"completed": state.sol >= state.mission_length_sols,
		"active_events": state.active_events.duplicate(true)
	}


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
