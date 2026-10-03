extends Node

## Small runtime bridge between the landing selector, walkable outpost, and
## mission dashboard. MissionSimulator remains authoritative for mission state.

var selected_site_id := ""
var return_scene_path := ""
var dashboard_simulator: RefCounted = null
var dashboard_state: Variant = null
var dashboard_last_tick: Dictionary = {}
signal state_changed
var action_busy := false
var reduce_motion := false
var outpost_pose: Dictionary = {}


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
	dashboard_last_tick = {}
	state_changed.emit()
	return OK


func can_advance() -> bool:
	return not action_busy and dashboard_state != null and dashboard_state.mission_outcome.get("status", "") == "in_progress" and dashboard_state.pending_events.is_empty()


func advance_mission() -> bool:
	if not can_advance():
		return false
	action_busy = true
	dashboard_last_tick = dashboard_simulator.advance_sol(dashboard_state)
	dashboard_state = dashboard_last_tick.state
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


func select_landing_site(site_id: String) -> void:
	if selected_site_id != site_id:
		outpost_pose = {}
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
			outpost_pose = {"site_id": selected_site_id, "transform": player.transform, "yaw": player.camera_yaw, "pitch": player.camera_pitch}
	get_tree().change_scene_to_file("res://scenes/mission_dashboard.tscn")


func return_to_game() -> void:
	var destination := return_scene_path
	if destination.is_empty():
		destination = "res://scenes/lunar_landing_selector.tscn"
	return_scene_path = ""
	get_tree().change_scene_to_file(destination)
