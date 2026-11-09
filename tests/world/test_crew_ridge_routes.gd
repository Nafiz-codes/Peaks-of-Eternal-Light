extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func ridge(height: float) -> ConcavePolygonShape3D:
 var shape := ConcavePolygonShape3D.new()
 var faces := PackedVector3Array()
 for span in [[-3.0, 0.0, 0.0, height], [0.0, height, 3.0, 0.0]]:
  var a := Vector3(span[0],span[1],-2)
  var b := Vector3(span[0],span[1],2)
  var c := Vector3(span[2],span[3],2)
  var d := Vector3(span[2],span[3],-2)
  faces.append_array(PackedVector3Array([a,c,b,a,d,c]))
 shape.set_faces(faces)
 return shape
func run():
 var world := Node3D.new()
 root.add_child(world)
 var outpost := Node3D.new()
 outpost.name = "Outpost"
 world.add_child(outpost)
 for id in ["water_recycler", "food_storage", "crew_briefing"]:
  var actor := Node3D.new()
  actor.name = id
  outpost.add_child(actor)
  var body := StaticBody3D.new()
  body.name = "CrewBody"
  actor.add_child(body)
 var player := StaticBody3D.new()
 player.name = "Astronaut"
 outpost.add_child(player)
 var surface := Node3D.new()
 surface.name = "Regolith"
 world.add_child(surface)
 var body := StaticBody3D.new()
 body.name = "LunarSurfaceCollision"
 surface.add_child(body)
 var collision := CollisionShape3D.new()
 collision.shape = ridge(0.8)
 body.add_child(collision)
 await physics_frame
 await physics_frame
 var routes = load("res://src/world/crew_routes.gd").new(world,14)
 check(routes.clear_segment(Vector3(-2.9,0.027,0),Vector3(2.9,0.027,0)), "Walkable ridge can be crossed")
 var peak: Dictionary = routes.ground(Vector3.ZERO)
 check(not peak.is_empty() and absf(peak.position.y - 0.8) < 0.01, "Grounding finds ridge above endpoint interpolation")
 collision.shape = ridge(2.5)
 await physics_frame
 await physics_frame
 check(not routes.clear_segment(Vector3(-2.9,0.083,0),Vector3(2.9,0.083,0)), "Unsafe ridge between low endpoints blocks route")
 print("Crew ridge routes: ", failures, " failures")
 world.queue_free()
 await process_frame
 quit(failures)

