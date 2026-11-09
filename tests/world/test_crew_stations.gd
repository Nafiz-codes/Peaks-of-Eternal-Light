extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var session := root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 session.start_selected_mission()
 session.maya_intro_complete = true
 var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await physics_frame
 var placement := world.get_node("SolarPlacement")
 placement.set_physics_process(false)
 var crew := world.get_node("CrewFieldwork")
 crew.set_physics_process(false)
 var player := world.get_node("Outpost/Astronaut")
 player.set_physics_process(false)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.current = true
 placement._open_menu()
 check(placement.grid.get_child_count() == 9, "B menu includes three stations.")
 placement._close_menu_and()
 player.moving = true
 player.animation_player.play("moon_walk")
 placement._select("maya_station")
 player._update_animation(true)
 check(player.animation_player.current_animation == "moon_walk" and player.animation_player.is_playing(), "Entering placement while walking keeps locomotion animation running.")
 check(player.placing_solar and placement.pose_hold != null, "Station placement uses the raised-arm pose.")
 placement._cancel()
 check(player.animation_player.current_animation == "moon_walk" and player.animation_player.is_playing(), "Cancelling placement restores walking without needing to release movement keys.")
 check(not player.placing_solar and not player.ui_blocked and placement.pose_hold == null, "Cancel releases pose and movement locks.")
 await process_frame
 check(placement.stations.is_empty() and session.station_placements.is_empty(), "Cancelling discards only the preview.")
 for id in ["maya_station", "alex_station", "sam_station"]:
  placement._select(id)
  var found := false
  for z in [-9,-4,1,6,10,16,-18]:
   for x in [-10,-5,0,5,10,-18,18]:
    var spot := Vector3(x,0,z)
    player.global_position = spot + Vector3(0,0,8)
    camera.global_position = spot + Vector3(0,7,1)
    camera.look_at(spot)
    placement.yaw = PI
    placement.route_checked_at = 0
    placement._physics_process(0)
    if placement.valid:
     found = true
     break
   if found: break
  check(found, "Reachable ground found for " + id)
  if not found:
   placement._cancel()
   continue
  var preview: Node3D = placement.panel
  var shell_bounds := AABB()
  var first_mesh := true
  var is_tower := id == "maya_station"
  for mesh in (preview.get_node("StationBuilding") if is_tower else preview.find_child("HabitatShell", true, false)).find_children("*", "MeshInstance3D", true, false):
   var box: AABB = (preview.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
   shell_bounds = box if first_mesh else shell_bounds.merge(box)
   first_mesh = false
  if is_tower:
   check(shell_bounds.size.x > 12.5 and shell_bounds.size.x < 13.5, "Operations tower matches the radiation habitat's ~13 m scale.")
   check(shell_bounds.size.y > 6.5 and shell_bounds.end.y <= placement.Station.clearance_height(id), "Tower is full height and fits its clearance.")
  else:
   check(shell_bounds.size.y > 7.0 and shell_bounds.size.y < 7.3, "Workshop shell is scaled 1.3x, approximately 7.15 m high.")
   check(is_equal_approx(shell_bounds.size.x, 9.6 * 1.3), "Workshop shell keeps its proportions at 1.3x (12.48 m width).")
  var landing: Transform3D = preview.transform
  var assigned: String = placement.Station.DEFINITIONS[id].npc
  if id == "alex_station":
   crew.data.crew[assigned].phase = "Waiting for assistance"
   crew.data.crew[assigned].task = "sample"
  if id == "sam_station":
   crew.data.crew[assigned].phase = "Working"
   crew.data.crew[assigned].task = "inspect"
  player.moving = true
  player.animation_player.play("moon_walk")
  var player_velocity: Vector3 = Vector3(0.7, 0, -1.1)
  player.velocity = player_velocity
  placement.confirm()
  check(player.animation_player.current_animation == "moon_walk" and player.animation_player.is_playing(), "Confirm preserves walk animation while movement remains held.")
  check(player.velocity == player_velocity and not player.placing_solar and placement.pose_hold == null and not player.ui_blocked, "Confirm preserves movement and releases the raised-arm pose.")
  var collision_bodies := preview.find_children("*", "StaticBody3D", true, false)
  check(not collision_bodies.is_empty(), "Collision reserves the building space as soon as placement is confirmed.")
  var collision_origin: Vector3 = collision_bodies[0].global_position
  check(placement.settling and preview.position.y > landing.origin.y, "Station drops from above its landing.")
  await create_timer(0.5).timeout
  check(collision_bodies[0].global_position.is_equal_approx(collision_origin), "Grounded collision stays fixed during the visual drop.")
  check(preview.transform.is_equal_approx(landing), "Station lands at the exact rotated preview transform.")
  check(preview.find_children("*", "StaticBody3D", true, false).size() > 0, "Placed station has collision.")
  check(session.station_placements.has(id), "Station placement persisted.")
  var npc: String = placement.Station.DEFINITIONS[id].npc
  check(crew.station_homes.has(npc), "Station assigned to its canonical NPC.")
  crew._tick(npc, 0.1)
  check(crew.data.crew[npc].phase == "Returning", "Idle, waiting, or working NPC starts returning to the new station.")
  # A temporary obstruction must not leave a returning NPC permanently blocked.
  crew.data.crew[npc].phase = "Blocked"
  crew.data.crew[npc].checkpoint = "Returning"
  crew._tick(npc, 1.1)
  check(crew.data.crew[npc].phase == "Returning", "Blocked station return automatically replans.")
  if id == "sam_station": world.get_node("RoverHull").active = true
  for step in range(360):
   if crew.data.crew[npc].phase == "Available": break
   crew._tick(npc, 0.25)
   await physics_frame
  print("ARRIVAL ", npc, " ", crew.data.crew[npc].phase, " ", crew.data.crew[npc].message, " pos=", crew.actors[npc].position, " home=", crew.homes[npc])
  check(crew.data.crew[npc].phase == "Available" and crew.actors[npc].position.distance_to(crew.homes[npc]) < 0.65, "NPC reaches its workstation without teleporting.")
  world.get_node("RoverHull").active = false
  check(not crew.route_service.route(crew.actors[npc].position, Vector3(0,0,6)).is_empty(), "Crew can leave the full-size outpost and return to base duties.")
  crew.elapsed = 100.0
  crew._tick(npc, 1.0)
  check(crew.data.crew[npc].phase == "Available", "Arrival is not immediately undone by autonomous work.")
  print("PLACED ", id, " at ", landing.origin)
 # The main astronaut must physically walk, stop and jump after building.
 player.position = Vector3(22, 0.05, 0)
 player.velocity = Vector3.ZERO
 player.camera_yaw = 0.0
 for step in range(20):
  await physics_frame
  player._step_locomotion(1.0 / 60.0, Vector2.ZERO, false)
 var walk_start: Vector3 = player.position
 for step in range(120):
  await physics_frame
  player._step_locomotion(1.0 / 60.0, Vector2(0,-1), false)
 check(player.position.distance_to(walk_start) > 1.0 and player.animation_player.current_animation == "moon_walk", "Player walks normally after placing all buildings.")
 for step in range(80):
  await physics_frame
  player._step_locomotion(1.0 / 60.0, Vector2.ZERO, false)
 check(player.animation_player.current_animation == "idle" and Vector2(player.velocity.x,player.velocity.z).length() < 0.01, "Player stops and idles normally after placement.")
 player._step_locomotion(1.0 / 60.0, Vector2.ZERO, true)
 check(player.velocity.y > 0.5 and not player.placing_solar, "Jump is restored after placement.")
 var shared_dock: Transform3D = placement.stations.maya_station.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0,0,8.8))
 check(not placement._station_access_is_clear("alex_station", shared_dock), "Face-to-face outposts cannot share the same NPC standing point.")
 # Exercise all three together: they must finish at their own unique dock.
 var starting_positions := {"crew_briefing": Vector3(3.4,0,3.8), "water_recycler": Vector3(0.8,0,3), "food_storage": Vector3(0,0,-4)}
 for npc in crew.IDS:
  crew.actors[npc].position = starting_positions[npc]
  crew.data.crew[npc].position = starting_positions[npc]
  crew.request_station_arrival(npc)
 await physics_frame
 for step in range(600):
  for npc in crew.IDS: crew._tick(npc, 0.25)
  await physics_frame
  if crew.IDS.all(func(npc): return crew.data.crew[npc].phase == "Available" and crew.actors[npc].position.distance_to(crew.homes[npc]) < 0.65): break
 for station_id in placement.Station.DEFINITIONS:
  var npc: String = placement.Station.DEFINITIONS[station_id].npc
  var expected: Vector3 = placement.stations[station_id].global_transform * placement.Station.dock(station_id)
  check(crew.actors[npc].global_position.distance_to(expected) < 0.65, "Simultaneous return reaches assigned outpost: " + station_id)
  for other in crew.IDS:
   if other != npc:
    check(crew.actors[other].global_position.distance_to(expected) > 1.5, "No second NPC occupies " + station_id)
  print("ASSIGNMENT ", npc, " -> ", station_id, " at ", crew.actors[npc].position)
 var Save = preload("res://src/runtime/mission_save.gd")
 var saved: Dictionary = Save.capture(session)
 check(Save.decode(saved).get("station_placements", {}).size() == 3, "All three station transforms round-trip through save validation.")
 var legacy: Dictionary = saved.duplicate(true)
 legacy.erase("station_placements")
 check(not Save.decode(legacy).is_empty(), "Existing saves remain compatible.")
 var bad: Dictionary = saved.duplicate(true)
 bad.station_placements = {"unknown": Transform3D.IDENTITY}
 check(Save.decode(bad).is_empty(), "Unknown station IDs are rejected.")
 bad.station_placements = {"maya_station": Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO), Vector3.ZERO)}
 check(Save.decode(bad).is_empty(), "Degenerate saved transforms are rejected.")
 if placement.stations.has("sam_station"):
  placement._set_target(placement.stations.sam_station)
  placement._destroy_target()
  await physics_frame
  check(not session.station_placements.has("sam_station") and not crew.station_homes.has("food_storage"), "Destroy removes station and restores original NPC home.")
  placement._select("sam_station")
  check(placement.active, "Destroyed station can be placed again.")
  placement._cancel()
 check(not placement.placed and session.solar_placement.is_empty(), "Station placement never places or powers the solar panel.")
 world.queue_free()
 await process_frame
 Save.restore(session, saved)
 var restored := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(restored)
 current_scene = restored
 await physics_frame
 check(restored.get_node("SolarPlacement").stations.size() == 3, "Reload rebuilds all three station models.")
 check(restored.get_node("CrewFieldwork").station_homes.size() == 3, "Reload reassigns all crew homes.")
 restored.queue_free()
 await process_frame
 print("CREW STATIONS TEST: %d failures" % failures)
 quit(failures)
