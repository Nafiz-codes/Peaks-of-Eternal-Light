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
## Enough to build the essentials, not to coast: the crew draws on these continuously.
const INITIAL_POWER_KWH := 100.0
const INITIAL_WATER_L := 250.0
const INITIAL_OXYGEN_KG := 30.0
const INITIAL_FOOD_KG := 22.0
## Maya's review passes when every reserve reaches its goal (the line on the HUD bars).
const MISSION_GOALS := {"power_kwh": 200.0, "water_l": 330.0, "oxygen_kg": 40.0, "food_kg": 30.0}
## Real play seconds for one modeled day of crew draw and production.
const DAY_SECONDS := 240.0
## Gameplay easing on the crew's NASA-baseline daily use of every reserve.
const CREW_DRAW_SCALE := 0.85
## Extra copies allowed of each repeatable producer (the first copy is not counted).
const MAX_STRUCTURE_COPIES := 5
const REPEATABLE_STRUCTURES := ["water_extractor", "greenhouse"]
## Extractor ice also feeds electrolysis; greenhouse plants release oxygen as they grow
## (about 1.07 kg of O2 per kg of dry biomass from photosynthesis).
const EXTRACTOR_WATER_L := 24.0
const EXTRACTOR_OXYGEN_KG := 2.2
const GREENHOUSE_FOOD_KG := 2.2
const GREENHOUSE_OXYGEN_KG := 2.0
## What one copy of each producer adds per day, for the build menu (solar is per spot).
const STRUCTURE_OUTPUT := {
	"water_extractor": {"water_l": EXTRACTOR_WATER_L, "oxygen_kg": EXTRACTOR_OXYGEN_KG},
	"greenhouse": {"food_kg": GREENHOUSE_FOOD_KG, "oxygen_kg": GREENHOUSE_OXYGEN_KG},
}
const BATTERY_CAPACITY_KWH := 300.0
## Storage the outpost has for each supply: production past it is lost (like a full battery),
## so building more producers cannot stockpile without limit. Well above MISSION_GOALS.
const STORAGE_CAPACITY := {"water_l": 500.0, "oxygen_kg": 70.0, "food_kg": 55.0}

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
## No generation without panels: the outpost's power comes only from what the Commander
## places (the lander's own supply is the starting battery charge).
const BASE_SOLAR_GENERATION_KWH_PER_SOL := 0.0
const SOLAR_ARRAY_GENERATION_KWH_PER_SOL := 18.0
## Gameplay value: share of sunlight left during the dust storm (visuals use the same value).
const DUST_STORM_LIGHT_MULTIPLIER := 0.5
const HISTORY_DAYS := 60
## Building costs, as cost key -> state field. Water, oxygen and food are what the crew
## use while building (Resources/construction.json explains the values).
const COST_RESOURCES := {"power": "power_kwh", "water": "water_l", "oxygen": "oxygen_kg", "food": "food_kg"}
const BUILD_RESERVE_DAYS := 2.0 # Never build so much that supplies drop below this.
## Gameplay values: a damaged structure keeps this share of its output until repaired,
## and the dust storm can damage these. "solar_panel" is the hand-placed panel.
const DAMAGED_OUTPUT_SHARE := 0.4
## Random events that ask the Commander to choose are off: their only prompt was a debug
## panel, and a waiting choice froze the rover and the day. Automatic events still happen.
const DECISION_EVENTS_ENABLED := false
## Gameplay values for the radiation wave, per crew member left outside the radiation
## habitat: medical treatment uses supplies, the dose rises, and the crew work slower.
const RADIATION_TREATMENT := {"water_l": 15.0, "oxygen_kg": 2.0, "food_kg": 1.5}
const RADIATION_DOSE_MSV := 0.8
const RADIATION_SLOWDOWN := 0.15 # Output lost per exposed crew member while they recover.
const RADIATION_RECOVERY_SOLS := 2
## Only resource-producing structures take storm damage.
const STORM_DAMAGE_TARGETS := ["solar_panel", "water_extractor", "greenhouse"]
## Repairs cost the crew this share of the structure's build cost.
const REPAIR_COST_SHARE := 0.5
## Shielding the structures before a radiation wave; unshielded producers make this much
## less for RADIATION_RECOVERY_SOLS afterwards.
const STRUCTURE_SHIELD_COST := {"power": 10.0, "water": 6.0, "oxygen": 1.0, "food": 0.5}
const UNSHIELDED_OUTPUT_SHARE := 0.6
## Packing producers away before the dust storm (the crew's time outside).
## Supplies a successful rover operation brings back (none when it fails).
const OPERATION_REWARDS := [
	{"power": 40.0, "water": 20.0, "why": "The survey charted a sunlit ridge line and a frost patch: the panels were retuned and the frost melted down."},
	{"water": 45.0, "oxygen": 5.0, "why": "The ice samples were melted down, and part of the water split into oxygen."},
	{"oxygen": 4.0, "food": 6.0, "why": "Alex's unused emergency oxygen and ration packs came back with him."},
]
## Fixing a wrecked rover (parts and the crew's time outside).
const ROVER_REPAIR_COST := {"power": 15.0, "water": 6.0, "oxygen": 1.0, "food": 0.6}
const STOW_COST := {"power": 6.0, "water": 4.0, "oxygen": 0.8, "food": 0.4}

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
	state.crew_productivity = _crew_productivity_baseline()
	state.terrain_shielding_factor = _terrain_shielding_factor(_find_site(selected_site_id))
	state.life_support_status = _life_support_status(state, 0.0, 0.0, 0.0)
	state.mission_outcome = _evaluate_mission_outcome(state)
	_update_report_data(state)
	state.history.append(state.snapshot())
	record_milestone(state, "Landing")
	return state


