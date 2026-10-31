extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var session := root.get_node("MissionSession")
	session.skip_next_startup_intro = true
	change_scene_to_file("res://scenes/startup.tscn")
	await scene_changed
	var startup := current_scene
	for attempt in range(150):
		if startup.state==startup.State.MENU_IDLE and startup.ready_for_mission: break
		await create_timer(0.1).timeout
	startup._start_mission()
	for attempt in range(100):
		if startup.opening_video != null: break
		await create_timer(0.1).timeout
	# Exercise the existing video-finished handler without waiting for the movie.
	startup._finish_opening()
	for attempt in range(100):
		if startup.commander_menu != null: break
		await create_timer(0.1).timeout
	check(startup.commander_menu != null,"Existing startup reaches commander selection")
	startup.commander_menu.select_appearance("commander-02",false)
	startup.commander_menu.name_input.text = "Planner"
	startup.commander_menu._validate()
	startup.commander_menu._confirm()
	await create_timer(3.8).timeout
	check(current_scene.name != "Startup","Startup hands off existing selector")
	for id in ["ridge_a","shadow_zone","crater_rim_b","plateau_d"]:
		if current_scene.scene_file_path != "res://scenes/lunar_landing_selector.tscn":
			change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
			await scene_changed
		session.reduce_motion = true
		current_scene.select_site(id)
		await scene_changed
		check(current_scene.name=="MissionPlanning","Selected outpost opens planning: "+id)
		check(session.commander_name()=="Planner","Identity survives planning")
		check(not root.get_node("MenuMusic").mission_active,"Planning retains pre-mission music context")
		var menu := root.get_node("GameMenu")
		menu.open_menu()
		check(menu.opened and paused,"Existing pause menu opens during planning")
		menu.close_menu()
		check(not paused,"Closing menu resumes planning")
		var ui := current_scene
		ui._choose("zone_id","south")
		ui._step(1)
		ui._adjust("battery",1)
		ui._step(0)
		check(session.planning_draft.zone_id=="south" and session.planning_draft.cargo.battery==3,"Back preserves choices")
		ui._step(-1)
		await scene_changed
		current_scene.select_site(id)
		await scene_changed
		ui = current_scene
		check(session.planning_draft.zone_id=="south" and session.planning_draft.cargo.battery==3,"Returning through selector preserves same-site draft")
		ui._choose("zone_id","compact")
		for step in range(6):
			ui._step(step)
			await process_frame
		ui._save()
		ui._adjust("battery",1)
		ui._load_save()
		check(session.planning_draft.cargo.battery==3,"Draft disk save restores choices")
		ui._approve()
		check(not session.approved_plan.is_empty(),"UI approves and saves")
		check(session.dashboard_state==null,"Planning never initializes live mission inventory")
		if DisplayServer.get_name() != "headless" and id=="plateau_d":
			root.size = Vector2i(960,720)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/planning-review.png")
			ui._step(4)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/planning-cargo.png")
			ui._step(5)
			await process_frame
			await process_frame
			ui.scroller.scroll_vertical = int(ui.scroller.get_v_scroll_bar().max_value)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/planning-review-bottom.png")
	current_scene._handoff()
	await scene_changed
	check(current_scene.name=="LunarOutpost","Approved plan hands off to existing stage")
	check(session.approved_plan.delivery_status=="pending","Handoff does not deliver cargo")
	print("MISSION PLANNING UI: %d failures" % failures)
	quit(failures)
