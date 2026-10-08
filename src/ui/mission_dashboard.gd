extends Control

## Member 3 presentation controller. Simulation and content contracts stay owned
## by Members 1 and 2. No resource, event-effect, or outcome calculations live here.
const UI = preload("res://src/ui/ui_style.gd")
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const OutpostPreview = preload("res://src/ui/outpost_preview.gd")
const EventScene = preload("res://scenes/event_preview.tscn")
const MISSION_LENGTH := 10
const SITE_FIELDS := {"illumination_pct": ["Illumination", "%"], "elevation_m": ["Elevation", "m"], "slope_deg": ["Slope", "degrees"], "hydrogen_ppm": ["Hydrogen potential", "ppmw H"]}
const REQUIRED_SITE_FIELDS := ["illumination_pct", "elevation_m", "slope_deg"]

var simulator: RefCounted
var state: Variant = null
var selected_site_id := ""
var screen := "loading"
var load_error := ""
var copy: Dictionary = {}
var last_tick: Dictionary = {}
var page: ScrollContainer
var column: VBoxContainer
var readings: GridContainer
var sites_grid: GridContainer
var dashboard_grid: GridContainer
var run_button: Button
var start_button: Button
var event_dialog: ConfirmationDialog
var restart_dialog: ConfirmationDialog
var busy := false
var operations: AcceptDialog

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process_unhandled_input(true)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b0d16")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	event_dialog = EventScene.instantiate()
	add_child(event_dialog)
	event_dialog.decision_confirmed.connect(_resolve_event)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "Start a new mission?"
	restart_dialog.dialog_text = "Return to site selection? The current report will be cleared."
	restart_dialog.exclusive = true
	restart_dialog.confirmed.connect(reset_mission)
	add_child(restart_dialog)
	operations = preload("res://src/ui/operations_panel.gd").new()
	add_child(operations)
	operations.visibility_changed.connect(func():
		if is_instance_valid(run_button):
			run_button.disabled = not _can_advance())
	get_viewport().size_changed.connect(_resize)
	reload_contracts()

func reload_contracts(loader: RefCounted = null) -> void:
	state = null
	last_tick = {}
	selected_site_id = ""
	var session := get_node_or_null("/root/MissionSession")
	var saved_simulator: Variant = null if session == null else session.get("dashboard_simulator")
	simulator = saved_simulator if saved_simulator is RefCounted else (Simulator.new() if loader == null else loader)
	if simulator.load_contracts() != OK:
		show_load_error("Mission data could not be loaded. Check the Resources files and retry.")
		return
	var ids: Array[String] = []
	for site in simulator.sites:
		var id := str(site.get("site_id", ""))
		if id.is_empty() or ids.has(id):
			show_load_error("Site data contains a missing or duplicate ID. Correct the data and retry.")
			return
		ids.append(id)
	if session != null:
		state = session.get("dashboard_state")
		var saved_last_tick: Variant = session.get("dashboard_last_tick")
		if saved_last_tick is Dictionary:
			last_tick = saved_last_tick.duplicate(true)
		if state != null:
			selected_site_id = str(state.site_id)
		else:
			var active_site := str(session.get("selected_site_id"))
			if ids.has(active_site):
				selected_site_id = active_site
	copy = {}
	if FileAccess.file_exists("res://Resources/mission_copy.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/mission_copy.json"))
		if parsed is Dictionary:
			copy = parsed
	load_error = ""
	if state == null:
		show_sites()
	elif state.mission_outcome.get("status", "") in ["success", "failure"]:
		show_report()
	else:
		show_dashboard()

func show_load_error(message: String) -> void:
	load_error = message
	state = null
	_new_page("error", "Mission data unavailable")
	column.add_child(UI.label(message, 18, UI.AMBER))
	column.add_child(UI.button("Retry loading", reload_contracts))

func _new_page(name_: String, heading: String) -> void:
	screen = name_
	readings = null
	sites_grid = null
	dashboard_grid = null
	run_button = null
	start_button = null
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	page.add_child(margin)
	column = UI.box()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	column.add_child(UI.label("△ △ △  /  by TRIARCHY", 14, UI.PURPLE))
	column.add_child(UI.label("Peaks of Eternal Light", 34))
	column.add_child(UI.label(heading, 22, UI.BLUE))
	if _has_return_destination():
		column.add_child(UI.button("Return to lunar scene  [I]", _return_to_game))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I and _has_return_destination():
		_return_to_game()
		get_viewport().set_input_as_handled()


