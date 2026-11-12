extends SceneTree
const Terrain = preload("res://src/world/expedition_terrain.gd")
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func run():
 var session = root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 var controller = world.get_node("RoverTraining")
 check(controller.developer_jump_event(3),"Lifeline opens")
 controller.set_physics_process(false)
 var driver = controller.driver
 driver.set_physics_process(false)
 driver.active = true
 driver.power_state = driver.Power.READY
 controller._update_landscape_visibility()
 await process_frame
 await process_frame
 check(controller.seated,"Alex is seated")
 check(controller.crew.global_position.distance_to(Terrain.point(Terrain.RESCUE_SITE)) < 0.01,"Alex is at the search location")
 check(controller._navigation().destination.distance_to(controller.crew.global_position) < 0.01,"Search marker leads to Alex")
 var vertices = controller.seat_pose.posed_vertices(controller.crew_visual)
 check(vertices.size() > 100,"Check actual posed suit geometry")
 var clearance := INF
 var top := -INF
 for p in vertices:
  clearance = minf(clearance,p.y-controller._rescue_ground_height(p))
  top = maxf(top,p.y-controller.crew.global_position.y)
 print("POSE: vertices=%d clearance=%.4f top=%.4f" % [vertices.size(),clearance,top])
 check(clearance >= 0.005,"No suit vertices below terrain")
 check(clearance < 0.08,"Seated suit touches ground without floating")
 check(top > 0.6 and top < 1.6,"Seated astronaut has visible sitting height")
 driver.global_position = Terrain.point(Terrain.RESCUE_SITE+Vector2(0,-4))+Vector3.UP*0.7
 driver.heading = 0
 driver._sync_visual(1)
 check(controller.scanner.validate(driver,controller.targets.astronaut) == "","Alex is visible and reachable for rescue")
 if DisplayServer.get_name() != "headless":
  # Independently verify the renderer's skinned geometry, not just CPU fitting.
  var rendered_clearance := INF
  for node in controller.crew_visual.find_children("*","MeshInstance3D",true,false):
   if node.skin == null: continue
   var mesh = node.bake_mesh_from_current_skeleton_pose()
   for surface in range(mesh.get_surface_count()):
    for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
     var p: Vector3 = node.global_transform*vertex
     rendered_clearance = minf(rendered_clearance,p.y-controller._rescue_ground_height(p))
  check(rendered_clearance >= 0.005 and rendered_clearance < 0.08,"Rendered suit rests above terrain")
  var camera := Camera3D.new()
  world.add_child(camera)
  camera.global_position = controller.crew.global_position+Vector3(3,2,-4)
  camera.look_at(controller.crew.global_position+Vector3.UP*0.65)
  camera.make_current()
  world.get_node("LowPolarSun").light_energy = 1.0
  await create_timer(1).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/lifeline-grounded.png")
 var original: Transform3D = controller.seat_pose.original_visual_transform
 controller._physics_process(0.01)
 check(controller.data.discovered,"Approaching the search marker discovers Alex")
 controller.handle_key(KEY_E)
 check(controller.data.stabilized and not controller.seated,"Rescue interaction restores standing pose")
 check(controller.crew_visual.transform.is_equal_approx(original),"Standing visual offset is fully restored")
 print("LIFELINE PLACEMENT: %d failures" % failures)
 quit(1 if failures else 0)
