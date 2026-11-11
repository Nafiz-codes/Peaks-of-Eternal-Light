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
		var first_meeting: bool = not session.maya_intro_complete if id == "crew_briefing" else not session.crew_introductions.get(id, false)
		world._on_player_interaction(id)
		if first_meeting:
			check(world.maya_dialogue_active and not menu.visible, "Each first meeting starts introduction directly")
		if not world.maya_dialogue_active:
			check(menu.visible and menu.buttons.size() == 6 and not menu.buttons[5].visible, "E opens five choices")
			check(not menu.view.portrait.visible and not menu.view.get_node("DialogueColumn").visible, "Menu shows only choices")
			check(player.ui_blocked, "Player blocked during choices")
			check(root.get_node("GameMenu")._modal_visible(), "Conversation owns Escape before pause menu")
			await capture("choices_" + id)
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			menu._input(wheel)
			check(menu.selected == 1, "Wheel changes selected choice")
			var talk := InputEventKey.new()
			menu._select(0)
			talk.keycode = KEY_E
			talk.pressed = true
			menu._input(talk)
		check(world.maya_dialogue_active, "Talk starts introduction")
		var dialogue = world.get_node("MayaIntroduction")
		var expected: Array = dialogue.SEQUENCES.get(id, []) if dialogue.dialogue_id != "maya_closing" else []
		while not dialogue.ending:
			check(dialogue.view.portrait.visible, "Speaking character portraits are visible")
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
	check(not menu.view.portrait.visible and not menu.view.get_node("DialogueColumn").visible, "Reopened menu clears previous expression")
	menu._choose(0)
	check(menu.view.portrait.visible and menu.view.get_node("DialogueColumn").visible, "Selecting status reveals expression and dialogue")
	check(menu.visible and not world.maya_dialogue_active, "Completed introduction becomes status")
	menu._choose(1)
	check(world.get_node("CrewFieldwork").data.crew.crew_briefing.task == "follow", "Follow command connected")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	check(not menu.visible and not player.ui_blocked, "Escape restores gameplay")
	check(world.get_node("MissionTracker").visible, "Objective HUD restored")
	for id in ["food_storage", "water_recycler"]:
		player.global_position = world.get_node("Outpost/" + id).global_position + Vector3(0, 0, 1.8)
		world._on_player_interaction(id)
		check(menu.visible and not world.maya_dialogue_active, "Repeat NPC interaction opens menu")
		check(not menu.view.portrait.visible and not menu.view.get_node("DialogueColumn").visible, "Repeat menu hides portraits and dialogue")
		menu._choose(0)
		check(menu.view.portrait.visible, "NPC status shows expression after selection")
		menu.hide()
	var tracker = world.get_node("MissionTracker")
	session.solar_placement = {"transform": Transform3D.IDENTITY}
	session.station_placements = {"maya_station": Transform3D.IDENTITY, "alex_station": Transform3D.IDENTITY}
	tracker._process(0)
	check(tracker.title.text.contains("Build the solar"), "Incomplete construction keeps build objective")
	check(tracker.detail.text.contains("Solar panels: 1/8") and tracker.detail.text.contains("Workstations: 2/3"), "Build objective counts separate solar panel and workstations")
	session.extra_panels = [{"transform": Transform3D.IDENTITY, "kwh_per_sol": 1.0}]
	tracker._process(0)
	check(tracker.detail.text.contains("Solar panels: 2/8"), "Additional solar panels increment total")
	session.extra_panels = []
	session.station_placements["sam_station"] = Transform3D.IDENTITY
	tracker._process(0)
	check(tracker.title.text.contains("Speak with Maya"), "Complete construction points to Maya")
	player.global_position = world.get_node("Outpost/crew_briefing").global_position + Vector3(0, 0, 1.8)
	world._on_player_interaction("crew_briefing")
	menu._choose(0)
	var briefing = world.get_node("MayaIntroduction")
	check(briefing.dialogue_id == "rover_briefing" and briefing.lines.size() == 3, "Post-build Maya briefing has three lines")
	check(briefing.lines[0][1] == "smiling" and briefing.lines[2][1] == "confident", "Maya uses encouraging expressions")
	briefing.advance()
	check(briefing.view.speech.text == "How will I control the rover?" and briefing.view.portrait.visible, "Player asks about rover control with player portrait")
	briefing.advance()
	check(not session.crew_introductions.get("rover_briefing", false), "Briefing flag waits for final line")
	briefing.advance()
	await process_frame
	tracker._process(0)
	check(tracker.title.text.contains("Go to the Lander and Drive the Rover"), "Briefing directs player to lander")
	var restored: Dictionary = preload("res://src/runtime/mission_save.gd").decode(preload("res://src/runtime/mission_save.gd").capture(session))
	check(not restored.is_empty() and restored.crew_introductions.get("rover_briefing", false), "Rover briefing completion survives save/load")
	world._on_player_interaction("crew_briefing")
	menu._choose(0)
	check(not world.maya_dialogue_active, "Rover briefing does not repeat")
	menu.hide()
	world.get_node("RoverHull").active = true
	tracker._process(0)
	check(not tracker.title.text.contains("Go to the Lander"), "Driving replaces lander objective with expedition objective")
	world.get_node("RoverHull").active = false
	var training = world.get_node("RoverTraining")
	training.data.completed = [0, 1]
	training.data.mission = -1
	training.data["aftermath"] = "briefing"
	world.get_node("RoverHull").active = true
	tracker._process(0)
	check(tracker.title.text.contains("Press R to exit Rover and talk to Maya."), "Two rover missions show exit-and-talk objective")
	check(tracker.detail.position.y >= tracker.title.position.y + tracker.title.get_minimum_size().y + 6, "Objective and instructions do not overlap")
	check(training.hud.result.position.y > tracker.detail.position.y + tracker.detail.get_minimum_size().y, "Rover status stays below instructions")
	world.get_node("RoverHull").active = false
	menu.open_conversation("crew_briefing")
	menu._select(1)
	for key in [KEY_ENTER, KEY_SPACE, KEY_2]:
		var ignored := InputEventKey.new()
		ignored.keycode = key
		ignored.pressed = true
		menu._input(ignored)
		check(not menu.view.portrait.visible, "Only E confirms menu options")
	check(menu.buttons[1].mouse_filter == Control.MOUSE_FILTER_IGNORE, "Mouse clicks cannot activate options")
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_E
	confirm.pressed = true
	menu._input(confirm)
	check(menu.view.portrait.visible, "E confirms selected option")
	check(not menu.view.choices.visible, "Response hides action choices")
	menu._input(confirm)
	check(not menu.visible and not player.ui_blocked, "Next E closes response and restores gameplay")
	check(world.get_node("MissionHUD").help_hint.text.is_empty(), "Alt and camera hints removed")
	var access = world.get_node("LanderAccess")
	var driver = world.get_node("RoverHull")
	access.inside = true
	player.global_position = access.seat_eye - Vector3(0, 1.1, 0)
	player.set_seated(true, access.seat_eye)
	driver.active = true
	player.ui_blocked = true
	driver.camera.make_current()
	training.data.mission = 0
	training.data.location = "expedition"
	training.data.phase = "active"
	training.data.completed = []
	training.data.surveys = ["alpha", "beta", "gamma"]
	await training._transition(false)
	check(not driver.active and not player.ui_blocked, "Return transition restores player input")
	check(access.inside and player.seated and not driver.camera.current, "Return restores seated lander camera")
	check(training.data.completed.has(0) and training.data.location == "outpost", "Return retains mission completion")
	menu.open_conversation("crew_briefing")
	menu._select(1)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	menu._input(right_click)
	check(menu.response_open and menu.visible, "Right click selects highlighted dialogue option")
	menu._input(right_click)
	check(not menu.visible and not player.ui_blocked, "Right click dismisses response")
	training.data["radiation"] = "done"
	tracker._process(0)
	check(tracker.title.text.contains("Take control of the Rover again"), "On-foot next mission points to rover controls")
	driver.active = true
	driver.power_state = driver.Power.READY
	player.ui_blocked = true
	driver.camera.make_current()
	driver.position = training.departure.position + Vector3.UP * 0.7
	driver.speed = 0
	training.armed = true
	training._check_circle(1)
	await create_timer(1.5).timeout
	check(training.data.location == "expedition" and training.data.mission == 1, "Purple departure starts water ice mission")
	check(driver.active and driver.camera.current and player.ui_blocked, "Departure retains rover control")
	await training._transition(false)
	check(driver.active and training.data.location == "expedition", "Incomplete ice mission cannot return")
	training.data.samples = ["ice_a", "ice_b", "ice_c"]
	driver.position = training.extraction.position + Vector3.UP * 0.7
	driver.speed = 0
	training.armed = true
	training._check_circle(1)
	await create_timer(1.5).timeout
	check(training.data.completed.has(1) and training.data.location == "outpost", "Completed ice extraction returns to outpost")
	check(not driver.active and access.inside and player.seated and not player.ui_blocked, "Completed ice mission hands control back to player")
	training.data["dust_storm_complete"] = false
	menu.open_conversation("food_storage")
	check(not menu.buttons[5].visible, "Alex option hidden before dust clears")
	menu.hide()
	training.data["dust_storm_complete"] = true
	menu.open_conversation("food_storage")
	check(menu.buttons[5].visible, "Sam offers Alex conversation after storm")
	menu._select(5)
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.position = Vector2(-100, -100)
	left_click.pressed = true
	menu._input(left_click)
	var sam_dialogue = world.get_node("MayaIntroduction")
	check(sam_dialogue.dialogue_id == "sam_alex", "Left click selects Alex option")
	check(sam_dialogue.view.portrait.visible and sam_dialogue.view.speech.text.begins_with("Sam, have you heard"), "Player question has portrait")
	sam_dialogue.advance()
	check(sam_dialogue.view.portrait.visible and sam_dialogue.lines[1][1] == "concerned", "Sam uses concerned expression")
	sam_dialogue.advance()
	await process_frame
	check(not world.maya_dialogue_active and not player.ui_blocked, "Sam conversation restores gameplay")
	training.data.completed.append(2)
	menu.open_conversation("food_storage")
	check(not menu.buttons[5].visible, "Alex option hidden after rescue")
	menu.hide()
	for variant in ["commander-01", "commander-02", "commander-03", "commander-04"]:
		session.confirm_new_commander(variant, "Commander")
		menu.open_conversation("food_storage")
		menu.view.present("player", "How will I control the rover?", "neutral")
		var texture: AtlasTexture = menu.view.portrait.texture
		check(texture != null and texture.atlas.resource_path.contains(variant + "-dialogue-transparent"), "Selected player appearance uses transparent sheet")
		check(texture.atlas.get_image().get_pixel(0, 0).a < 0.1, "Player background contains transparency")
		await capture("transparent_" + variant)
		menu.hide()
	print("NPC conversation failures: ", failures)
	quit(failures)