func _has_return_destination() -> bool:
	var session := get_node_or_null("/root/MissionSession")
	return session != null and not str(session.get("return_scene_path")).is_empty()


func _return_to_game() -> void:
	if event_dialog.visible or restart_dialog.visible or operations.visible:
		return
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.call("return_to_game")

func _brief(key: String, fallback: String) -> String:
	var briefing: Variant = copy.get("mission_briefing", {})
	if not briefing is Dictionary:
		return fallback
	return str(briefing.get(key, fallback)).replace("[MISSION_LENGTH]", str(MISSION_LENGTH if state == null else state.mission_length_sols))

func show_sites() -> void:
	_new_page("sites", "Choose your landing site")
	column.add_child(UI.label(_brief("opening", "Establish a lunar outpost and sustain your crew.")))
	column.add_child(UI.label(_brief("primary_objective", "Sustain the crew through Sol 10."), 16, UI.PURPLE))
	column.add_child(UI.label(_brief("science_notice", "Hydrogen indicates resource potential, not guaranteed water."), 14, UI.MUTED))
	sites_grid = GridContainer.new()
	sites_grid.add_theme_constant_override("h_separation", 12)
	sites_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(sites_grid)
	for site in simulator.sites:
		var id := str(site.site_id)
		var card := UI.panel(sites_grid)
		var prefix := "SELECTED / " if selected_site_id == id else "SELECT / "
		var choose := UI.button(prefix + str(site.get("name", id)), select_site.bind(id))
		choose.name = "Select_" + id
		card.add_child(choose)
		card.add_child(UI.label(field_text(site, "illumination_pct"), 15, UI.BLUE))
		card.add_child(UI.label(str(site.get("description", "Description unavailable")), 14, UI.MUTED))
	var details := UI.panel(column)
	var selected := _site(selected_site_id)
	if selected.is_empty():
		details.add_child(UI.label("Select a site above to inspect its measurements and sources."))
	else:
		details.add_child(UI.label(str(selected.get("name", selected_site_id)) + " / Site conditions", 20))
		for field in SITE_FIELDS:
			details.add_child(UI.label(field_text(selected, field)))
		var coordinates: Variant = selected.get("coordinates", {})
		if coordinates is Dictionary and coordinates.has("latitude_deg") and coordinates.has("longitude_deg"):
			details.add_child(UI.label("Coordinates: %s°, %s° east" % [coordinates.latitude_deg, coordinates.longitude_deg], 14, UI.MUTED))
		UI.disclosure(details, "Measurement sources and reading dates", _site_sources(selected))
		details.add_child(UI.label("Solar availability is an ideal-horizon lunar-day estimate. NASA hydrogen coverage does not include these landing coordinates.", 14, UI.AMBER))
		if not _valid_site(selected):
			details.add_child(UI.label("Required numeric site data is missing. This site cannot start a mission.", 14, UI.AMBER))
	column.add_child(UI.label("Development build: construction and rover actions are not available yet. Events use the current simulator effect support. The modeled solar average is not a site-specific lighting forecast.", 14, UI.AMBER))
	start_button = UI.button("Establish outpost", start_mission, not _valid_site(selected))
	column.add_child(start_button)
	_add_previews()
	_resize()

func select_site(id: String) -> void:
	if _site(id).is_empty():
		return
	selected_site_id = id
	show_sites()
	var selected: Node = column.find_child("Select_" + id, true, false)
	if selected is Button:
		selected.grab_focus()

func _site(id: String) -> Dictionary:
	for site in simulator.sites:
		if site.get("site_id", "") == id:
			return site
	return {}

func _valid_site(site: Dictionary) -> bool:
	if site.is_empty():
		return false
	for field in REQUIRED_SITE_FIELDS:
		var data: Variant = site.get(field)
		if not data is Dictionary:
			return false
		var value: Variant = data.get("value")
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return true

