extends RefCounted
## Save data is plain Variant data, never serialized executable objects.
const State = preload("res://src/simulation/mission_state.gd")
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const VERSION := 1
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
	return {"version": VERSION, "saved_at": Time.get_datetime_string_from_system(),
		"site_id": session.selected_site_id, "state": state_data(session.dashboard_state),
		"last_tick": tick, "pose": session.outpost_pose.duplicate(true), "crew_read_reports": session.crew_read_reports.duplicate(true),
		"orbital_clock": session.orbital_clock.duplicate(true)}

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != VERSION:
		return {}
	if not data.get("site_id") is String or not data.get("state") is Dictionary or not data.get("pose") is Dictionary or not data.get("last_tick") is Dictionary:
		return {}
	var simulator := Simulator.new()
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
				if key in ["shielding_wall_material_discount", "rover_pose", "rover_health", "fieldwork", "rover_training", "rover_expedition"] and not data.state.has(key):
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
		if state.site_id != data.site_id or state.sol < 0 or state.sol > state.mission_length_sols or state.mission_length_sols < 1:
			return {}
		# The previous four-person resource model omitted the visible player.
		if state.crew_size == 4:
			state.power_kwh += 12.0 * maxf(0,state.mission_length_sols-state.sol)
			state.water_l *= 1.25
			state.oxygen_kg *= 1.25
			state.food_kg *= 1.25
		state.crew_size = 5
		if state.rover_health < 0.0 or state.rover_health > 100.0:
			return {}
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
		if state.mission_length_sols == 10:
			state.mission_length_sols = 7
			state.sol = mini(state.sol, 7)
			state.mission_outcome = simulator._evaluate_mission_outcome(state)
			simulator._update_report_data(state)
	var pose: Dictionary = data.pose
	if not pose.is_empty():
		if pose.get("site_id") != data.site_id or not pose.get("transform") is Transform3D or not pose.get("yaw") is float or not pose.get("pitch") is float:
			return {}
		if not pose.transform.is_finite() or not is_finite(pose.yaw) or not is_finite(pose.pitch):
			return {}
	return {"simulator": simulator, "state": state, "site_id": data.site_id,
		"pose": pose.duplicate(true), "last_tick": data.last_tick.duplicate(true), "crew_read_reports": read_reports.duplicate(true), "orbital_clock": orbital_clock.duplicate(true)}

static func restore(session: Node, data: Dictionary) -> Error:
	var restored := decode(data)
	if restored.is_empty():
		return ERR_INVALID_DATA
	session.selected_site_id = restored.site_id
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
