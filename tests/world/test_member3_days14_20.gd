extends SceneTree

var failures := 0
var assertions := 0
var capture := false

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func labels(node: Node) -> String:
	var text := ""
	if node is Label or node is Label3D:
		text += node.text + "\n"
	for child in node.get_children():
		text += labels(child)
	return text

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.tools/day20")
	check(root.get_texture().get_image().save_png("res://.tools/day20/" + filename + ".png") == OK, "Screenshot saved: " + filename)

func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1360, 820)
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	check(session.start_selected_mission() == OK, "Mission initializes from real contracts.")
	var state: Variant = session.dashboard_state
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var hud := world.get_node("MissionHUD")
	hud.panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var baseline: Dictionary = state.snapshot()
	var original_built: Dictionary = state.built_structures.duplicate(true)
	hud.open_operations("build", hud.run_button)
	check(hud.operations.visible and world.get_node("Outpost/Astronaut").ui_blocked, "Planning modal blocks walking.")
	check(hud.run_button.disabled, "Planning blocks advancing the mission.")
	hud.advance_turn()
	check(state.snapshot() == baseline, "Planning cannot advance state.")
	check(labels(hud.operations).contains("35") and labels(hud.operations).contains("Radiation Shielding Wall"), "Catalog displays real costs and all structures.")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	hud._input(alt)
	check(hud.panel.visible, "Alt cannot dismiss the HUD through an operations modal.")
	for button in hud.operations.content.find_children("*", "Button", true, false):
		if button.text == "Build unavailable":
			check(button.disabled, "Unavailable build commands remain disabled.")
	await shot("construction-desktop")
	root.size = Vector2i(520, 900)
	hud.operations.hide()
	hud.open_operations("build", hud.run_button)
	await shot("construction-narrow")
	check(hud.operations.size.x <= 520, "Planning dialog fits narrow viewport.")
	# Use the visible preview button, not a fabricated construction result.
	for button in hud.operations.content.find_children("*", "Button", true, false):
		if button.text == "Preview illustrative placement":
			button.pressed.emit()
			break
	check(not hud.operations.visible, "Preview closes the planning modal.")
	check(is_instance_valid(world.construction_view.preview), "Preview creates a ghost.")
	check(labels(world.construction_view.preview).contains("NOT BUILT"), "Ghost explicitly disclaims completion.")
	check(world.construction_view.preview.find_children("*", "StaticBody3D", true, false).is_empty(), "Ghost does not block walking.")
	check(state.snapshot() == baseline and state.built_structures == original_built, "Preview spends no resources and constructs nothing.")
	root.size = Vector2i(1360, 820)
	session.reduce_motion = true
	world.toggle_overview()
	await shot("placement-preview")
	hud.clear_preview_button.pressed.emit()
	check(world.construction_view.preview == null, "Clear preview removes the ghost.")
	check(not world.construction_view.show_preview("invalid", session.dashboard_simulator.construction.structures), "Unknown structures cannot be previewed.")
	# Existing authoritative field tested with fixtures, not playable construction.
	for entry in session.dashboard_simulator.construction.structures:
		state.built_structures[entry.structure_id] = 0
	world.refresh_feedback()
	check(world.construction_view.completed.size() == 6, "Each confirmed structure has a world representation.")
	check(world.construction_view.completed.shielding_wall.find_children("*", "StaticBody3D", true, false).size() == 1, "Completed shielding has a collision hull.")
	world.refresh_feedback()
	check(world.construction_view.get_child_count() == 6, "Repeated refresh does not duplicate structures.")
	await shot("completed-structures-fixture")
	state.built_structures.clear()
	world.refresh_feedback()
	check(world.construction_view.completed.is_empty(), "Removed/reset structures disappear.")
	hud.open_operations("rover", hud.run_button)
	check(labels(hud.operations).contains("0.55") and labels(hud.operations).contains("remains parked"), "Rover panel uses real parameters and discloses unavailable movement.")
	await shot("rover-panel")
	hud.operations.hide()
	check(not world.get_node("Outpost/Astronaut").ui_blocked, "Closing operations restores exploration input.")
	check(root.gui_get_focus_owner() == hud.run_button, "Closing operations restores invoker focus.")
	var rover := world.get_node("Outpost/Rover")
	var hull := world.get_node("RoverHull")
	var parked: Vector3 = rover.position
	check(rover.position.is_equal_approx(Vector3(5.2, 0, -2.8)), "Normal play leaves rover parked.")
	var route := {"ok": true, "action_id": "fixture_route_1", "presentation_route": [parked, parked + Vector3(1, 0, 0), parked + Vector3(2, 0, 1)]}
	check(not world.rover_view.play_confirmed_route(rover, hull, {"ok": false}, false), "Rejected actions do not animate.")
	check(not world.rover_view.play_confirmed_route(rover, hull, {"ok": true, "action_id": "bad", "presentation_route": [parked, "invalid"]}, false), "Malformed routes do not animate.")
	check(world.rover_view.play_confirmed_route(rover, hull, route, false), "Confirmed route fixture starts animation.")
	await create_timer(0.3).timeout
	check(rover.position.distance_to(parked) > 0.01 and rover.position.distance_to(route.presentation_route[-1]) > 0.01, "Rover interpolates rather than teleporting.")
	check(hull.position.is_equal_approx(rover.position + Vector3(0, 0.65, 0)), "Collision hull follows the rover.")
	check(not world.rover_view.play_confirmed_route(rover, hull, route, false), "Duplicate action does not replay.")
	session.reduce_motion = true
	world.refresh_feedback()
	check(rover.position.is_equal_approx(route.presentation_route[-1]), "Enabling reduced motion finishes active rover motion.")
	route.action_id = "fixture_route_2"
	route.presentation_route = [rover.position, parked]
	check(world.rover_view.play_confirmed_route(rover, hull, route, true) and rover.position.is_equal_approx(parked), "Reduced-motion route immediately displays the confirmed destination.")
	route.action_id = "fixture_route_3"
	route.presentation_route = [parked, parked + Vector3(1, 0, 0), parked + Vector3(2, 0, 1)]
	check(world.rover_view.play_confirmed_route(rover, hull, route, false), "A new confirmed action can animate.")
	await create_timer(1.5).timeout
	check(rover.position.is_equal_approx(route.presentation_route[-1]), "All route segments finish at their confirmed destination.")
	session.reduce_motion = false
	world.toggle_overview()
	await create_timer(0.1).timeout
	session.reduce_motion = true
	world.refresh_feedback()
	check(is_equal_approx(world.get_node("Outpost/Astronaut/CameraPivot/SpringArm").spring_length, 4.8), "Enabling reduced motion finishes the active camera transition.")
	check(state.snapshot() == baseline and state.built_structures == original_built, "World fixtures and animations never mutate mission values.")
	var activity = preload("res://src/ui/mission_activity.gd")
	state.resolved_events.append({"event_id": "notification", "sol": 1})
	check(activity.describe(state, [{"event_id": "notification", "choices": null}]).contains("notification"), "Null-choice notifications render safely.")
	state.resolved_events.clear()
	# Real mission provides the report data, including actual resolved decisions.
	while state.mission_outcome.status == "in_progress":
		if state.pending_events.is_empty():
			session.advance_mission()
			await process_frame
		else:
			var event: Dictionary = state.pending_events[0]
			session.resolve_decision(str(event.event_id), str(event.choices[0].choice_id))
	baseline = state.snapshot()
	world.queue_free()
	await process_frame
	var dashboard := preload("res://scenes/mission_dashboard.tscn").instantiate()
	root.add_child(dashboard)
	current_scene = dashboard
	await process_frame
	check(dashboard.screen == "report", "Real terminal mission opens report.")
	var charts: Array = []
	for node in dashboard.column.find_children("*", "VBoxContainer", true, false):
		if node.get_script() == preload("res://src/ui/resource_history.gd"):
			charts.append(node)
	check(charts.size() == 1, "Report contains the resource history chart.")
	var chart: Node = charts[0]
	for field in chart.FIELDS:
		chart.selected_field = field
		chart._refresh()
		check(chart.table.text.contains("%.3f" % float(state.history[-1][field])), "History shows exact final " + field)
	chart.selected_field = "power_kwh"
	chart._refresh()
	# Scroll to the chart for QA; the outcome remains accessible above it.
	await process_frame
	dashboard.page.scroll_vertical = int(chart.get_global_rect().position.y) - 30
	await shot("report-desktop")
	root.size = Vector2i(520, 900)
	await process_frame
	await process_frame
	dashboard.page.scroll_vertical = int(chart.get_global_rect().position.y) + dashboard.page.scroll_vertical - 30
	await shot("report-narrow")
	check(chart.size.x <= 520, "Report chart fits narrow viewport.")
	check(state.snapshot() == baseline, "Report and resource selection never mutate simulation.")
	chart.set_history([])
	check(not chart.chart.visible and chart.table.text == "No recorded history.", "Empty history has no invented chart.")
	chart.set_history([{"sol": 0, "power_kwh": 0.0}])
	check(chart.table.text.contains("0.000"), "Zero-valued single-sol history is valid.")
	chart.selected_field = "water_l"
	chart._refresh()
	check(chart.table.text.contains("Unavailable"), "Missing history values are disclosed.")
	dashboard.reset_mission()
	dashboard.select_site("ridge_a")
	dashboard.start_mission()
	dashboard.operations.open_operations("build", dashboard.state, dashboard.simulator.construction, dashboard.run_button)
	var sol: int = dashboard.state.sol
	dashboard.advance_turn()
	check(dashboard.state.sol == sol and dashboard.run_button.disabled, "Dashboard operations block background sol commands.")
	dashboard.operations.hide()
	check(not dashboard.run_button.disabled, "Dashboard sol commands recover after closing operations.")
	dashboard.queue_free()
	await process_frame
	print("Member 3 Days 14–20: %d failures / %d assertions. Fixtures do not certify missing gameplay APIs." % [failures, assertions])
	quit(1 if failures else 0)