func field_text(site: Dictionary, field: String) -> String:
	var descriptor: Array = SITE_FIELDS[field]
	var data: Variant = site.get(field)
	if not data is Dictionary:
		return str(descriptor[0]) + ": Unavailable"
	if data.get("available", true) == false:
		return "%s: Not available · %s" % [descriptor[0], str(data.get("availability_note", "No applicable source coverage"))]
	if not (data.get("value") is float or data.get("value") is int):
		return str(descriptor[0]) + ": Unavailable"
	var verification := "NASA source" if data.get("verified", false) == true else str(data.get("status_label", "Model estimate"))
	return "%s: %.2f %s · %s" % [descriptor[0], float(data.value), descriptor[1], verification]

func _site_sources(site: Dictionary) -> String:
	var lines := PackedStringArray()
	for field in SITE_FIELDS:
		var data: Variant = site.get(field, {})
		if data is Dictionary:
			lines.append("%s\n%s\nRead: %s" % [SITE_FIELDS[field][0], data.get("source", "Source unavailable"), data.get("date_read", "Unavailable")])
	return "\n\n".join(lines)

func start_mission() -> void:
	if not load_error.is_empty() or not _valid_site(_site(selected_site_id)) or state != null:
		return
	state = simulator.begin_mission(selected_site_id, MISSION_LENGTH)
	last_tick = {}
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.call("select_landing_site", selected_site_id)
		session.set("dashboard_simulator", simulator)
		session.set("dashboard_state", state)
		session.set("dashboard_last_tick", last_tick)
	show_dashboard()

func show_dashboard() -> void:
	if state == null:
		return
	_new_page("dashboard", "%s / SOL %02d / %d" % [_site(state.site_id).get("name", state.site_id), state.sol, state.mission_length_sols])
	column.add_child(UI.label(str(state.mission_outcome.get("primary_objective", "Mission objective unavailable")), 16, UI.PURPLE))
	_add_readings(column)
	run_button = UI.button("Run the sol", advance_turn, not _can_advance())
	column.add_child(run_button)
	dashboard_grid = GridContainer.new()
	dashboard_grid.add_theme_constant_override("h_separation", 16)
	dashboard_grid.add_theme_constant_override("v_separation", 16)
	column.add_child(dashboard_grid)
	var left := UI.box()
	var right := UI.box()
	dashboard_grid.add_child(left)
	dashboard_grid.add_child(right)
	var terrain := UI.panel(left)
	terrain.add_child(UI.label("OUTPOST / SCHEMATIC", 16))
	terrain.add_child(OutpostPreview.new())
	terrain.add_child(UI.label("Habitat · Solar array · Rover / Placement is illustrative", 14, UI.MUTED))
	for entry in [["Construction planning", "build"], ["Rover operations", "rover"]]:
		var button := UI.button(entry[0], Callable())
		button.pressed.connect(func(): operations.open_operations(entry[1], state, simulator.construction, button))
		left.add_child(button)
	var crew := UI.panel(right)
	crew.add_child(UI.label("CREW / %d" % state.crew_size, 18))
	for member in simulator.crew:
		var name_: String = str(member.get("name", ""))
		var role := str(member.get("role", "Role unavailable"))
		crew.add_child(UI.label(role if name_.is_empty() or name_ == "TBD" else name_ + " / " + role, 15))
	crew.add_child(UI.label("Live crew health and modifiers are not available yet.", 14, UI.MUTED))
	var activity := UI.panel(right)
	activity.add_child(UI.label("MISSION ACTIVITY", 18))
	activity.add_child(UI.label("No pending decisions." if state.pending_events.is_empty() else "%d event decision(s) need attention." % state.pending_events.size(), 15, UI.AMBER))
	for pending in state.pending_events:
		activity.add_child(UI.label(str(pending.get("text", "Event decision")), 15))
		var review := UI.button("Review mission decision", Callable())
		review.pressed.connect(func(): event_dialog.open_preview(pending, review, true))
		activity.add_child(review)
	if state.sol > 0:
		activity.add_child(UI.label("Last sol: energy generated %.2f kWh / consumed %.2f kWh / balance %+.2f kWh" % [state.power_generated_kwh, state.power_consumed_kwh, state.power_balance_kwh], 15))
		activity.add_child(UI.label("Water consumed %.2f L / recovered %.2f L · Radiation +%.3f mSv" % [state.water_consumed_l, state.water_recovered_l, state.radiation_this_sol_msv], 15))
	if state.consecutive_power_depleted_sols > 0:
		activity.add_child(UI.label("! Battery depleted for %d consecutive sol(s)." % state.consecutive_power_depleted_sols, 16, UI.AMBER))
	UI.disclosure(activity, "Active effects and decision record", preload("res://src/ui/mission_activity.gd").describe(state, simulator.events))
	UI.disclosure(column, "Model assumptions and source status", _model_notes())
	UI.disclosure(column, "Selected site provenance", _site_sources(_site(state.site_id)))
	_add_previews()
	_resize()
	run_button.grab_focus()

