extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func capture(label: String):
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/conversation_" + label + ".png")
func run():
	root.size = Vector2i(960, 540) if "--small" in OS.get_cmdline_user_args() else Vector2i(1360, 820)
	var session = root.get_node("MissionSession")
	session.confirm_new_commander("commander-01", "Commander")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	var world = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await process_frame
	var player = world.get_node("Outpost/Astronaut")
	player.set_physics_process(false)
	var menu = world.get_node("MissionHUD").crew_dialogue
	for id in ["crew_briefing", "food_storage", "water_recycler", "crew_briefing"]:
		var actor = world.get_node("Outpost/" + id)
		player.global_position = actor.global_position + Vector3(0, 0, 1.8)
		world._on_player_interaction(id)
		check(menu.visible and menu.buttons.size() == 5, "E opens five choices")
		check(player.ui_blocked, "Player blocked during choices")
		check(root.get_node("GameMenu")._modal_visible(), "Conversation owns Escape before pause menu")
		await capture("choices_" + id)
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		menu._input(wheel)
		check(menu.selected == 3, "Wheel changes selected choice")
		var talk := InputEventKey.new()
		talk.keycode = KEY_3
		talk.pressed = true
		menu._input(talk)
		check(world.maya_dialogue_active, "Talk starts introduction")
		var dialogue = world.get_node("MayaIntroduction")
		var expected: Array = dialogue.SEQUENCES.get(id, []) if dialogue.dialogue_id != "maya_closing" else []
		while not dialogue.ending:
			check(dialogue.view.portrait.texture != null, "Correct character portrait is available")
			if not expected.is_empty():
				check(dialogue.view.speech.text == expected[dialogue.line_index][2], "Exact authored dialogue line")
			await capture(id + "_" + str(dialogue.line_index))
			dialogue.advance()
		await process_frame
		check(not world.maya_dialogue_active and not player.ui_blocked, "Conversation restores control")
	check(session.maya_intro_complete and session.crew_introductions.get("water_recycler", false) and session.crew_introductions.get("food_storage", false), "Introductions marked complete")
	var saved: Dictionary = preload("res://src/runtime/mission_save.gd").capture(session)
	check(preload("res://src/runtime/mission_save.gd").decode(saved).crew_introductions == session.crew_introductions, "Introduction flags survive save/load")
	world._on_player_interaction("crew_briefing")
	menu._choose(2)
	check(menu.visible and not world.maya_dialogue_active, "Completed introduction becomes status")
	menu._choose(0)
	check(world.get_node("CrewFieldwork").data.crew.crew_briefing.task == "follow", "Follow command connected")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	check(not menu.visible and not player.ui_blocked, "Escape restores gameplay")
	check(world.get_node("MissionTracker").visible, "Objective HUD restored")
	print("NPC conversation failures: ", failures)
	quit(failures)
