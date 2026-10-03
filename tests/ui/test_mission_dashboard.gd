extends SceneTree

const AppScene = preload("res://scenes/mission_dashboard.tscn")
const Simulator = preload("res://src/simulation/mission_simulator.gd")
var failures := 0

class FailedLoader:
	extends RefCounted
	func load_contracts() -> Error:
		return ERR_FILE_CANT_READ

func _init() -> void:
	call_deferred("_verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _verify() -> void:
	root.gui_embed_subwindows = true
	var app: Control = AppScene.instantiate()
	root.add_child(app)
	await process_frame
	check(app.screen == "sites", "Project should open at site selection")
	check(app.start_button.disabled, "Mission start requires an explicit site selection")
	check(app.simulator.sites.size() == 4 and app.simulator.events.size() == 19, "Current teammate contracts must load")
	app.select_site("not_a_site")
	check(app.selected_site_id.is_empty(), "Invalid site IDs must not reach simulator assertions")
	check(app.field_text({}, "slope_deg").contains("Unavailable"), "Missing site values must be labeled")
	check(app.field_text({"slope_deg": {"value": 3, "verified": false}}, "slope_deg").contains("Model estimate"), "Unverified values must remain labeled")
	check(app.field_text({"hydrogen_ppm": {"available": false, "verified": false, "availability_note": "No applicable LEND coverage"}}, "hydrogen_ppm").contains("Not available"), "Unavailable hydrogen coverage must remain labeled")
	var damaged: Dictionary = app.simulator.sites[0].duplicate(true)
	damaged.erase("slope_deg")
	check(not app._valid_site(damaged), "A mission cannot start with missing required site data")
	var original: Dictionary = app.simulator.sites[0]
	app.simulator.sites[0] = damaged
	app.select_site(str(damaged.site_id))
	check(app.start_button.disabled, "Missing required fields disable the visible start button")
	app.simulator.sites[0] = original

	var baseline := Simulator.new()
	check(baseline.load_contracts() == OK, "Reference simulator must load")
	for site in baseline.sites:
		app.reset_mission()
		app.select_site(site.site_id)
		check(not app.start_button.disabled, "Each current site should be selectable")
		app.start_button.pressed.emit()
		var reference: Variant = baseline.begin_mission(site.site_id, 10)
		check(app.state.site_id == site.site_id and app.state.sol == 0, "Site selection should reach mission initialization")
		var initial: Dictionary = app.state.snapshot()
		app.start_mission()
		check(app.state.snapshot() == initial, "Duplicate starts must not recreate state")
		while reference.mission_outcome.status == "in_progress" and reference.sol < 10:
			app.run_button.pressed.emit()
			var once: int = app.state.sol
			app.advance_turn()
			check(app.state.sol == once, "Repeated callbacks while a turn is updating must not tick twice")
			baseline.advance_sol(reference)
			while not reference.pending_events.is_empty():
				var pending: Dictionary = reference.pending_events[0]
				var choices: Array = pending.get("choices", [])
				var choice_id := ""
				if not choices.is_empty():
					choice_id = str(choices[0].get("choice_id", ""))
				baseline.resolve_event_choice(reference, str(pending.get("event_id", "")), choice_id)
				app._resolve_event(str(pending.get("event_id", "")), choice_id)
			check(app.state.snapshot() == reference.snapshot(), "UI must preserve authoritative state for " + str(site.site_id))
			var expected := [reference.power_kwh, reference.water_l, reference.oxygen_kg, reference.food_kg, reference.radiation_msv, reference.materials]
			for index in range(expected.size()):
				var displayed: Array[Node] = app.readings.get_child(index).find_children("*", "Label", true, false)
				check(displayed[1].text == "%.2f" % float(expected[index]), "Visible resource reading must update from the returned state")
			await process_frame
		check(app.screen == "report", "Terminal outcomes should open the report")
		var final_sol: int = app.state.sol
		app.advance_turn()
		check(app.state.sol == final_sol, "No turns after success or early failure")
		check(app.state.history.size() == reference.history.size(), "Report history must retain simulator snapshots")
		check(app.state.mission_outcome.status == "failure", "Respect current baseline outcomes")
		app._request_restart()
		check(app.restart_dialog.visible and app.state != null, "Restart needs confirmation before discarding a report")
		app.restart_dialog.hide()

	app.reset_mission()
	check(app.state == null and app.selected_site_id.is_empty(), "New mission must discard the prior run")
	app.select_site("ridge_a")
	app.start_mission()
	var before_preview: Dictionary = app.state.snapshot()
	var choice_event: Dictionary = {}
	var notice: Dictionary = {}
	for event in app.simulator.events:
		if event.event_id == "solar_particle_event":
			choice_event = event
		if event.event_id == "greenhouse_bloom":
			notice = event
	app.event_dialog.open_preview(choice_event, app.run_button)
	await process_frame
	check(app.event_dialog.get_ok_button().disabled, "Choice preview needs explicit selection")
	var option: Button = app.event_dialog.content.get_child(3)
	option.pressed.emit()
	check(not app.event_dialog.get_ok_button().disabled, "Selecting a choice enables preview confirmation")
	check(app.event_dialog.selection_label.text.begins_with("Selected:"), "Selection must be expressed in text")
	for index in range(8):
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		app.event_dialog.push_input(tab)
		await process_frame
		var focused: Control = app.event_dialog.gui_get_focus_owner()
		check(focused != null and app.event_dialog.is_ancestor_of(focused), "Tab must keep focus inside the modal")
	app.advance_turn()
	check(app.state.sol == 0, "An open modal must block turns")
	app.event_dialog._finish_preview()
	app.event_dialog.hide()
	check(root.gui_get_focus_owner() == app.run_button, "Closing a preview should restore its invoking control")
	check(app.state.snapshot() == before_preview, "Preview choices must never apply event effects")
	app.event_dialog.open_preview(notice, app.run_button)
	check(not app.event_dialog.get_ok_button().disabled, "No-choice notification permits acknowledgement")
	app.event_dialog.hide()
	app.state.pending_events.append({"event_id": "future_required_event", "text": "Resolve this decision.", "choices": [{"choice_id": "continue", "text": "Continue", "effects": {}}]})
	app.show_dashboard()
	check(app.run_button.disabled, "Pending event decisions must pause turns until resolved")
	app.state.pending_events.clear()
	app.show_load_error("Test load failure")
	check(app.screen == "error" and app.state == null and app.start_button == null, "Load failures must block mission start")
	app.show_sites()
	check(app.screen == "sites", "Retry should recover to site selection")
	app.show_report()
	check(app.screen == "report" and app.state == null, "Report shell supports no attached mission")
	print("Member 3 UI integration: %d failures; four site flows, terminal guards, previews, missing values and load recovery checked." % failures)
	quit(1 if failures else 0)