func advance_sol(state: Variant) -> Dictionary:
	assert(state != null, "A MissionState is required.")
	assert(state.pending_events.is_empty(), "Resolve pending event decisions before advancing the mission.")
	# Whatever part of today already ran in real time is not charged again.
	var remaining := maxf(0.0, 1.0 - state.day_progress)
	state.day_progress = maxf(0.0, state.day_progress - 1.0)
	return _close_day(state, remaining)


## Continuous play: the crew's draw and the base's production for `seconds` of play.
## Returns true once a whole day has run, so the caller can close it (close_day).
func tick_time(state: Variant, seconds: float) -> bool:
	if state == null or seconds <= 0.0 or not is_finite(seconds) or state.mission_outcome.get("status", "") != "in_progress":
		return false
	var fraction := seconds / DAY_SECONDS
	_apply_balances(state, _find_site(state.site_id), fraction)
	state.day_progress += fraction
	state.mission_outcome = _evaluate_mission_outcome(state)
	return state.day_progress >= 1.0


## The day's bookkeeping (calendar, construction, events, history) after tick_time has
## already charged its resources.
func close_day(state: Variant) -> Dictionary:
	state.day_progress = maxf(0.0, state.day_progress - 1.0)
	return _close_day(state, 0.0)


func _close_day(state: Variant, fraction: float) -> Dictionary:
	state.sol += 1
	state.rover_distance_this_sol_km = 0.0
	_advance_construction(state)
	var site: Dictionary = _find_site(state.site_id)
	var ticks := _apply_balances(state, site, fraction)
	var power_tick: Dictionary = ticks.power
	var life_support_tick: Dictionary = ticks.life_support
	var structural_dose_multiplier: float = ticks.dose_multiplier
	state.consecutive_power_depleted_sols = state.consecutive_power_depleted_sols + 1 if state.power_kwh <= 0.0 else 0
	_evaluate_event_triggers(state)
	_expire_effects(state)
	state.mission_outcome = _evaluate_mission_outcome(state)
	_update_report_data(state)
	state.history.append(state.snapshot())
	# The mission is open-ended: keep the first snapshot and the latest 60 days.
	if state.history.size() > HISTORY_DAYS + 1:
		state.history.remove_at(1)
	return {
		"state": state,
		"completed": false,
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
	var shortfall := cost_shortfall(state, structure_id)
	if not shortfall.is_empty():
		return {"ok": false, "error": "insufficient_" + shortfall}
	var paid := build_cost(state, structure_id)
	_spend(state, paid, -1.0)
	state.construction_queue.append({"structure_id": structure_id, "remaining_work": float(structure.get("build_time_sols", 1)), "started_sol": state.sol})
	_publish_action_state(state)
	return {"ok": true, "structure_id": structure_id, "cost": paid}


## What building it costs now: power, plus the water, oxygen and food the crew use
## while building it. A regolith stockpile halves the shielding habitat's crew cost.
func build_cost(state: Variant, structure_id: String) -> Dictionary:
	var authored: Dictionary = _find_structure(structure_id).get("build_cost", {})
	var crew_share := 0.5 if structure_id == "shielding_wall" and state != null and state.shielding_wall_material_discount > 0.0 else 1.0
	var cost := {}
	for key in COST_RESOURCES:
		cost[key] = float(authored.get(key, 0.0)) * (1.0 if key == "power" else crew_share)
	return cost


## The first resource the outpost cannot spare for this structure ("" when affordable).
## Water, oxygen and food must still last the crew BUILD_RESERVE_DAYS afterwards.
func cost_shortfall(state: Variant, structure_id: String) -> String:
	if state == null:
		return "mission"
	var cost := build_cost(state, structure_id)
	var draw := {"water": maxf(0.0, -state.water_balance_l), "oxygen": maxf(0.0, state.oxygen_consumed_kg), "food": maxf(0.0, state.food_consumed_kg)}
	if state.sol == 0: # No day has run yet: use the crew's planned daily use.
		var life := _calculate_life_support(state)
		draw = {"water": maxf(0.0, -life.water_balance_l), "oxygen": maxf(0.0, life.oxygen_consumed_kg), "food": maxf(0.0, life.food_consumed_kg)}
	for key in COST_RESOURCES:
		var have: float = state.get(COST_RESOURCES[key])
		var keep: float = 0.0 if key == "power" else draw[key] * BUILD_RESERVE_DAYS
		if have - float(cost[key]) < keep - 0.0001:
			return key
	return ""


func _spend(state: Variant, cost: Dictionary, sign: float) -> void:
	for key in COST_RESOURCES:
		var field: String = COST_RESOURCES[key]
		state.set(field, maxf(0.0, float(state.get(field)) + sign * float(cost.get(key, 0.0))))
	_clamp_reserves(state)


## Most a reserve can hold: the battery for power, storage for water, oxygen and food.
func capacity(state: Variant, field: String) -> float:
	return _battery_capacity(state) if field == "power_kwh" else float(STORAGE_CAPACITY.get(field, INF))


## Keeps every reserve within what the outpost can store (never below zero).
func _clamp_reserves(state: Variant) -> void:
	for field in ["power_kwh", "water_l", "oxygen_kg", "food_kg"]:
		state.set(field, clampf(float(state.get(field)), 0.0, capacity(state, field)))


## The storm interlude cuts sunlight for the current sol; the next Run Sol pays for it once.
func apply_dust_storm(state: Variant) -> bool:
	if state == null:
		return false
	for active in state.active_events:
		if active.get("event_id") == "dust_storm" and int(active.get("started_sol", -1)) == state.sol:
			return false # Already applied, e.g. a save loaded mid-storm.
	state.active_events.append({
		"event_id": "dust_storm",
		"effects": {"solar_light_multiplier": DUST_STORM_LIGHT_MULTIPLIER, "duration_sols": 1},
		"remaining_sols": 1,
		"started_sol": state.sol,
		"text": "Dust storm: sunlight reaching solar power collectors is cut to %d%% for this day." % roundi(DUST_STORM_LIGHT_MULTIPLIER * 100.0)
	})
	_publish_action_state(state)
	return true


## What keeps the base from being ready to grow into a permanent base: any reserve
## below its MISSION_GOALS line.
func base_shortfalls(state: Variant) -> Array:
	var shortfalls: Array = []
	for key in COST_RESOURCES:
		if float(state.get(COST_RESOURCES[key])) < float(MISSION_GOALS[COST_RESOURCES[key]]):
			shortfalls.append(key)
	return shortfalls


## Maya's end-of-mission review: with no shortfalls the mission succeeds.
func complete_mission(state: Variant) -> Array:
	# Already confirmed (e.g. a save made during Maya's verdict): nothing is short.
	if state != null and state.mission_outcome.get("status", "") == "success":
		return []
	if state == null or state.mission_outcome.get("status", "") != "in_progress":
		return ["mission"]
	var shortfalls := base_shortfalls(state)
	if shortfalls.is_empty():
		state.mission_outcome.status = "success"
		record_milestone(state, "Mission review")
		_publish_action_state(state)
	return shortfalls


## The mission has failed: a reserve stayed empty too long, or the review fell short.
func fail_mission(state: Variant, reason: String) -> void:
	if state == null or state.mission_outcome.get("status", "") != "in_progress": return
	state.depletion_failure = reason
	_publish_action_state(state)


## The first reserve that has run out ("" when none), in the order the crew feels it.
func empty_reserve(state: Variant) -> String:
	for key in ["oxygen", "water", "food", "power"]:
		if float(state.get(COST_RESOURCES[key])) <= 0.0: return key
	return ""


## Reserves at a story milestone; each label is recorded once (replays add nothing).
func record_milestone(state: Variant, label: String) -> void:
	if state == null:
		return
	for entry in state.milestones:
		if entry.get("label", "") == label:
			return
	state.milestones.append({"label": label, "power_kwh": state.power_kwh, "water_l": state.water_l, "oxygen_kg": state.oxygen_kg, "food_kg": state.food_kg})


## The radiation wave hits: exposed crew need treatment and work slower for two days.
func apply_radiation_wave(state: Variant, exposed: int) -> void:
	if state == null:
		return
	exposed = clampi(exposed, 0, 3)
	state.water_l = maxf(0.0, state.water_l - RADIATION_TREATMENT.water_l * exposed)
	state.oxygen_kg = maxf(0.0, state.oxygen_kg - RADIATION_TREATMENT.oxygen_kg * exposed)
	state.food_kg = maxf(0.0, state.food_kg - RADIATION_TREATMENT.food_kg * exposed)
	state.radiation_msv += RADIATION_DOSE_MSV * exposed
	state.radiation_this_sol_msv += RADIATION_DOSE_MSV * exposed
	if exposed > 0:
		var share := 1.0 - RADIATION_SLOWDOWN * exposed
		state.active_events.append({
			"event_id": "radiation_sickness",
			# output_multiplier already scales base solar power as well as the extractor and greenhouse.
			"effects": {"output_multiplier": share, "water_recovery_multiplier": share, "duration_sols": RADIATION_RECOVERY_SOLS},
			"remaining_sols": RADIATION_RECOVERY_SOLS,
			"started_sol": state.sol,
			"text": "Radiation sickness: %d crew member(s) recovering; the base produces %d%% less." % [exposed, roundi(RADIATION_SLOWDOWN * exposed * 100.0)]
		})
	if not state.structures_shielded:
		state.active_events.append({
			"event_id": "radiation_structures",
			"effects": {"producer_multiplier": UNSHIELDED_OUTPUT_SHARE, "duration_sols": RADIATION_RECOVERY_SOLS},
			"remaining_sols": RADIATION_RECOVERY_SOLS,
			"started_sol": state.sol,
			"text": "Unshielded structures: solar panels, extractors and greenhouses produce %d%% less while their electronics recover." % roundi((1.0 - UNSHIELDED_OUTPUT_SHARE) * 100.0)
		})
	state.structures_shielded = false
	_publish_action_state(state)


## After the ending, "Continue playing" reopens the base for free play.
func resume_after_success(state: Variant) -> bool:
	if state == null or state.mission_outcome.get("status", "") != "success":
		return false
	state.mission_outcome.status = "in_progress"
	_publish_action_state(state)
	return true


## Debug builds only (outpost DEV tools): top up every reserve, or drain it with
## direction -1 (never below zero, power never above the battery).
func developer_add_resources(state: Variant, direction := 1.0) -> void:
	if state == null:
		return
	state.power_kwh = clampf(state.power_kwh + 150.0 * direction, 0.0, _battery_capacity(state))
	state.water_l = maxf(0.0, state.water_l + 150.0 * direction)
	state.oxygen_kg = maxf(0.0, state.oxygen_kg + 20.0 * direction)
	state.food_kg = maxf(0.0, state.food_kg + 15.0 * direction)
	_clamp_reserves(state)
	_publish_action_state(state)


## After the dust storm: one to three of the outpost's working structures are damaged.
## Returns the damaged ids (empty when there is nothing to damage).
func apply_storm_damage(state: Variant) -> Array:
	var damaged: Array = []
	if state == null:
		return damaged
	var candidates: Array = []
	for id in STORM_DAMAGE_TARGETS:
		var present: bool = state.placed_panel_kwh_per_sol > 0.0 if id == "solar_panel" else state.built_structures.has(id)
		if present and not state.damaged_structures.has(id):
			candidates.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("storm_damage:%s:%d" % [state.site_id, state.sol])
	for index in mini(candidates.size(), rng.randi_range(1, 3)):
		var id: String = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		state.damaged_structures[id] = true
		damaged.append(id)
	_publish_action_state(state)
	return damaged


func repair_cost(state: Variant, structure_id: String) -> Dictionary:
	var cost := build_cost(state, "solar_array" if structure_id == "solar_panel" else structure_id)
	for key in cost: cost[key] = float(cost[key]) * REPAIR_COST_SHARE
	return cost


## The first resource the outpost lacks for `cost` ("" when it can pay).
func missing_for(state: Variant, cost: Dictionary) -> String:
	for key in COST_RESOURCES:
		if float(state.get(COST_RESOURCES[key])) < float(cost.get(key, 0.0)) - 0.0001:
			return key
	return ""


func repair_structure(state: Variant, structure_id: String) -> bool:
	if state == null or not state.damaged_structures.has(structure_id):
		return false
	var cost := repair_cost(state, structure_id)
	if not missing_for(state, cost).is_empty():
		return false
	_spend(state, cost, -1.0)
	state.damaged_structures.erase(structure_id)
	_publish_action_state(state)
	return true


## Adds supplies (rewards); power stays within the battery.
func grant(state: Variant, amounts: Dictionary) -> void:
	if state == null: return
	_spend(state, amounts, 1.0)
	_publish_action_state(state)


## Pays for and completes a rover repair (false when the outpost cannot pay).
func repair_rover(state: Variant) -> bool:
	if state == null or not missing_for(state, ROVER_REPAIR_COST).is_empty():
		return false
	_spend(state, ROVER_REPAIR_COST, -1.0)
	state.rover_health = 100.0
	_publish_action_state(state)
	return true


## Before a radiation wave: pay to shield the structures (false when it cannot be paid).
func shield_structures(state: Variant) -> bool:
	if state == null or not missing_for(state, STRUCTURE_SHIELD_COST).is_empty():
		return false
	_spend(state, STRUCTURE_SHIELD_COST, -1.0)
	state.structures_shielded = true
	_publish_action_state(state)
	return true


## Before the dust storm: pack the producers away (offline, but safe from damage).
func stow_producers(state: Variant) -> bool:
	if state == null or not missing_for(state, STOW_COST).is_empty():
		return false
	_spend(state, STOW_COST, -1.0)
	state.producers_stowed = true
	_publish_action_state(state)
	return true


func redeploy_producers(state: Variant) -> void:
	if state == null: return
	state.producers_stowed = false
	_publish_action_state(state)


func _output_share(state: Variant, structure_id: String) -> float:
	return DAMAGED_OUTPUT_SHARE if state.damaged_structures.has(structure_id) else 1.0


## Built copies of a producer, each at the structure's storm-damage share (0 when unbuilt).
func _producing_copies(state: Variant, structure_id: String) -> float:
	if not state.built_structures.has(structure_id):
		return 0.0
	return (1.0 + float(state.structure_copies.get(structure_id, 0))) * _output_share(state, structure_id) * _producer_multiplier(state)


## Panels, extractors and greenhouses: none while packed away, less after an unshielded wave.
func _producer_multiplier(state: Variant) -> float:
	return 0.0 if state.producers_stowed else _active_effect_multiplier_for(state.active_events, "producer_multiplier")


## Another copy of a repeatable producer, placed by the Commander. Returns "" or what is short.
func buy_structure_copy(state: Variant, structure_id: String) -> String:
	if state == null or state.mission_outcome.get("status", "") != "in_progress":
		return "mission"
	if structure_id not in REPEATABLE_STRUCTURES or not state.built_structures.has(structure_id):
		return "structure"
	if int(state.structure_copies.get(structure_id, 0)) >= MAX_STRUCTURE_COPIES:
		return "space"
	var shortfall := cost_shortfall(state, structure_id)
	if not shortfall.is_empty():
		return shortfall
	_spend(state, build_cost(state, structure_id), -1.0)
	state.structure_copies[structure_id] = int(state.structure_copies.get(structure_id, 0)) + 1
	_publish_action_state(state)
	return ""


func sell_structure_copy(state: Variant, structure_id: String) -> Dictionary:
	if state == null or int(state.structure_copies.get(structure_id, 0)) <= 0:
		return {}
	var refund := build_cost(state, structure_id)
	_spend(state, refund, 1.0)
	state.structure_copies[structure_id] = int(state.structure_copies[structure_id]) - 1
	if state.structure_copies[structure_id] == 0: state.structure_copies.erase(structure_id)
	_publish_action_state(state)
	return refund


## Placed buildings finish on confirmation, like the solar panel; costs are already paid.
func complete_construction(state: Variant, structure_id: String) -> bool:
	if state == null:
		return false
	for index in state.construction_queue.size():
		if str(state.construction_queue[index].get("structure_id", "")) == structure_id:
			state.construction_queue.remove_at(index)
			state.built_structures[structure_id] = state.sol
			_publish_action_state(state)
			return true
	return false


func demolish_structure(state: Variant, structure_id: String) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "missing_mission_state"}
	if state.mission_outcome.get("status", "") != "in_progress" or not state.pending_events.is_empty():
		return {"ok": false, "error": "mission_not_ready"}
	if not state.built_structures.has(structure_id):
		return {"ok": false, "error": "structure_not_built"}
	if int(state.structure_copies.get(structure_id, 0)) > 0:
		return {"ok": false, "error": "copies_remain"}
	# Full refund of the build cost, as requested for destroying; energy cannot exceed
	# battery capacity.
	# shortcut: uses the current regolith discount, so a habitat bought before the discount
	# refunds less than was paid; record the paid cost per structure if that matters.
	var refund := build_cost(state, structure_id)
	state.built_structures.erase(structure_id)
	state.damaged_structures.erase(structure_id)
	_spend(state, refund, 1.0)
	_publish_action_state(state)
	return {"ok": true, "structure_id": structure_id, "refund": refund}


