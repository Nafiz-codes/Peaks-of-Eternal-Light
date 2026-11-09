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
 world.get_node("CrewFieldwork").set_physics_process(false)
 var hud = world.get_node("MissionHUD/SurvivalBars")
 check(hud.bars.size() == 4, "Four survival meters")
 var state = session.dashboard_state
 var original = float(state.history[0].oxygen_kg)
 state.oxygen_kg = original * 0.5
 hud._process(0)
 check(is_equal_approx(hud.bars.oxygen_kg.value / hud.bars.oxygen_kg.max_value, 0.5), "Oxygen depletion shown proportionally")
 hud.state_reference = null
 hud._process(0)
 check(is_equal_approx(hud.bars.oxygen_kg.value / hud.bars.oxygen_kg.max_value, 0.5), "Saved depleted reserve does not appear full")
 state.oxygen_kg = 0
 hud._process(0)
 check(hud.bars.oxygen_kg.value == 0, "Empty reserve is shown empty")
 for key in hud.RESOURCES:
  check(hud.captions[key].text == hud.RESOURCES[key][0], "Only resource names are displayed")
 state.oxygen_kg = original
 state.consecutive_power_depleted_sols = 0
 hud._process(0)
 await process_frame
 if DisplayServer.get_name() != "headless":
  root.get_texture().get_image().save_png("res://.tools/survival-bars.png")
 print("Survival bars: ", failures, " failures")
 world.queue_free()
 await process_frame
 quit(failures)
