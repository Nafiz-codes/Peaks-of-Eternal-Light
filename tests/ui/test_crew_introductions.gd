extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var session := root.get_node("MissionSession")
 session.select_landing_site("ridge_a")
 session.start_selected_mission()
 var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await create_timer(0.5).timeout
 var player := world.get_node("Outpost/Astronaut")
 player.set_physics_process(false)
 check(not world.maya_dialogue_active, "Dialogue waits for an E interaction.")
 var lines := [
  ["crew_briefing", "Dr. Maya Chen", "Welcome, Commander! I'm Dr. Maya Chen, your flight engineer and instructor. I'll guide you through the equipment, scientific data, and mission procedures."],
  ["water_recycler", "Dr. Alex Rivera", "Dr. Alex Rivera, planetary geologist. I'm here to help us understand the Moon's terrain, history, and potential resources."],
  ["food_storage", "Sam Okafor", "And I'm Sam Okafor, robotics and habitat engineer. Give me the equipment, and I'll help turn it into a functioning base."],
  ["crew_briefing", "Dr. Maya Chen", "We all have our specialties, Commander. But you'll be making the final decisions."]
 ]
 for speech in lines:
  var actor := world.get_node("Outpost/" + str(speech[0])) as Node3D
  player.global_position = actor.global_position + Vector3(0,0,8)
  world._on_player_interaction(speech[0])
  check(not world.maya_dialogue_active, "Introductions require approaching the correct NPC.")
  player.global_position = actor.global_position + Vector3(0,0,1.8)
  world._on_player_interaction(speech[0])
  check(world.maya_dialogue_active and player.ui_blocked, "E starts the selected NPC introduction.")
  var dialogue := world.get_node("MayaIntroduction")
  check(dialogue.content.get_child(0).text == speech[1], "Correct speaker name.")
  check(dialogue.content.get_child(2).text == speech[2], "User's dialogue is reproduced exactly.")
  check(dialogue.content.get_child(1).name == "GoldDivider", "Gold glowing divider is retained.")
  check(dialogue.content.modulate.a == 0.0, "Dialogue begins faded out.")
  var stop := actor.global_position
  world._on_player_interaction("water_recycler")
  check(world.dialogue_speaker == speech[0], "Repeated E cannot replace the active speaker.")
  await create_timer(0.25).timeout
  check(dialogue.content.modulate.a > 0.99, "Fast fade-in completes.")
  check(not world.get_node("SolarPlacement").hud.visible, "Build hints do not overlap subtitles.")
  if "--capture" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.tools/intro_" + dialogue.dialogue_id + ".png")
  await create_timer(5.6).timeout
  check(world.maya_dialogue_active and dialogue.content.modulate.a > 0.99, "Text remains readable for the six-second hold.")
  check(actor.global_position.is_equal_approx(stop), "Speaking NPC stays in place.")
  await create_timer(0.65).timeout
  check(not world.maya_dialogue_active and not player.ui_blocked, "Fade-out restores normal movement.")
  check(world.dialogue_speaker.is_empty(), "Speaker hold is released.")
 check(session.maya_intro_complete and session.crew_introductions.get("water_recycler",false) and session.crew_introductions.get("food_storage",false) and session.crew_introductions.get("maya_closing",false), "All four introductions complete independently.")
 world._on_player_interaction("crew_briefing")
 check(not world.maya_dialogue_active and world.get_node("MissionHUD").crew_dialogue.visible, "Later E interactions retain existing crew reports and actions.")
 world.get_node("MissionHUD").crew_dialogue.hide()
 var Save = preload("res://src/runtime/mission_save.gd")
 var saved: Dictionary = Save.capture(session)
 check(Save.decode(saved).crew_introductions == session.crew_introductions, "Introduction completion survives save/load.")
 saved.erase("crew_introductions")
 check(not Save.decode(saved).is_empty(), "Older saves remain valid.")
 saved.crew_introductions = {"food_storage": "invalid"}
 check(Save.decode(saved).is_empty(), "Invalid saved introduction flags are rejected.")
 session.reset_current_mission()
 check(session.crew_introductions.is_empty() and not session.maya_intro_complete, "New mission restores all introductions.")
 world.queue_free()
 await physics_frame
 await process_frame
 print("CREW INTRODUCTIONS: %d failures" % failures)
 quit(failures)
