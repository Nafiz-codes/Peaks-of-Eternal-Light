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
 assert(env.fog_enabled and is_equal_approx(env.fog_density, storm.FOG_DENSITY))
 assert(storm.FOG_DENSITY <= 0.25) # Dense, but not the old near-zero-visibility wall.
 assert(is_equal_approx(float(world.get_meta("storm_light_factor")), storm.VISUAL_LIGHT_FACTOR))
 assert(world.get_node("LowPolarSun").light_color.is_equal_approx(storm.DUSTY_SUN))
 assert(storm.sign_layer.visible)
 var storm_effects = session.dashboard_state.active_events.filter(func(e): return e.event_id == "dust_storm")
 assert(storm_effects.size() == 1)
 storm._process(0.5)
 assert(session.dashboard_state.active_events.filter(func(e): return e.event_id == "dust_storm").size() == 1) # Charged once
 assert(not Save.decode(Save.capture(session)).is_empty())
 if "--capture" in OS.get_cmdline_user_args():
  await create_timer(1.0).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/dust-storm-preview.png")
 storm._process(10.5)
 assert(storm.active)
 storm._process(1.0)
 assert(not storm.active and storm.elapsed == 15.0)
 assert(env.fog_density == before)
 assert(not world.has_meta("storm_light_factor") and not storm.sign_layer.visible)
 assert(world.get_node("LowPolarSun").light_color.is_equal_approx(Color("ffe5bd")))
 # Lifeline waits for Maya's storm briefings (damage, then the lost astronaut).
 assert(expedition.available_assignment() == -1 and expedition.Rules.aftermath(expedition.data) == "briefing")
 expedition.data["aftermath"] = "done"
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

