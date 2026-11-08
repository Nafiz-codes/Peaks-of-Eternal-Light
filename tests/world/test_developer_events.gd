extends SceneTree
const Save = preload("res://src/runtime/mission_save.gd")
func _init(): call_deferred("run")
func run():
 var session = root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 await process_frame
 var hud = world.get_node("MissionHUD")
 var expedition = world.get_node("RoverTraining")
 var storm = world.get_node("DustStorm")
 var driver = world.get_node("RoverHull")
 assert(hud.find_child("DeveloperGoToEvent", true, false) != null)
 assert(hud.find_child("DeveloperEventChoice", true, false).item_count == 4)
 for index in [0, 1, 2, 3, 2, 2]:
  hud._developer_jump(index)
  await physics_frame
  await process_frame
  assert(not hud.panel.visible)
  assert(not Save.decode(Save.capture(session)).is_empty())
  if index == 2:
   assert(not driver.active)
   storm._process(2.0)
   assert(storm.active and storm.elapsed >= 2.0 and storm.elapsed < 3.0)
  else:
   assert(driver.active and driver.power_state == driver.Power.READY)
   assert(expedition.data.location == "expedition")
   assert(expedition.data.mission == (2 if index == 3 else index))
   var alt = InputEventKey.new()
   alt.keycode = KEY_ALT
   alt.pressed = true
   driver._input(alt)
   assert(hud.panel.visible)
   driver._input(alt)
   assert(not hud.panel.visible)
 assert(not expedition.developer_jump_event(4))
 expedition.transitioning = true
 assert(not expedition.developer_jump_event(0))
 expedition.transitioning = false
 print("Developer events: PASS")
 quit()
