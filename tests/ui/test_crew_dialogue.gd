extends SceneTree
const Report = preload("res://src/ui/crew_report.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1360, 820)
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var hud := world.get_node("MissionHUD")
	var player := world.get_node("Outpost/Astronaut")
	var dialogue: AcceptDialog = hud.crew_dialogue
	for id in Report.ROLES:
		world._on_player_interaction(id)
		check(dialogue.visible and player.ui_blocked, "E interaction opens a conversation and blocks movement: " + id)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialogue releases the cursor.")
		check(not "NEW UPDATE" in world.get_node("Outpost/" + id + "/StatusLabel").text, "Reading clears the update marker.")
		check(session.dashboard_state == null, "Talking does not start a mission implicitly.")
		dialogue.hide()
		check(not player.ui_blocked, "Closing restores player input.")
	check(session.start_selected_mission() == OK, "Mission starts.")
	var original := Save.state_data(session.dashboard_state)
	for id in Report.ROLES:
		check("NEW UPDATE" in world.get_node("Outpost/" + id + "/StatusLabel").text, "Mission start produces a fresh report.")
		hud.inspect_station(id)
		check("Sol 00" in Report.build(id, session.dashboard_state).status, "Report uses the actual sol.")
		check(Save.state_data(session.dashboard_state) == original, "Reading leaves simulation values unchanged.")
		dialogue.hide()
	var captured := Save.capture(session)
	check(Save.decode(captured).crew_read_reports == session.crew_read_reports, "Read markers survive save/load decoding.")
	captured.erase("crew_read_reports")
	check(not Save.decode(captured).is_empty(), "Saves from before NPC dialogue remain compatible.")
	session.advance_mission()
	await process_frame
	check("NEW UPDATE" in world.get_node("Outpost/power_console/StatusLabel").text, "Advancing a sol produces a fresh update.")
	if session.dashboard_state.pending_events.is_empty():
		session.dashboard_state.pending_events.append(session.dashboard_simulator.events[1].duplicate(true))
		session.state_changed.emit()
		await process_frame
	check(not session.dashboard_state.pending_events.is_empty(), "A real mission decision is available.")
	if not session.dashboard_state.pending_events.is_empty():
		var event: Dictionary = session.dashboard_state.pending_events[0]
		hud.inspect_station("crew_briefing")
		var report := Report.build("crew_briefing", session.dashboard_state)
		check(report.decisions[0].event_id == event.event_id, "Crew lead exposes the real pending decision.")
		dialogue._request("decision", event.event_id)
		check(not dialogue.visible and hud.event_dialog.visible and player.ui_blocked, "Decision handoff keeps player input blocked.")
		check(hud.event_dialog.live_event_id == event.event_id, "Handoff selects the requested decision.")
		hud._resolve_decision(event.event_id, event.choices[0].choice_id)
		check(session.dashboard_state.resolved_events.size() > 0, "NPC decision uses the authoritative simulator.")
		hud.event_dialog.hide()
	var water_event := {"event_id": "test_water", "effects": {"water_loss_l": 3}}
	check(Report.relevant("water_recycler", water_event) and Report.relevant("food_storage", water_event), "Alex and Sam both receive water-related decisions.")
	session.dashboard_state.mission_outcome.status = "failure"
	session.dashboard_state.mission_outcome.failure_reason = "water_depleted"
	var terminal := Report.build("crew_briefing", session.dashboard_state)
	check(terminal.terminal and terminal.decisions.is_empty() and "water depleted" in terminal.update, "Terminal reports explain outcome and suppress actions.")
	hud.inspect_station("water_recycler")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.get_node("GameMenu")._input(esc)
	check(not root.get_node("GameMenu").opened, "Escape belongs to the conversation before the pause menu.")
	root.push_input(esc)
	await process_frame
	check(not dialogue.visible and not player.ui_blocked, "Escape ends the conversation.")
	session.select_landing_site("shadow_zone")
	check(session.crew_read_reports.is_empty(), "Switching outposts resets local report markers.")
	print("Crew dialogue: %d failures." % failures)
	quit(1 if failures else 0)
