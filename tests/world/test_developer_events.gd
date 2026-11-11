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
 assert(hud.find_child("DeveloperEventChoice", true, false).item_count == 6)
 assert(hud.find_child("DeveloperAddResources", true, false) != null and hud.find_child("DeveloperSpeed", true, false) != null)
 for index in [0, 1, 2, 3, 2, 2, 4, 5]:
  hud._developer_jump(index)
  await physics_frame
  await process_frame
  assert(not hud.panel.visible)
  assert(not Save.decode(Save.capture(session)).is_empty())
  if index == 4:
   assert(not driver.active and expedition.Rules.debrief(expedition.data) == "pending")
  elif index == 5:
   assert(not driver.active and expedition.Rules.radiation(expedition.data) == "alert" and expedition.available_assignment() == -1)
  elif index == 2:
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
 assert(not expedition.developer_jump_event(6))
 var water: float = session.dashboard_state.water_l
 hud.find_child("DeveloperAddResources", true, false).pressed.emit()
 assert(session.dashboard_state.water_l == water + 150.0)
 hud.find_child("DeveloperRemoveResources", true, false).pressed.emit()
 assert(session.dashboard_state.water_l == water)
 var speed: Button = hud.find_child("DeveloperSpeed", true, false)
 speed.pressed.emit()
 assert(Engine.time_scale == 2.0)
 for step in 3: speed.pressed.emit()
 assert(Engine.time_scale == 1.0)
 expedition.transitioning = true
 assert(not expedition.developer_jump_event(0))
 expedition.transitioning = false
 print("Developer events: PASS")
 quit()
