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
 await physics_frame
 await physics_frame
 var driver = world.get_node("RoverHull")
 var controller = world.get_node("RoverTraining")
 driver.set_physics_process(false)
 controller.set_physics_process(false)
 controller.landscape.show()
 for point in [Vector2(420,420),Vector2(-420,420),Vector2(420,-420),Vector2(-420,-420),Vector2(420,230)]:
  check(is_equal_approx(Terrain.horizon_height(point),Terrain.height_at(point.x,point.y)), "Horizon joins ridge exactly")
  check(absf(Terrain.horizon_height(point*1.001)-Terrain.height_at(point.x,point.y)) < 0.3,"No abrupt cliff at horizon seam")
 var terrain = controller.landscape
 for name in ["MissionGround","MissionHorizon"]:
  var mesh = terrain.get_node(name).mesh
  var arrays = mesh.surface_get_arrays(0)
  var vertices = arrays[Mesh.ARRAY_VERTEX]
  var bad := 0
  for i in range(0,vertices.size(),3):
   if (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).y <= 0: bad += 1
  check(bad == 0, name+": all triangles face upward without holes")
 for point in [Vector2(-210,170),Vector2(260,230),Vector2(20,350),Vector2(410,230)]:
  driver.global_position = Terrain.point(point)+Vector3.UP*0.7
  for yaw in range(16):
   driver.camera_yaw = TAU*yaw/16.0
   driver.camera_elevation = 0.12
   driver._update_camera()
   var query = PhysicsShapeQueryParameters3D.new()
   var sphere = SphereShape3D.new()
   sphere.radius = 0.25
   query.shape = sphere
   query.transform.origin = driver.camera.global_position
   query.exclude = [driver.get_rid()]
   check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Camera clears ridge at orbit "+str(yaw))
 if DisplayServer.get_name() != "headless":
  driver.global_position = Terrain.point(Vector2(-170,190))+Vector3.UP*0.7
  driver.camera_yaw = 1.2
  driver.camera_elevation = 0.38
  driver._update_camera()
  driver.camera.make_current()
  await create_timer(1).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/mission-ridges-fixed.png")
 print("MISSION RIDGES: %d failures" % failures)
 quit(1 if failures else 0)
