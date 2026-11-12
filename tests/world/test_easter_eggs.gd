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
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await create_timer(1).timeout
 var eggs = world.get_node("EasterEggs")
 check(eggs.cards.size() == 4,"All four photographs spawn")
 if eggs.cards.size() != 4:
  quit(1)
  return
 var saved_positions = session.dashboard_state.easter_eggs.positions.duplicate()
 var terrain = preload("res://src/world/expedition_terrain.gd")
 for index in range(4):
  var objective: Vector2 = [terrain.SITES.alpha,terrain.SITES.gamma,terrain.SITES.ice_a,terrain.RESCUE_SITE][index]
  check(eggs.cards[index].global_position.distance_to(terrain.point(objective)) < 6,"Photograph is discoverable beside its mission")
 var driver = world.get_node("RoverHull")
 var expedition = world.get_node("RoverTraining")
 expedition.set_physics_process(false)
 driver.set_physics_process(false)
 var original_expedition: Dictionary = expedition.data.duplicate(true)
 expedition.data.location = "expedition"
 driver.active = true
 driver.global_position = eggs.cards[0].global_position + Vector3(0,0.6,1)
 eggs._process(0)
 check(eggs.nearest == 0,"Nearby rover receives E prompt")
 var key := InputEventKey.new()
 key.keycode = KEY_E
 key.pressed = true
 driver._input(key)
 check(eggs.revealing and paused,"Rover E opens reveal and pauses action")
 await create_timer(0.8).timeout
 check(eggs.quote.text == '"RIP Margaret Hamilton"',"First caption matches supplied text")
 check(eggs.artwork.rotation == 0 and eggs.artwork.scale == Vector2.ONE,"Photo finishes facing screen")
 if DisplayServer.get_name() != "headless":
  RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://.tools/easter-egg-reveal.png")
 eggs.close_reveal()
 check(not paused and not eggs.cards[0].visible,"Closing resumes and removes collected item")
 eggs.collect(0)
 check(not eggs.revealing,"Collected picture cannot be collected twice")
 driver.active = false
 var astronaut = world.get_node("Outpost/Astronaut")
 astronaut.set_physics_process(false)
 astronaut.ui_blocked = false
 astronaut.global_position = eggs.cards[1].global_position + Vector3(0,0,1)
 eggs._process(0)
 check(eggs.nearest == 1,"On-foot approach shows pickup prompt")
 for index in [1,2,3]:
  if index == 1:
   eggs._input(key)
  else:
   eggs.collect(index)
  await create_timer(0.7).timeout
  check(eggs.quote.text == '"'+eggs.TEXTS[index]+'"',"Each image has its matching caption")
  var escape := InputEventKey.new()
  escape.keycode = KEY_ESCAPE
  escape.pressed = true
  eggs._input(escape)
  check(not eggs.revealing and not paused,"Escape closes reveal and resumes gameplay")
 session.dashboard_state.rover_expedition = original_expedition
 driver.active = false
 var Save = load("res://src/runtime/mission_save.gd")
 var saved: Dictionary = Save.capture(session)
 var restored: Dictionary = Save.decode(saved)
 check(not restored.is_empty() and restored.state.easter_eggs.collected.size() == 4,"Discoveries persist through save/load")
 check(not restored.is_empty() and restored.state.easter_eggs.positions == saved_positions,"Mission-adjacent locations persist")
 # A legacy layout relocates photographs while retaining collection progress.
 session.dashboard_state.easter_eggs.erase("layout")
 session.dashboard_state.easter_eggs.positions[0] = Vector3(4000,0,55)
 for card in eggs.cards: card.queue_free()
 eggs.cards.clear()
 eggs._spawn()
 await physics_frame
 await process_frame
 check(session.dashboard_state.easter_eggs.collected.size() == 4,"Layout migration retains discoveries")
 check(session.dashboard_state.easter_eggs.positions[0].distance_to(terrain.point(terrain.SITES.alpha)) < 6,"Legacy photograph relocates beside mission")
 saved.state.erase("easter_eggs")
 check(not Save.decode(saved).is_empty(),"Older saves remain compatible")
 print("Easter eggs: ",failures," failures")
 world.queue_free()
 await process_frame
 quit(failures)