func _add_readings(parent: Node) -> void:
	readings = GridContainer.new()
	readings.add_theme_constant_override("h_separation", 10)
	readings.add_theme_constant_override("v_separation", 10)
	parent.add_child(readings)
	var values := [["Energy reserve", state.power_kwh, "kWh", ""], ["Water", state.water_l, "L", state.life_support_status.get("water", "Unavailable")], ["Oxygen", state.oxygen_kg, "kg", state.life_support_status.get("oxygen", "Unavailable")], ["Food", state.food_kg, "kg", state.life_support_status.get("food", "Unavailable")], ["Accumulated dose", state.radiation_msv, "mSv", ""], ["Materials", state.materials, "game units", ""]]
	for entry in values:
		var card := UI.panel(readings)
		card.add_child(UI.label(str(entry[0]), 14, UI.MUTED))
		card.add_child(UI.label("%.2f" % float(entry[1]), 26, UI.BLUE))
		card.add_child(UI.label(str(entry[2]), 14, UI.MUTED))
		if not str(entry[3]).is_empty():
			card.add_child(UI.label(str(entry[3]).to_upper(), 14, UI.BLUE if entry[3] == "nominal" else UI.AMBER))

func _can_advance() -> bool:
	return state != null and not busy and state.sol < state.mission_length_sols and state.mission_outcome.get("status", "") == "in_progress" and state.pending_events.is_empty() and not event_dialog.visible and not operations.visible and not restart_dialog.visible

func _resolve_event(event_id: String, choice_id: String) -> void:
	if state == null or state.mission_outcome.get("status", "") != "in_progress":
		return
	var result: Dictionary = simulator.resolve_event_choice(state, event_id, choice_id)
	if not result.get("ok", false):
		return
	state = result.state
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.set("dashboard_state", state)
	if state.mission_outcome.get("status", "") in ["success", "failure"]:
		show_report()
	else:
		show_dashboard()

func advance_turn() -> void:
	if not _can_advance():
		return
	busy = true
	if is_instance_valid(run_button):
		run_button.disabled = true
	last_tick = simulator.advance_sol(state)
	state = last_tick.state
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.set("dashboard_state", state)
		session.set("dashboard_last_tick", last_tick)
	if state.mission_outcome.get("status", "") in ["success", "failure"]:
		show_report()
	else:
		show_dashboard()
	_finish_turn.call_deferred()

func _finish_turn() -> void:
	busy = false
	if is_instance_valid(run_button):
		run_button.disabled = not _can_advance()
		if not run_button.disabled:
			run_button.grab_focus()

