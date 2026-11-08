extends SceneTree
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Save = preload("res://src/runtime/mission_save.gd")
func _init(): call_deferred("run")
func run():
 var session = root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 session.start_selected_mission()
 session.maya_intro_complete = true
 var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 await process_frame
 var expedition = world.get_node("RoverTraining")
 var storm = world.get_node("DustStorm")
 storm.set_process(false)
 var env = world.get_node("LunarEnvironment").environment
 var before = env.fog_density
 storm._process(1.0)
 assert(not storm.active)
 expedition.data.completed = [0, 1]
 expedition.data.mission = -1
 assert(expedition.available_assignment() == -1)
 storm._process(3.0)
 assert(storm.active and storm.intensity > 0.99)
 assert(env.fog_enabled and is_equal_approx(env.fog_density, 0.85))
 assert(not Save.decode(Save.capture(session)).is_empty())
 if "--capture" in OS.get_cmdline_user_args():
  await create_timer(1.0).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/dust-storm-preview.png")
 storm._process(11.0)
 assert(storm.active)
 storm._process(1.0)
 assert(not storm.active and storm.elapsed == 15.0)
 assert(env.fog_density == before)
 assert(expedition.available_assignment() == 2)
 storm._process(1.0)
 assert(not storm.active)
 assert(not Save.decode(Save.capture(session)).is_empty())
 expedition.data.erase("dust_storm_complete")
 expedition.data.dust_storm_elapsed = 8.0
 storm._process(1.0)
 assert(storm.active and storm.elapsed == 9.0)
 world.remove_child(storm)
 assert(env.fog_density == before)
 storm.free()
 assert(Rules.valid_save(expedition.data))
 expedition.data.dust_storm_elapsed = -1.0
 assert(not Rules.valid_save(expedition.data))
 print("Dust storm: PASS")
 quit()

