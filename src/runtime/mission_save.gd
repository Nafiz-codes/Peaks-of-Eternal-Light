extends RefCounted
## Save data is plain Variant data, never serialized executable objects.
const State = preload("res://src/simulation/mission_state.gd")
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const VERSION := 4
const Planner = preload("res://src/simulation/mission_planner.gd")
const Commander = preload("res://src/runtime/commander_identity.gd")
const MAX_BYTES := 8 * 1024 * 1024

static func state_data(state: RefCounted) -> Dictionary:
	var result := {}
	if state != null:
		for property in state.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = state.get(property.name)
	return result.duplicate(true)

static func capture(session: Node) -> Dictionary:
	var tick: Dictionary = session.dashboard_last_tick.duplicate(true)
	tick.erase("state")
	return {"version": VERSION, "saved_at": Time.get_datetime_string_from_system(), "maya_intro_complete":session.maya_intro_complete, "crew_introductions":session.crew_introductions.duplicate(true), "solar_placement":session.solar_placement.duplicate(true), "station_placements":session.station_placements.duplicate(true), "building_placements":session.building_placements.duplicate(true), "planning_draft":session.planning_draft.duplicate(true), "approved_plan":session.approved_plan.duplicate(true),
		"site_id": session.selected_site_id, "state": state_data(session.dashboard_state),
		"last_tick": tick, "pose": session.outpost_pose.duplicate(true), "crew_read_reports": session.crew_read_reports.duplicate(true),
		"orbital_clock": session.orbital_clock.duplicate(true), "player_character": session.player_character.duplicate(true)}

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") not in [1, 2, 3, VERSION]:
		return {}
	var identity: Variant = data.get("player_character", {})
	if not Commander.valid(identity): return {}
	if not data.get("site_id") is String or not data.get("state") is Dictionary or not data.get("pose") is Dictionary or not data.get("last_tick") is Dictionary:
		return {}
	var simulator := Simulator.new()
	var introduction: Variant = data.get("maya_intro_complete", true)
	if not introduction is bool: return {}
	var crew_introductions: Variant = data.get("crew_introductions", {})
	if not crew_introductions is Dictionary: return {}
	for id in crew_introductions:
		if id not in ["water_recycler", "food_storage", "maya_closing"] or not crew_introductions[id] is bool: return {}
	var placement: Variant = data.get("solar_placement", {})
	if not placement is Dictionary: return {}
	if not placement.is_empty() and (not placement.get("transform") is Transform3D or not placement.transform.is_finite()): return {}
	var stations: Variant = data.get("station_placements", {})
	if not stations is Dictionary: return {}
	for id in stations:
		if id not in ["maya_station", "alex_station", "sam_station"]: return {}
		if not stations[id] is Transform3D or not stations[id].is_finite(): return {}
		if not stations[id].basis.is_equal_approx(stations[id].basis.orthonormalized()) or stations[id].basis.determinant() < 0.99: return {}
	var buildings: Variant = data.get("building_placements", {})
	if not buildings is Dictionary: return {}
	for id in buildings:
		if id not in ["habitat_module", "comms_relay", "water_extractor", "greenhouse", "shielding_wall"]: return {}
		if not buildings[id] is Transform3D or not buildings[id].is_finite(): return {}
		if not buildings[id].basis.is_equal_approx(buildings[id].basis.orthonormalized()) or buildings[id].basis.determinant() < 0.99: return {}
	var panel_output: Variant = placement.get("kwh_per_sol", 0.0)
	if not (panel_output is float or panel_output is int) or not is_finite(float(panel_output)) or float(panel_output) < 0.0 or float(panel_output) > 100.0: return {}
	var draft: Variant = data.get("planning_draft", {})
	var approved: Variant = data.get("approved_plan", {})
	if not draft is Dictionary or not approved is Dictionary: return {}
	var planner := Planner.new()
	if not draft.is_empty() and (not planner.shape_valid(draft) or draft.site_id != data.site_id): return {}
	if not approved.is_empty():
		if not planner.shape_valid(approved.get("plan")) or approved.plan.site_id != data.site_id or approved.get("completed") != true or approved.get("delivery_status") != "pending": return {}
		var signature := planner.data_signature(data.site_id)
		if approved.get("plan_id") != var_to_bytes([approved.plan,signature,Planner.MODEL_REVISION]).hex_encode().sha256_text() or approved.get("model_revision") != Planner.MODEL_REVISION or approved.get("data_signature") != signature: return {}
		var evaluation := planner.evaluate(approved.plan)
		if not evaluation.valid: return {}
		approved = approved.duplicate(true)
		approved.evaluation = evaluation # Never trust saved derived totals.
	var orbital_clock: Variant = data.get("orbital_clock", preload("res://src/world/orbital_model.gd").default_clock())
	if not preload("res://src/world/orbital_model.gd").valid_clock(orbital_clock):
		return {}
	var read_reports: Variant = data.get("crew_read_reports", {})
	if not read_reports is Dictionary:
		return {}
	for key in read_reports:
		if not key is String or not read_reports[key] is String:
			return {}
	if simulator.load_contracts() != OK:
		return {}
	var valid_site := false
	for site in simulator.sites:
		valid_site = valid_site or site.site_id == data.site_id
	if not valid_site:
		return {}
	var state: RefCounted = null
	if not data.state.is_empty():
		state = State.new()
		for property in state.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var key: String = property.name
			if not data.state.has(key) or typeof(data.state[key]) != property.type:
				# Older version 1 saves omit newer fields; preserve their defaults.
				if key in ["shielding_wall_material_discount", "rover_pose", "rover_health", "fieldwork", "rover_training", "rover_expedition", "placed_panel_kwh_per_sol"] and not data.state.has(key):
					continue
				return {}
			var value: Variant = data.state[key]
			if value is float and not is_finite(value):
				return {}
			if value is Array:
				var target: Array = state.get(key)
				for item in value:
					if typeof(item) != target.get_typed_builtin():
						return {}
				target.assign(value.duplicate(true))
			else:
				state.set(key, value.duplicate(true) if value is Dictionary else value)
		if state.site_id != data.site_id or state.sol < 0 or state.mission_length_sols < 1:
			return {}
		# Canonical roster migration keeps earned resources and historical readings.
		# Version 2 distinguishes new four-person saves from legacy versions.
		state.crew_size = 4
		if state.rover_health < 0.0 or state.rover_health > 100.0:
			return {}
		# A placed panel tops out near 45 kWh per sol; reject edited values.
		if state.placed_panel_kwh_per_sol < 0.0 or state.placed_panel_kwh_per_sol > 100.0:
			return {}
		if not preload("res://src/world/crew_fieldwork.gd").valid_save(state.fieldwork, data.version == 1):
			return {}
		if data.version == 1:
			preload("res://src/world/crew_fieldwork.gd").migrate_legacy(state.fieldwork)
		if not preload("res://src/world/crew_fieldwork.gd").valid_save(state.fieldwork):
			return {}
		if not preload("res://src/simulation/rover_training.gd").valid_save(state.rover_training):
			return {}
		if not preload("res://src/simulation/rover_expedition.gd").valid_save(state.rover_expedition):
			return {}
		if not state.rover_pose.is_empty():
			if not state.rover_pose.get("position") is Vector3 or not state.rover_pose.get("heading") is float:
				return {}
			if not state.rover_pose.position.is_finite() or not is_finite(state.rover_pose.heading):
				return {}
		if not state.mission_outcome.get("status", "") in ["in_progress", "success", "failure"]:
			return {}
		state.mission_outcome = simulator._evaluate_mission_outcome(state)
		simulator._update_report_data(state)
	var pose: Dictionary = data.pose
	if not pose.is_empty():
		if pose.get("site_id") != data.site_id or not pose.get("transform") is Transform3D or not pose.get("yaw") is float or not pose.get("pitch") is float:
			return {}
		if not pose.transform.is_finite() or not is_finite(pose.yaw) or not is_finite(pose.pitch):
			return {}
	return {"simulator": simulator, "state": state, "site_id": data.site_id, "maya_intro_complete":introduction, "crew_introductions":crew_introductions.duplicate(true), "solar_placement":placement.duplicate(true), "station_placements":stations.duplicate(true), "building_placements":buildings.duplicate(true), "planning_draft":draft.duplicate(true), "approved_plan":approved.duplicate(true),
		"pose": pose.duplicate(true), "last_tick": data.last_tick.duplicate(true), "crew_read_reports": read_reports.duplicate(true), "orbital_clock": orbital_clock.duplicate(true), "player_character": identity.duplicate(true)}

