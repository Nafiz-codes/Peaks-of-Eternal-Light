extends SceneTree
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Save = preload("res://src/runtime/mission_save.gd")
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
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 await physics_frame
 await physics_frame
 var c = world.get_node("RoverTraining")
 var d = world.get_node("RoverHull")
 c.set_physics_process(false)
 d.set_physics_process(false)
 c.data.mission = 1
 c.data.completed = [0]
 c.data.location = "expedition"
 c.data.phase = "active"
 c.data.samples = ["ice_a"]
 session.dashboard_state.rover_health = 11
 c._check_damage()
 check(not c.damage_blocked(),"No warning before 90 percent damage")
 session.dashboard_state.rover_health = 10
 c._check_damage()
 check(c.damage_mode == "warning" and c.locks_drive(),"Warning stops driving at 90 percent damage")
 check(c.damage_dialog.visible,"Warning visible")
 await capture(c, "damage-dialog")
 c._damage_confirm()
 c._check_damage()
 check(not c.damage_blocked(),"Continue acknowledges warning once")
 session.dashboard_state.rover_health = 0
 c._check_damage()
 check(c.data.phase == "failed" and c.damage_mode == "failed","Destroyed rover fails mission")
 c._recall()
 c._check_circle(2)
 check(not c.transitioning and c.data.location == "expedition","Destroyed rover cannot be recovered")
 check(Rules.valid_save(c.data),"Failure state is valid for save")
 var saved: Dictionary = Save.capture(session)
 check(not Save.decode(saved).is_empty(),"Failed expedition survives save validation")
 check(Save.restore(session,saved) == OK,"Failed expedition restores")
 d.sync_state()
 c._sync()
 c._check_damage()
 check(c.data.phase == "failed" and c.damage_blocked(),"Reload cannot bypass mission failure")
 await capture(c, "damage-dialog")
 c._damage_confirm()
 check(session.dashboard_state.rover_health == 100 and c.data.phase == "active","Retry restores a playable attempt")
 check(c.data.samples.is_empty() and c.data.completed == [0] and c.data.mission == 1,"Retry resets current objectives only")
 check(d.position.distance_to(Vector3(4000,0.7,10)) < 0.1,"Retry starts at mission entrance")
 session.dashboard_state.rover_health = 5
 c._check_damage()
 check(c.damage_mode == "warning","Retry resets warning")
 c._damage_abort()
 await create_timer(1.5).timeout
 check(c.data.location == "outpost" and not c.transitioning,"Abort calls living rover back")
 check(session.dashboard_state.rover_health == 5,"Abort does not grant free repairs")
 print("EXPEDITION DAMAGE: %d failures" % failures)
 quit(1 if failures else 0)
func capture(controller: Node, label: String):
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.tools/"+label+"-"+controller.damage_mode+".png")

