extends Node

## Small runtime bridge between the landing selector, walkable outpost, and
## mission dashboard. MissionSimulator remains authoritative for mission state.

var selected_site_id := ""
var player_character: Dictionary = {}
var commander_draft: Dictionary = {}
var planning_draft: Dictionary = {}
var approved_plan: Dictionary = {}
signal mission_plan_approved(record: Dictionary)
const Planner = preload("res://src/simulation/mission_planner.gd")

func begin_planning() -> void:
	if planning_draft.get("site_id", "") != selected_site_id:
		planning_draft = Planner.new().default_plan(selected_site_id)

func approve_planning() -> Dictionary:
	var planner := Planner.new()
	var result := planner.evaluate(planning_draft)
	if planning_draft.get("site_id") != selected_site_id:
		return {"valid":false,"errors":["The plan must match the selected outpost."]}
	if not result.valid: return result
	var plan := planning_draft.duplicate(true)
	plan.step = 5
	var signature := planner.data_signature(selected_site_id)
	if approved_plan.get("plan", {}) == plan and approved_plan.get("data_signature") == signature and approved_plan.get("model_revision") == Planner.MODEL_REVISION: return result
	var previous := approved_plan.duplicate(true)
	approved_plan = {"plan":plan,"plan_id":var_to_bytes([plan,signature,Planner.MODEL_REVISION]).hex_encode().sha256_text(),"data_signature":signature,"evaluation":result,"completed":true,"delivery_status":"pending","model_revision":Planner.MODEL_REVISION}
	var error := save_slot("user://mission-planning.save")
	if error != OK:
		approved_plan = previous
		return {"valid":false,"errors":["Approval could not be saved: " + error_string(error)]}
	mission_plan_approved.emit(approved_plan.duplicate(true))
	state_changed.emit()
	return result

func pending_mission_plan() -> Dictionary:
	# Future delivery must consume this ID transactionally, once, before granting cargo.
	return approved_plan.duplicate(true) if approved_plan.get("delivery_status") == "pending" else {}
const Commander = preload("res://src/runtime/commander_identity.gd")

func confirm_new_commander(appearance: String, player_name: String) -> bool:
	var identity := Commander.create(appearance, player_name)
	if identity.is_empty(): return false
	player_character = identity
	commander_draft = {"appearance_id": appearance, "name": identity.name}
	# Commit a fresh in-memory playthrough only after confirmation. Disk slots stay intact.
	selected_site_id = ""
	planning_draft = {}
	approved_plan = {}
	dashboard_simulator = null
	dashboard_state = null
	dashboard_last_tick = {}
	outpost_pose = {}
	sol_checkpoint = {}
	crew_read_reports = {}
	return_scene_path = ""
	action_busy = false
	orbital_clock = preload("res://src/world/orbital_model.gd").default_clock()
	state_changed.emit()
	return true

func commander_name() -> String:
	return str(player_character.get("name", "Commander"))

func commander_portrait(expression := "neutral") -> Dictionary:
	return Commander.portrait(player_character, expression)
var skip_next_startup_intro := false
var return_scene_path := ""
var dashboard_simulator: RefCounted = null
var dashboard_state: Variant = null
var dashboard_last_tick: Dictionary = {}
signal state_changed
var action_busy := false
var reduce_motion := false
var outpost_pose: Dictionary = {}
var sol_checkpoint: Dictionary = {}
var crew_read_reports: Dictionary = {}
var orbital_clock: Dictionary = preload("res://src/world/orbital_model.gd").default_clock()
const Save = preload("res://src/runtime/mission_save.gd")
# Temporary development aid. Set false (or remove this method/UI) before release.
const DEV_SOL_SKIP_ENABLED := true

func developer_skip_sols(count: int) -> bool:
	if not DEV_SOL_SKIP_ENABLED or not OS.is_debug_build() or count <= 0 or action_busy or get_tree().paused:
		return false
	var scene := get_tree().current_scene
	if scene != null:
		var driver := scene.get_node_or_null("RoverHull")
		var access := scene.get_node_or_null("LanderAccess")
		if (driver != null and driver.active) or (access != null and access.busy):
			return false
	if start_selected_mission() != OK:
		return false
	if dashboard_state.mission_outcome.get("status", "") != "in_progress" or dashboard_state.rover_expedition.get("location", "outpost") != "outpost":
		return false
	# Calendar-only jump: retain supplies, decisions, and incomplete objectives.
	# Leave the final Sol to the simulator so it can generate a valid outcome.
	var target := mini(dashboard_state.sol + count, dashboard_state.mission_length_sols - 1)
	if target <= dashboard_state.sol:
		return false
	dashboard_state.sol = target
	dashboard_state.rover_distance_this_sol_km = 0.0
	dashboard_last_tick = {}
	state_changed.emit()
	capture_sol_checkpoint()
	return true

func remember_pose() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Outpost/Astronaut")
	if player != null:
		outpost_pose = {"site_id": selected_site_id, "transform": player.transform,
			"yaw": float(player.camera_yaw), "pitch": float(player.camera_pitch), "first_person": player.first_person}

func capture_sol_checkpoint() -> void:
	remember_pose()
	sol_checkpoint = Save.capture(self)

