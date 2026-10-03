extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _run() -> void:
	var session := root.get_node("MissionSession")
	var simulator := preload("res://src/simulation/mission_simulator.gd").new()
	check(simulator.load_contracts() == OK, "Real source/content contracts load.")
	var completed := 0
	var resolved := 0
	for site in simulator.sites:
		session.dashboard_state = null
		session.dashboard_simulator = null
		session.select_landing_site(str(site.site_id))
		var outpost := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(outpost)
		await process_frame
		var hud := outpost.get_node("MissionHUD")
		hud.advance_turn()
		var reference: Variant = simulator.begin_mission(str(site.site_id))
		check(session.dashboard_state != null and session.dashboard_state.sol == 0, "World starts the selected mission.")
		var safety := 0
		while session.dashboard_state.mission_outcome.status == "in_progress" and safety < 30:
			safety += 1
			if not session.dashboard_state.pending_events.is_empty():
				var pending: Dictionary = session.dashboard_state.pending_events[0]
				var choice_id := str(pending.choices[0].choice_id)
				var before: Dictionary = session.dashboard_state.snapshot()
				hud.open_pending_event()
				check(hud.event_dialog.visible, "Pending event opens a live modal.")
				check(outpost.get_node("Outpost/Astronaut").ui_blocked, "Modal blocks astronaut input.")
				check(not session.advance_mission(), "Pending choices block sol progression.")
				hud.event_dialog.hide()
				check(session.dashboard_state.snapshot() == before, "Dismissing a decision applies no effects.")
				hud.open_pending_event()
				hud.event_dialog.content.get_child(3).pressed.emit()
				check(not hud.event_dialog.get_ok_button().disabled, "Selecting an authored choice enables confirmation.")
				hud.event_dialog.confirmed.emit()
				hud.event_dialog.hide()
				simulator.resolve_event_choice(reference, str(pending.event_id), choice_id)
				resolved += 1
				check(not session.resolve_decision(str(pending.event_id), choice_id).get("ok", false), "A decision cannot be applied twice.")
			else:
				check(session.advance_mission(), "World can advance a ready mission.")
				check(not session.advance_mission(), "Duplicate actions in the same frame are blocked.")
				simulator.advance_sol(reference)
				await process_frame
			check(session.dashboard_state.snapshot() == reference.snapshot(), "World mission equals an independent simulator after every action.")
			check(outpost.feedback.solar_kwh == reference.power_generated_kwh, "Solar feedback uses authoritative generation.")
			check(outpost.feedback.water == reference.life_support_status.water, "Station warnings use authoritative statuses.")
			check(session.dashboard_state.history[-1].power_kwh == session.dashboard_state.power_kwh, "The current sol history includes resolved choice effects.")
			var before_render: Dictionary = session.dashboard_state.snapshot()
			outpost.refresh_feedback()
			check(session.dashboard_state.snapshot() == before_render, "World rendering never changes mission state.")
			check(hud.values.Water.text.contains("%.2f" % reference.water_l), "HUD shows the exact water reserve.")
		check(safety < 30, "Mission terminates within its bounded sol count.")
		check(not session.advance_mission(), "Terminal missions refuse more sols.")
		check(hud.report_button.text == "View mission report", "Terminal outcome provides report navigation.")
		print("Site %s: %s on sol %d" % [site.site_id, session.dashboard_state.mission_outcome.status, session.dashboard_state.sol])
		var saved: Variant = session.dashboard_state
		outpost.queue_free()
		await process_frame
		var dashboard := preload("res://scenes/mission_dashboard.tscn").instantiate()
		root.add_child(dashboard)
		await process_frame
		check(dashboard.screen == "report" and dashboard.state == saved, "Report consumes the same completed world mission.")
		dashboard.reset_mission()
		check(session.dashboard_state == null, "Restart clears the completed mission.")
		dashboard.queue_free()
		await process_frame
		completed += 1
	# Exercise active-effect pacing and reduced-motion feedback without inventing outcomes.
	session.select_landing_site("ridge_a")
	check(session.start_selected_mission() == OK, "Restart can initialize a new mission.")
	session.dashboard_state.active_events.append({"event_id": "test_timed", "remaining_sols": 2, "effects": {}})
	check(session.can_advance(), "Already-resolved timed effects do not pause turns.")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	session.reduce_motion = true
	world.refresh_feedback()
	world.toggle_overview()
	check(is_equal_approx(world.get_node("Outpost/Astronaut/CameraPivot/SpringArm").spring_length, 12.0), "Reduced-motion camera changes without tweening.")
	world.queue_free()
	await process_frame
	print("Day 14 integration: %d failures; %d real-site missions; %d authored choices resolved." % [failures, completed, resolved])
	quit(1 if failures > 0 else 0)