static func restore(session: Node, data: Dictionary) -> Error:
	var restored := decode(data)
	if restored.is_empty():
		return ERR_INVALID_DATA
	session.selected_site_id = restored.site_id
	session.maya_intro_complete = restored.maya_intro_complete
	session.crew_introductions = restored.crew_introductions
	session.solar_placement = restored.solar_placement
	session.station_placements = restored.station_placements
	session.building_placements = restored.building_placements
	session.planning_draft = restored.planning_draft
	session.approved_plan = restored.approved_plan
	session.player_character = restored.player_character
	session.dashboard_simulator = restored.simulator
	session.dashboard_state = restored.state
	session.dashboard_last_tick = restored.last_tick
	if restored.state != null and not restored.last_tick.is_empty():
		session.dashboard_last_tick["state"] = restored.state
	session.outpost_pose = restored.pose
	session.crew_read_reports = restored.crew_read_reports
	session.orbital_clock = restored.orbital_clock
	if restored.state != null:
		session.orbital_clock.elapsed_seconds = restored.state.sol * preload("res://src/world/orbital_model.gd").DAY
	session.action_busy = false
	session.return_scene_path = ""
	return OK

static func write_file(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(data, false)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES or file.get_length() < 4:
		return {}
	var value: Variant = file.get_var(false)
	return value if value is Dictionary else {}