func show_report() -> void:
	_new_page("report", "Mission report" if state != null else "Report layout preview")
	var report := UI.panel(column)
	if state == null:
		report.add_child(UI.label("OUTCOME UNAVAILABLE / No mission attached", 22, UI.AMBER))
		report.add_child(UI.label("Final reserves, cause, and resource history appear after a mission."))
	else:
		var outcome: Dictionary = state.mission_outcome
		report.add_child(UI.label(str(outcome.get("status", "unavailable")).to_upper(), 26, UI.PURPLE))
		report.add_child(UI.label("%s / Sol %d of %d" % [_site(state.site_id).get("name", state.site_id), state.sol, state.mission_length_sols]))
		if outcome.get("status", "") == "failure":
			report.add_child(UI.label("Cause: %s / first recorded on Sol %d" % [str(outcome.get("failure_reason", "Unavailable")).replace("_", " "), outcome.get("failure_sol", 0)], 18, UI.AMBER))
		report.add_child(UI.label(_report_guidance(outcome), 15, UI.MUTED))
		var metrics: Dictionary = state.report_data
		report.add_child(UI.label("Mission duration completed: %.0f%% / %d of %d sols" % [float(metrics.get("survival_pct", 0.0)), int(metrics.get("sols_survived", 0)), int(metrics.get("mission_length_sols", 0))], 16))
		report.add_child(UI.label("Events resolved: %d / Total modeled dose: %.2f mSv / Prospect: %s" % [int(metrics.get("events_resolved", 0)), float(metrics.get("radiation_total_msv", 0.0)), str(metrics.get("volatile_prospect_status", "none"))], 15))
		_add_readings(column)
		var record := UI.panel(column)
		var history := preload("res://src/ui/resource_history.gd").new()
		history.set_history(state.history)
		record.add_child(history)
		UI.disclosure(column, "Decision history", preload("res://src/ui/mission_activity.gd").describe(state, simulator.events))
		var construction := UI.panel(column)
		construction.add_child(UI.label("OUTPOST RECORD", 18))
		construction.add_child(UI.label("Completed structures recorded: %d\nLast rover action: %s" % [state.built_structures.size(), "None" if str(state.last_rover_action).is_empty() else str(state.last_rover_action)], 15))
		UI.disclosure(column, "Source measurements and model assumptions", _site_sources(_site(state.site_id)) + "\n\n" + _model_notes())
	column.add_child(UI.label("Construction and independence metrics require build and rover actions.", 14, UI.MUTED))
	var restart := UI.button("Choose a new mission" if state != null else "Back to site selection", _request_restart)
	column.add_child(restart)
	_resize()
	restart.grab_focus()

func _report_guidance(outcome: Dictionary) -> String:
	var report_copy: Dictionary = copy.get("mission_report_copy", {})
	if str(outcome.get("status", "")) == "success":
		return str(report_copy.get("success", "Primary objective complete. Review the mission record before planning the next deployment."))
	var failure_copy: Dictionary = report_copy.get("failure", {})
	return str(failure_copy.get(str(outcome.get("failure_reason", "")), failure_copy.get("default", "The mission ended before the primary objective was met.")))

func _request_restart() -> void:
	if state == null:
		reset_mission()
	else:
		restart_dialog.popup_centered_clamped(Vector2i(460, 180), 0.9)

func reset_mission() -> void:
	state = null
	last_tick = {}
	selected_site_id = ""
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.set("dashboard_state", null)
		session.set("dashboard_last_tick", {})
	show_sites()

func _model_notes() -> String:
	var lines := PackedStringArray(["Radiation: NASA lunar-surface baseline with a bounded terrain gameplay proxy. It is not a geographic CRaTER measurement.", "Water recovery uses an ISS whole-loop proxy, not a lunar-system prediction. Source verification describes provenance, not mission safety."])
	for key in simulator.bvad_constants:
		var field: Variant = simulator.bvad_constants[key]
		if field is Dictionary and field.has("verified"):
			lines.append("%s: %s" % [str(key).replace("_", " "), "verified source / see contract provenance" if field.verified == true else "unverified model choice"])
	if not last_tick.is_empty():
		lines.append("Life support model: " + str(last_tick.get("life_support", {}).get("model_status", "Unavailable")))
	return "\n\n".join(lines)

func _add_previews() -> void:
	var previews := UI.panel(column)
	previews.add_child(UI.label("INTERFACE PREVIEWS / No event effects applied", 14, UI.MUTED))
	for desired in ["solar_particle_event", "greenhouse_bloom"]:
		for event in simulator.events:
			if event.get("event_id", "") == desired:
				var trigger := UI.button("Preview " + ("choice event" if desired == "solar_particle_event" else "notification"), Callable())
				trigger.pressed.connect(func(): event_dialog.open_preview(event, trigger))
				previews.add_child(trigger)
	if state == null:
		previews.add_child(UI.button("Preview report layout", show_report))

func _resize() -> void:
	var width := get_viewport_rect().size.x
	if is_instance_valid(readings):
		readings.columns = 6 if width >= 1220 else (3 if width >= 700 else 2)
	if is_instance_valid(sites_grid):
		sites_grid.columns = 2 if width >= 900 else 1
	if is_instance_valid(dashboard_grid):
		dashboard_grid.columns = 2 if width >= 1000 else 1