## An extra hand-placed solar panel (the first is free): pays the Solar Panel cost and
## adds its rated output. Returns "" or the resource that is short.
func buy_solar_panel(state: Variant, kwh_per_sol: float) -> String:
	if state == null or state.mission_outcome.get("status", "") != "in_progress":
		return "mission"
	var shortfall := cost_shortfall(state, "solar_array")
	if not shortfall.is_empty():
		return shortfall
	_spend(state, build_cost(state, "solar_array"), -1.0)
	state.placed_panel_kwh_per_sol += maxf(0.0, kwh_per_sol)
	_publish_action_state(state)
	return ""


func sell_solar_panel(state: Variant, kwh_per_sol: float) -> Dictionary:
	if state == null:
		return {}
	var refund := build_cost(state, "solar_array")
	_spend(state, refund, 1.0)
	state.placed_panel_kwh_per_sol = maxf(0.0, state.placed_panel_kwh_per_sol - kwh_per_sol)
	_publish_action_state(state)
	return refund


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
	_clamp_reserves(state)
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
		if not DECISION_EVENTS_ENABLED and event.get("choices") is Array and not event.choices.is_empty():
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
	var illumination := 100.0 * PolarSolar.daily_fraction(site, _solar_day(state))
	match event_id:
		"solar_array_dust_accumulation": return state.sol > 3 and _has_rover_or_eva_activity(state)
		"solar_particle_event": return true
		"volatile_prospect_detected": return state.volatile_prospect_found and state.volatile_prospect_status == "uninvestigated" and state.last_rover_action in ["survey", "traverse"]
		"equipment_malfunction": return state.sol >= 3 and not state.built_structures.is_empty()
		"crew_conflict": return state.crew_stress_avg > 0.6
		"micrometeorite_strike": return true
		"water_recycler_clog": return state.sol > 2
		"rover_mobility_hazard": return state.last_rover_action == "traverse"
		"battery_thermal_alert": return state.power_kwh / BATTERY_CAPACITY_KWH * 100.0 < 35.0
		"regolith_stockpile": return state.last_rover_action == "survey" and not state.built_structures.has("shielding_wall")
		"extended_illumination_window": return illumination >= 50.0
		"crew_process_improvement": return state.sol >= 4 and state.crew_stress_avg < 0.45
		"comms_blackout": return not state.built_structures.has("comms_relay")
		"greenhouse_nutrient_imbalance": return state.built_structures.has("greenhouse")
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
	for key in ["water_l", "oxygen_kg", "food_kg"]:
		if effects.has(key):
			state.set(key, clampf(float(state.get(key)) + _numeric_effect(effects[key]), 0.0, capacity(state, key)))
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
		"failure_reason": depletion_reason,
		"failure_sol": state.mission_outcome.get("failure_sol", 0),
		"initial_reserves": {"power_kwh": initial.get("power_kwh", 0.0), "water_l": initial.get("water_l", 0.0), "oxygen_kg": initial.get("oxygen_kg", 0.0), "food_kg": initial.get("food_kg", 0.0)},
		"final_reserves": {"power_kwh": state.power_kwh, "water_l": state.water_l, "oxygen_kg": state.oxygen_kg, "food_kg": state.food_kg},
		"events_resolved": state.resolved_events.size(),
		"event_history": state.resolved_events.duplicate(true),
		"radiation_total_msv": state.radiation_msv,
		"volatile_prospect_status": state.volatile_prospect_status
	}