func save_slot(path: String) -> Error:
	remember_pose()
	var data := Save.capture(self)
	if Save.decode(data).is_empty():
		return ERR_INVALID_DATA
	data["checkpoint"] = sol_checkpoint.duplicate(true)
	return Save.write_file(path, data)

func load_slot(path: String) -> Error:
	var data := Save.read_file(path)
	if not data.get("checkpoint", {}) is Dictionary:
		return ERR_INVALID_DATA
	var checkpoint: Dictionary = data.get("checkpoint", {})
	if not checkpoint.is_empty() and (checkpoint.get("site_id") != data.get("site_id") or Save.decode(checkpoint).is_empty()):
		return ERR_INVALID_DATA
	var error := Save.restore(self, data)
	if error == OK:
		sol_checkpoint = checkpoint.duplicate(true)
	return error

func restart_current_sol() -> Error:
	if sol_checkpoint.is_empty():
		return ERR_UNAVAILABLE
	return Save.restore(self, sol_checkpoint)

func reset_current_mission() -> Error:
	orbital_clock = preload("res://src/world/orbital_model.gd").default_clock()
	crew_read_reports = {}
	dashboard_state = null
	dashboard_last_tick = {}
	outpost_pose = {}
	sol_checkpoint = {}
	action_busy = false
	return start_selected_mission()


func start_selected_mission() -> Error:
	if dashboard_state != null:
		return OK
	var simulator := preload("res://src/simulation/mission_simulator.gd").new()
	var error := simulator.load_contracts()
	if error != OK:
		return error
	var valid := false
	for site in simulator.sites:
		if str(site.site_id) == selected_site_id:
			valid = true
	if not valid:
		return ERR_INVALID_PARAMETER
	dashboard_simulator = simulator
	dashboard_state = simulator.begin_mission(selected_site_id)
	orbital_clock.elapsed_seconds = 0.0
	dashboard_last_tick = {}
	capture_sol_checkpoint()
	state_changed.emit()
	return OK


func can_advance() -> bool:
	return not action_busy and dashboard_state != null and dashboard_state.mission_outcome.get("status", "") == "in_progress" and dashboard_state.pending_events.is_empty()


func advance_mission() -> bool:
	if not can_advance():
		return false
	if dashboard_state.rover_expedition.get("location", "outpost") == "expedition":
		return false # Finish or recall the remote expedition before advancing the Sol.
	action_busy = true
	dashboard_last_tick = dashboard_simulator.advance_sol(dashboard_state)
	dashboard_state = dashboard_last_tick.state
	capture_sol_checkpoint()
	state_changed.emit()
	call_deferred("_unlock_action")
	return true


func _unlock_action() -> void:
	action_busy = false
	state_changed.emit()


func resolve_decision(event_id: String, choice_id: String) -> Dictionary:
	if action_busy or dashboard_state == null or dashboard_state.mission_outcome.get("status", "") != "in_progress":
		return {"ok": false, "error": "mission_not_ready"}
	var result: Dictionary = dashboard_simulator.resolve_event_choice(dashboard_state, event_id, choice_id)
	if result.get("ok", false):
		dashboard_state = result.state
		state_changed.emit()
	return result


func queue_structure(structure_id: String) -> Dictionary:
	if action_busy or dashboard_state == null:
		return {"ok": false, "error": "mission_not_ready"}
	var result: Dictionary = dashboard_simulator.queue_construction(dashboard_state, structure_id)
	if result.get("ok", false):
		capture_sol_checkpoint()
		state_changed.emit()
	return result


func send_rover(action_id: String, distance_km: float) -> Dictionary:
	var scene := get_tree().current_scene
	var driver := null if scene == null else scene.get_node_or_null("RoverHull")
	if driver == null or not driver.get("active") or not driver.available():
		return {"ok": false, "error": "lander_control_required"}
	if action_busy or dashboard_state == null:
		return {"ok": false, "error": "mission_not_ready"}
	var result: Dictionary = dashboard_simulator.dispatch_rover(dashboard_state, action_id, distance_km)
	# Remote driving publishes at 4 Hz and checkpoints on release, rather than
	# copying the mission history on every physics frame.
	return result


func select_landing_site(site_id: String) -> void:
	if selected_site_id != site_id:
		planning_draft = {}
		approved_plan = {}
		crew_read_reports = {}
		outpost_pose = {}
		sol_checkpoint = {}
	# A different destination must not resume another site's mission.
	if dashboard_state != null and str(dashboard_state.site_id) != site_id:
		dashboard_state = null
		dashboard_last_tick = {}
	selected_site_id = site_id
	state_changed.emit()


func open_dashboard(from_scene_path: String) -> void:
	if from_scene_path.is_empty() or from_scene_path == "res://scenes/mission_dashboard.tscn":
		return
	return_scene_path = from_scene_path
	var scene := get_tree().current_scene
	if scene != null:
		var player := scene.get_node_or_null("Outpost/Astronaut")
		if player != null:
			outpost_pose = {"site_id": selected_site_id, "transform": player.transform, "yaw": player.camera_yaw, "pitch": player.camera_pitch, "first_person": player.first_person}
	get_tree().change_scene_to_file("res://scenes/mission_dashboard.tscn")


func return_to_game() -> void:
	var destination := return_scene_path
	if destination.is_empty():
		destination = "res://scenes/lunar_landing_selector.tscn"
	return_scene_path = ""
	get_tree().change_scene_to_file(destination)
