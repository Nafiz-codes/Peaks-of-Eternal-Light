extends Node

## Small runtime bridge between the landing selector, walkable outpost, and
## mission dashboard. MissionSimulator remains authoritative for mission state.

var selected_site_id := ""
var return_scene_path := ""
var dashboard_simulator: RefCounted = null
var dashboard_state: Variant = null
var dashboard_last_tick: Dictionary = {}


func open_dashboard(from_scene_path: String) -> void:
	if from_scene_path.is_empty() or from_scene_path == "res://scenes/mission_dashboard.tscn":
		return
	return_scene_path = from_scene_path
	get_tree().change_scene_to_file("res://scenes/mission_dashboard.tscn")


func return_to_game() -> void:
	var destination := return_scene_path
	if destination.is_empty():
		destination = "res://scenes/lunar_landing_selector.tscn"
	return_scene_path = ""
	get_tree().change_scene_to_file(destination)