func _evaluate_mission_outcome(state: Variant) -> Dictionary:
	var existing_outcome: Dictionary = state.mission_outcome
	var failure_reason := str(existing_outcome.get("failure_reason", ""))
	# A reserve at zero starts a short countdown in the session (warning, then 20 s to
	# recover it); only when that runs out, or the final review falls short, is it a failure.
	if failure_reason.is_empty() and not str(state.depletion_failure).is_empty():
		failure_reason = state.depletion_failure

	var failure_sol := int(existing_outcome.get("failure_sol", 0))
	if not failure_reason.is_empty() and failure_sol == 0:
		failure_sol = state.sol
	# Success is granted once, by complete_mission, and kept unless the crew later fails.
	var status := "in_progress"
	if not failure_reason.is_empty():
		status = "failure"
	elif existing_outcome.get("status", "") == "success":
		status = "success"
	return {
		"status": status,
		"failure_reason": failure_reason,
		"failure_sol": failure_sol,
		"primary_objective": "Explore the Moon and support the crew."
	}


## The Earth day just completed, counted from the same start as the visible sky.
func _solar_day(state: Variant) -> float:
	return state.clock_start_seconds / PolarSolar.Orbit.DAY + maxi(0, state.sol - 1)


## Daily rates for the current base, applied by `fraction` of a day (1.0 = a whole day).
func _apply_balances(state: Variant, site: Dictionary, fraction: float) -> Dictionary:
	var power_tick: Dictionary = _calculate_power(state, site)
	state.power_generated_kwh = power_tick.generated_kwh
	state.power_consumed_kwh = power_tick.consumed_kwh
	state.power_balance_kwh = power_tick.balance_kwh
	state.power_kwh = clampf(state.power_kwh + state.power_balance_kwh * fraction, 0.0, _battery_capacity(state))
	state.terrain_shielding_factor = _terrain_shielding_factor(site)
	var structural_dose_multiplier := lerpf(1.0, SHIELDING_WALL_DOSE_MULTIPLIER, _output_share(state, "shielding_wall")) if state.built_structures.has("shielding_wall") else 1.0
	state.radiation_this_sol_msv = LUNAR_SURFACE_GCR_MSV_PER_SOL * (1.0 - state.terrain_shielding_factor) * structural_dose_multiplier
	state.radiation_msv += state.radiation_this_sol_msv * fraction
	var life_support_tick: Dictionary = _calculate_life_support(state)
	state.water_consumed_l = life_support_tick.water_consumed_l
	state.water_recovered_l = life_support_tick.water_recovered_l
	state.water_balance_l = life_support_tick.water_balance_l
	state.water_l = maxf(0.0, state.water_l + state.water_balance_l * fraction)
	state.oxygen_consumed_kg = life_support_tick.oxygen_consumed_kg
	state.oxygen_kg = maxf(0.0, state.oxygen_kg - state.oxygen_consumed_kg * fraction)
	state.food_consumed_kg = life_support_tick.food_consumed_kg
	state.food_kg = maxf(0.0, state.food_kg - state.food_consumed_kg * fraction)
	_clamp_reserves(state)
	state.life_support_status = _life_support_status(state, -state.water_balance_l, state.oxygen_consumed_kg, state.food_consumed_kg)
	return {"power": power_tick, "life_support": life_support_tick, "dose_multiplier": structural_dose_multiplier}


