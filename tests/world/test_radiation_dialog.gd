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
 await physics_frame
 var state = session.dashboard_state
 state.power_kwh = 100
 state.water_l = 100
 state.oxygen_kg = 100
 state.food_kg = 100
 var continuation := {"count":0}
 var done := func(): continuation.count += 1
 for shield in [false,true]:
  world._ask_shield_choice(done)
  var dialog: ConfirmationDialog
  for child in world.get_children():
   if child is ConfirmationDialog and child.visible: dialog = child
  check(dialog != null,"Shield choice appears")
  if dialog == null: continue
  check(dialog.get_script() == load("res://src/ui/rover_damage_dialog.gd"),"Radiation uses the same themed dialog")
  check(dialog.ok_button_text.to_lower() == "shield them" and dialog.cancel_button_text.to_lower() == "leave them","Radiation choices retained")
  check(dialog.message.text.to_lower().contains("40% less") and dialog.message.text.to_lower().contains("10 kwh"),"Radiation consequences and cost retained")
  check(world.get_node("Outpost/Astronaut").ui_blocked,"Dialog blocks walking")
  if DisplayServer.get_name() != "headless":
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.tools/radiation-gray.png")
  if shield: dialog.confirmed.emit()
  else: dialog.canceled.emit()
  await process_frame
  check(not world.get_node("Outpost/Astronaut").ui_blocked,"Answer restores walking")
  check(continuation.count == (2 if shield else 1),"Choice continues exactly once")
  check(state.structures_shielded == shield,"Choice applies shielding only when selected")
 check(is_equal_approx(state.power_kwh,90),"Shield choice charges the original cost")
 print("RADIATION DIALOG: %d failures" % failures)
 quit(1 if failures else 0)
