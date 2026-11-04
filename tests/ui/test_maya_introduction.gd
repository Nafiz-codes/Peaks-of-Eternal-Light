extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	change_scene_to_file("res://scenes/lunar_outpost_3d.tscn")
	await scene_changed
	var maya = current_scene.get_node("Outpost/crew_briefing")
	var initial: Vector3 = maya.position
	await create_timer(3.5).timeout
	var tracker = current_scene.get_node("MissionTracker")
	tracker._process(0.0)
	assert(tracker.title.text == "◆  Talk with Maya")
	assert(maya.position.distance_to(initial) > 0.1)
	assert(not tracker.marker.text.contains("→") and not tracker.marker.text.contains("←"))
	current_scene._on_player_interaction("crew_briefing")
	assert(not session.maya_intro_complete)
	assert(current_scene.maya_dialogue_active)
	assert(current_scene.get_node("MayaIntroduction").LINE == "Hi I am Dr. Maya, I will be your guide throughout this journey")
	var stop: Vector3 = maya.position
	await create_timer(4.8).timeout
	assert(current_scene.maya_dialogue_active)
	assert(current_scene.get_node("MayaIntroduction").content.get_child(1).name == "GoldDivider")
	assert(current_scene.get_node("MayaIntroduction").content.get_child(0).get_theme_font("font").font_weight == 600)
	await create_timer(2.0).timeout
	assert(session.maya_intro_complete)
	assert(not current_scene.maya_dialogue_active)
	assert(not current_scene.get_node("Outpost/Astronaut").ui_blocked)
	assert(maya.position.is_equal_approx(stop))
	tracker._process(0.0)
	assert(tracker.title.text == "◆  " + session.dashboard_state.mission_outcome.primary_objective)
	var save = preload("res://src/runtime/mission_save.gd")
	assert(save.decode(save.capture(session)).maya_intro_complete)
	print("PASS: Maya approaches; opening objective; interaction completion; original mission resumes; save round-trip; no arrows")
	quit()