func _calculate_power(state: Variant, site: Dictionary) -> Dictionary:
	var illumination_fraction := PolarSolar.daily_fraction(site, _solar_day(state))
	var solar_yield := PolarSolar.daily_fraction(site, _solar_day(state), true)
	var active_effect_multiplier := _active_power_generation_multiplier(state.active_events)
	var solar_array_output := SOLAR_ARRAY_GENERATION_KWH_PER_SOL * _output_share(state, "solar_array") if state.built_structures.has("solar_array") else 0.0
	# Sunlight lost to a dust storm reaches every solar collector alike.
	var light_multiplier := _active_effect_multiplier_for(state.active_events, "solar_light_multiplier")
	var generated_kwh := (BASE_SOLAR_GENERATION_KWH_PER_SOL + solar_array_output) * solar_yield * active_effect_multiplier * _active_effect_multiplier_for(state.active_events, "output_multiplier") * light_multiplier
	# The placed panel's rating already includes its site and spot, so only lost light scales it:
	# outside a storm the amount shown when placing is exactly what arrives every sol.
	generated_kwh += state.placed_panel_kwh_per_sol * light_multiplier * _output_share(state, "solar_panel") * _producer_multiplier(state)
	var baseline_kw_per_person := _field_value(bvad_constants, "power_baseline_kw_per_person")
	var consumed_kwh := baseline_kw_per_person * float(state.crew_size) * 24.0 * CREW_DRAW_SCALE * _active_effect_multiplier_for(state.active_events, "power_consumption_multiplier")
	return {
		"generated_kwh": generated_kwh,
		"consumed_kwh": consumed_kwh,
		"balance_kwh": generated_kwh - consumed_kwh,
		"illumination_fraction": illumination_fraction,
		"generation_multiplier": active_effect_multiplier,
		"light_multiplier": light_multiplier
	}


