extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func run():
 var session = root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 session.start_selected_mission()
 session.dashboard_state.materials = 1000
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await physics_frame
 var placement = world.get_node("SolarPlacement")
 placement.placed = true
 placement._open_menu()
 await process_frame
 var cards: Dictionary = {}
 for card in placement.grid.get_children():
  for label in card.find_children("*", "Label", true, false):
   if label.text in ["Habitat Extension", "Comms Relay"]: cards[label.text] = card
 var player = world.get_node("Outpost/Astronaut")
 player.set_physics_process(false)
 placement.set_physics_process(false)
 world.get_node("CrewFieldwork").set_physics_process(false)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.current = true
 for entry in [["Habitat Extension", "habitat_module"], ["Comms Relay", "comms_relay"]]:
  session.dashboard_state.materials = 0
  placement._open_menu()
  var card: Button
  for item in placement.grid.get_children():
   for caption in item.find_children("*", "Label", true, false):
    if caption.text == entry[0]: card = item
  check(card != null and not card.disabled, "NASA card is accessible")
  check(card.find_children("*", "SubViewport", true, false).size() == 1, "NASA thumbnail exists")
  card.pressed.emit()
  check(placement.active and placement.selected_id == entry[1], "Card opens mouse placement")
  var before: float = session.dashboard_state.materials
  placement._cancel()
  check(session.dashboard_state.materials == before and not player.placing_solar, "Cancel is free and restores movement")
  session.dashboard_state.materials = 1000
  placement._select(entry[1])
  var found := false
  for z in [-9,-4,1,6,10]:
   for x in [-10,-5,0,5,10]:
    var spot := Vector3(x,0,z)
    player.global_position = spot + Vector3(0,0,8)
    camera.global_position = spot + Vector3(0,7,1)
    camera.look_at(spot)
    placement.yaw = PI / 2
    placement._physics_process(0)
    if placement.valid:
     found = true
     break
   if found: break
  check(found, "NASA model has valid ground placement")
  if not found:
   placement._cancel()
   continue
  var expected: Transform3D = placement.panel.global_transform
  placement.confirm()
  check(session.building_placements.get(entry[1]) == expected, "Exact position and rotation retained")
  check(not placement.active and not player.placing_solar, "Confirmation restores normal movement")
  var paid: float = session.dashboard_state.materials
  placement._select(entry[1])
  check(placement.active, "Already queued item remains accessible")
  placement.panel.global_transform = expected
  placement.valid = true
  placement.confirm()
  check(session.dashboard_state.materials == paid, "Queued location changes do not charge twice")
 check(session.dashboard_state.construction_queue.size() == 2, "Both buildings retain construction times")
 var Save = load("res://src/runtime/mission_save.gd")
 var saved: Dictionary = Save.capture(session)
 var restored: Dictionary = Save.decode(saved)
 check(not restored.is_empty() and restored.building_placements == session.building_placements, "Building transforms survive save and load")
 var catalog = session.dashboard_simulator.construction.structures
 var factory = load("res://src/world/nasa_buildings.gd")
 # Reproduce confirmed sites, including reconstruction after loading a save.
 world.construction_view.sync_completed({}, catalog)
 world.construction_view.sync_completed({}, catalog, restored.building_placements, session.dashboard_state.construction_queue)
 for id in factory.MODELS:
  var site = world.construction_view.completed[id]
  check(site.get_meta("pending") and str(site.name).begins_with("Building_"), "Solid construction site remains pending")
  check(site.global_transform == session.building_placements[id], "Pending site restores its chosen transform")
  check(site.find_children("*", "StaticBody3D", true, false).size() == 1, "Pending site has exactly one collision body")
  for mesh in site.get_node("NASAModel").find_children("*", "MeshInstance3D", true, false):
   check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Confirmed model casts shadows")
   if mesh.material_override is StandardMaterial3D:
    check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Confirmed model has no hologram override")
 world.construction_view.sync_completed({}, catalog)
 for id in factory.MODELS:
  check(world.construction_view.show_preview(id, catalog), "NASA preview exists")
  var preview = world.construction_view.preview
  check(preview.find_children("*", "StaticBody3D", true, false).is_empty(), "Preview has no blocking collision")
  for mesh in preview.find_children("*", "MeshInstance3D", true, false):
   check(mesh.material_override != null, "Preview uses hologram material")
 world.construction_view.clear_preview()
 world.construction_view.sync_completed({"habitat_module": 0, "comms_relay": 0}, catalog, session.building_placements)
 for id in factory.MODELS:
  var completed = world.construction_view.completed[id]
  check(completed.global_transform == session.building_placements[id], "Completion uses chosen location and rotation")
  var model = completed.get_node("NASAModel")
  var bounds: AABB = factory.mesh_bounds(model)
  check(absf(bounds.position.y) < 0.001, "NASA model base rests on ground")
  check(absf(bounds.get_center().x) < 0.001 and absf(bounds.get_center().z) < 0.001, "Entire installation is centered for placement")
  check(model.find_child("Foundation", true, false) != null, "Completed installation includes its foundation")
  var astronaut_height: float = world.ASTRONAUT_HEIGHT
  if id == "habitat_module":
   check(bounds.size.y > astronaut_height * 3.0 and bounds.size.y < astronaut_height * 3.6, "Two-level habitat has astronaut-scale headroom")
   check(model.find_child("AccessStep", true, false) != null, "Habitat includes suited-crew access steps")
  else:
   check(bounds.size.y > astronaut_height * 2.8 and bounds.size.y < astronaut_height * 3.2, "Relay mast is realistically taller than the astronaut")
   check(model.find_child("RadioCabinet", true, false) != null and model.find_child("MastBrace", true, false) != null, "Relay includes radio equipment and structural bracing")
  var shape = completed.find_children("*", "CollisionShape3D", true, false)[0]
  check(shape.shape.size.is_equal_approx(bounds.size), "Collision matches full NASA model dimensions")
 placement._open_menu()
 for scroll in placement.build_menu.find_children("*", "ScrollContainer", true, false): scroll.scroll_vertical = 1000
 await create_timer(0.5).timeout
 if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://.tools/nasa-build-menu.png")
 print("NASA buildings: ", failures, " failures")
 world.queue_free()
 await process_frame
 quit(failures)
