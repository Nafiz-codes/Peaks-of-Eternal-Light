extends SceneTree
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Save = preload("res://src/runtime/mission_save.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
 var session = root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 assert(session.start_selected_mission() == OK)
 var d = Rules.fresh()
 assert(Rules.assigned(d, 0) == 0)
 d.completed.append(0)
 assert(Rules.assigned(d, 0) == 1)
 d.completed.append(1)
 assert(Rules.assigned(d, 0) == 2)
 d.completed.append(2)
 assert(Rules.assigned(d, 0) == -1)
 assert(not session.construction_ready())
 session.solar_placement = {"transform": Transform3D.IDENTITY}
 session.station_placements = {"maya_station": Transform3D.IDENTITY, "alex_station": Transform3D.IDENTITY, "sam_station": Transform3D.IDENTITY}
 assert(session.construction_ready())
 session.station_placements = {}
 session.solar_placement = {}
 session.dashboard_state.sol = 8
 session.dashboard_state.mission_outcome = session.dashboard_simulator._evaluate_mission_outcome(session.dashboard_state)
 assert(session.dashboard_state.mission_outcome.status == "in_progress")
 assert(not Save.decode(Save.capture(session)).is_empty())
 var before: float = session.orbital_clock.elapsed_seconds
 assert(session.advance_mission())
 assert(session.orbital_clock.elapsed_seconds == before + 86400.0)
 await process_frame
 session.dashboard_state.pending_events.clear()
 session.account_elapsed_time(86400.0)
 assert(session.dashboard_state.sol == 10)
 assert(session.orbital_clock.elapsed_seconds == before + 86400.0)
 assert(not Save.decode(Save.capture(session)).is_empty())
 print("Mission progression: PASS")
 quit()