## The whole crew's gross daily use of each reserve (before recycling or producers).
func crew_daily_use(crew_size: int = 4) -> Dictionary:
	var crew_count := float(crew_size) * CREW_DRAW_SCALE
	return {
		"power_kwh": _field_value(bvad_constants, "power_baseline_kw_per_person") * crew_count * 24.0,
		"water_l": crew_count * (_field_value(bvad_constants, "potable_water_consumption_l_per_person_per_day") + _field_value(bvad_constants, "hygiene_water_consumption_l_per_person_per_day")),
		"oxygen_kg": crew_count * _field_value(bvad_constants, "o2_consumption_kg_per_person_per_day"),
		"food_kg": crew_count * _field_value(bvad_constants, "food_consumption_kg_dry_per_person_per_day"),
	}


func _calculate_life_support(state: Variant) -> Dictionary:
	var crew_count := float(state.crew_size) * CREW_DRAW_SCALE
	var water_consumed_l := crew_count * (
		_field_value(bvad_constants, "potable_water_consumption_l_per_person_per_day")
		+ _field_value(bvad_constants, "hygiene_water_consumption_l_per_person_per_day")
	)
	var recycling_efficiency := clampf(_field_value(bvad_constants, "water_recycling_efficiency_pct") / 100.0, 0.0, 1.0)
	var structure_output_multiplier := _active_effect_multiplier_for(state.active_events, "output_multiplier")
	var extractors := _producing_copies(state, "water_extractor") if state.volatile_prospect_status == "extraction_candidate" else 0.0
	var extractor_output := EXTRACTOR_WATER_L * structure_output_multiplier * extractors
	var water_recovered_l := water_consumed_l * recycling_efficiency * _active_effect_multiplier_for(state.active_events, "water_recovery_multiplier") + extractor_output
	var greenhouses := _producing_copies(state, "greenhouse")
	var oxygen_produced_kg := (EXTRACTOR_OXYGEN_KG * extractors + GREENHOUSE_OXYGEN_KG * greenhouses) * structure_output_multiplier
	# Net draw: negative once producers out-supply the crew, so reserves can rebuild.
	var oxygen_consumed_kg := crew_count * _field_value(bvad_constants, "o2_consumption_kg_per_person_per_day") - oxygen_produced_kg
	var greenhouse_output := GREENHOUSE_FOOD_KG * structure_output_multiplier * _active_effect_multiplier_for(state.active_events, "food_production_multiplier") * greenhouses
	var food_consumed_kg := crew_count * _field_value(bvad_constants, "food_consumption_kg_dry_per_person_per_day") - greenhouse_output
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
