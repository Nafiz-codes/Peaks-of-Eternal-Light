extends CanvasLayer

const UI = preload("res://src/ui/ui_style.gd")
const EVENT_SCENE = preload("res://scenes/event_preview.tscn")
var session: Node
var world: Node3D
var heading: Label
var status: Label
var readings: GridContainer
var values: Dictionary = {}
var run_button: Button
var event_button: Button
var report_button: Button
var event_dialog: ConfirmationDialog
var panel: PanelContainer
var scroll: ScrollContainer
var busy_dialog := false
var displayed_sol := -1
var notice: Label
var help_hint: Label
var operations: AcceptDialog
var activity: Label
var clear_preview_button: Button
var reading_tween: Tween
var crew_dialogue: AcceptDialog
var orbital_panel: AcceptDialog

func _ready() -> void:
	name = "MissionHUD"
	world = get_parent()
	session = get_node("/root/MissionSession")
	help_hint = UI.label("Alt: show mission / details\nV: first / third person · Esc: pause menu", 15, UI.TEXT)
	help_hint.position = Vector2(18, 14)
	help_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	help_hint.add_theme_constant_override("outline_size", 6)
	add_child(help_hint)
	panel = PanelContainer.new()
	panel.hide()
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.05, 0.09, 0.94), UI.PURPLE))
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := UI.box()
	scroll.add_child(content)
	heading = UI.label("", 20, UI.PURPLE)
	content.add_child(heading)
	status = UI.label("", 15, UI.AMBER)
	content.add_child(status)
	readings = GridContainer.new()
	readings.add_theme_constant_override("h_separation", 12)
	readings.add_theme_constant_override("v_separation", 6)
	content.add_child(readings)
	for key in ["Energy", "Water", "Oxygen", "Food", "Dose", "Materials"]:
		var label := UI.label(key, 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readings.add_child(label)
		values[key] = label
	var actions := HFlowContainer.new()
	content.add_child(actions)
	run_button = UI.button("Start mission", advance_turn)
	actions.add_child(run_button)
	if session.DEV_SOL_SKIP_ENABLED and OS.is_debug_build():
		var skip_count := SpinBox.new()
		skip_count.name = "DeveloperSolCount"
		skip_count.min_value = 1
		skip_count.max_value = 9
		skip_count.value = 1
		skip_count.prefix = "Sols: "
		skip_count.tooltip_text = "Temporary developer calendar jump. Supplies and mission objectives are preserved."
		actions.add_child(skip_count)
		var skip_button := UI.button("DEV: Skip Sols", func():
			if _modal_visible(): return
			if session.developer_skip_sols(int(skip_count.value)):
				notice.text = "DEV: jumped to Sol %d. No supplies consumed or objectives completed. Pending decisions remain." % session.dashboard_state.sol
			else:
				notice.text = "DEV skip unavailable: return rover to outpost and stop control. Mission must be active; final Sol uses Run the sol.")
		skip_button.name = "DeveloperSkipSols"
		actions.add_child(skip_button)
	event_button = UI.button("Review decision", open_pending_event)
	actions.add_child(event_button)
	report_button = UI.button("Dashboard / report", open_dashboard)
	actions.add_child(report_button)
	for entry in [["Construction planning", "build"], ["Rover status", "rover"]]:
		var button := UI.button(entry[0], Callable())
		button.pressed.connect(func(): open_operations(entry[1], button))
		actions.add_child(button)
	clear_preview_button = UI.button("Clear placement preview", func():
		world.construction_view.clear_preview()
		clear_preview_button.hide()
		notice.text = "Placement preview cleared.")
	clear_preview_button.hide()
	actions.add_child(clear_preview_button)
	actions.add_child(UI.button("Overview camera", func(): world.toggle_overview()))
	actions.add_child(UI.button("Orbital motion", func():
		if not _modal_visible():
			orbital_panel.open_orbits(world.get_node("OrbitalMotion"))))
	var reduced := CheckButton.new()
	reduced.text = "Reduce motion"
	reduced.button_pressed = session.reduce_motion
	get_node("/root/GameSettings").settings_changed.connect(func():
		reduced.set_pressed_no_signal(session.reduce_motion))
	reduced.toggled.connect(func(enabled: bool):
		get_node("/root/GameSettings").change("reduce_motion", enabled))
	actions.add_child(reduced)
	for action in actions.get_children():
		action.custom_minimum_size.x = 175
	notice = UI.label("", 14, UI.BLUE)
	content.add_child(notice)
	activity = UI.label("", 14, UI.MUTED)
	content.add_child(activity)
	content.add_child(UI.label("Alt: hide mission / details · Esc: pause menu / back · V: first / third person · WASD: move · Shift + W: sprint · Mouse: look · Space: jump · E: station · I: dashboard", 13, UI.MUTED))
	content.add_child(UI.label("Illustrative terrain and lighting · NASA coarse terrain samples inform the simulation; solar availability is modeled. Construction and rover operations use authoritative mission results.", 13, UI.MUTED))
	var copy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/mission_copy.json"))
	if copy is Dictionary:
		var brief: Dictionary = copy.get("mission_briefing", {})
		UI.disclosure(content, "Mission briefing and science", str(brief.get("opening", "")) + "\n\n" + str(brief.get("science_notice", "")))
	event_dialog = EVENT_SCENE.instantiate()
	add_child(event_dialog)
	event_dialog.decision_confirmed.connect(_resolve_decision)
	event_dialog.visibility_changed.connect(_dialog_visibility_changed)
	operations = preload("res://src/ui/operations_panel.gd").new()
	add_child(operations)
	operations.operation_requested.connect(_run_operation)
	operations.mission_start_requested.connect(func(kind: String):
		if session.start_selected_mission() != OK:
			operations.show_operation_error("mission_data_unavailable")
			return
		operations.open_operations(kind, session.dashboard_state, _construction_contract(), null, true, true))
	operations.visibility_changed.connect(_dialog_visibility_changed)
	crew_dialogue = preload("res://src/ui/crew_dialogue.gd").new()
	add_child(crew_dialogue)
	crew_dialogue.visibility_changed.connect(_dialog_visibility_changed)
	crew_dialogue.report_read.connect(world.refresh_feedback)
	crew_dialogue.action_requested.connect(_crew_action)
	orbital_panel = preload("res://src/ui/orbital_panel.gd").new()
	add_child(orbital_panel)
	orbital_panel.visibility_changed.connect(_dialog_visibility_changed)
	operations.placement_preview_requested.connect(func(id: String):
		var catalog := _construction_contract()
		if world.construction_view.show_preview(id, catalog.get("structures", [])):
			clear_preview_button.show()
			notice.text = "Placement preview only. No resources spent and no structure built.")
	session.state_changed.connect(refresh)
	get_viewport().size_changed.connect(_resize)
	_resize()
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ALT and event.pressed and not event.echo:
		# Keep the decision dialog's cursor and focus until it is dismissed.
		if not _modal_visible():
			panel.visible = not panel.visible
			help_hint.text = ("Alt: hide mission / details" if panel.visible else "Alt: show mission / details") + "\nV: first / third person · Esc: pause menu"
			if panel.visible:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				var focused := get_viewport().gui_get_focus_owner()
				if focused != null and panel.is_ancestor_of(focused):
					focused.release_focus()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	help_hint.size.x = maxf(240, viewport_size.x - 36)
	panel.position = Vector2(12, maxf(12, viewport_size.y - minf(285, viewport_size.y * 0.48) - 12))
	panel.size = Vector2(maxf(240, viewport_size.x - 24), minf(285, viewport_size.y * 0.48))
	readings.columns = 3 if viewport_size.x >= 850 else (2 if viewport_size.x >= 500 else 1)

func refresh() -> void:
	var state: Variant = session.dashboard_state
	var events: Array = [] if session.dashboard_simulator == null else session.dashboard_simulator.events
	activity.text = preload("res://src/ui/mission_activity.gd").describe(state, events)
	if session.reduce_motion and reading_tween != null:
		reading_tween.kill()
		readings.modulate = Color.WHITE
	heading.text = str(world.site_record.get("name", "Lunar outpost"))
	if state == null:
		status.text = "READY / Start a 10-sol mission at this site."
		for key in values:
			values[key].text = key + " / Awaiting mission"
		run_button.text = "Start mission"
		run_button.disabled = _modal_visible()
		event_button.disabled = true
		return
	heading.text += " · SOL %02d / %d" % [state.sol, state.mission_length_sols]
	var terminal: bool = state.mission_outcome.get("status", "") != "in_progress"
	status.text = "MISSION " + str(state.mission_outcome.status).to_upper() if terminal else ("DECISION REQUIRED / Resolve before the next sol" if not state.pending_events.is_empty() else "MISSION ACTIVE / Ready for the next sol")
	if terminal and state.mission_outcome.status == "failure":
		status.text += " / " + str(state.mission_outcome.get("failure_reason", "")).replace("_", " ")
	values.Energy.text = "Energy %.2f kWh · %+.2f last sol" % [state.power_kwh, state.power_balance_kwh]
	values.Water.text = "Water %.2f L · %s" % [state.water_l, state.life_support_status.get("water", "unavailable")]
	values.Oxygen.text = "Oxygen %.2f kg · %s" % [state.oxygen_kg, state.life_support_status.get("oxygen", "unavailable")]
	values.Food.text = "Food %.2f kg · %s" % [state.food_kg, state.life_support_status.get("food", "unavailable")]
	values.Dose.text = "Dose %.3f mSv · modeled" % state.radiation_msv
	values.Materials.text = "Materials %.1f units" % state.materials
	run_button.text = "Run the sol"
	run_button.disabled = not session.can_advance() or _modal_visible()
	event_button.disabled = terminal or state.pending_events.is_empty() or _modal_visible()
	report_button.text = "View mission report" if terminal else "Mission dashboard"
	if displayed_sol != state.sol:
		displayed_sol = state.sol
		if not session.reduce_motion:
			readings.modulate = Color(0.65, 0.8, 1.0)
			if reading_tween != null:
				reading_tween.kill()
			reading_tween = create_tween()
			reading_tween.tween_property(readings, "modulate", Color.WHITE, 0.5)

func advance_turn() -> void:
	if _modal_visible():
		return
	if session.dashboard_state == null:
		var error: int = session.start_selected_mission()
		if error != OK:
			notice.text = "Mission data unavailable. Retry or open the dashboard to inspect the data."
		return
	if session.advance_mission():
		notice.text = "Sol recorded. Readings and world indicators updated."
		if not session.dashboard_state.pending_events.is_empty() and session.dashboard_state.mission_outcome.status == "in_progress":
			open_pending_event()

func open_pending_event() -> void:
	var state: Variant = session.dashboard_state
	if state == null or state.pending_events.is_empty() or state.mission_outcome.status != "in_progress" or _modal_visible():
		return
	event_dialog.open_preview(state.pending_events[0], event_button, true)

func _resolve_decision(event_id: String, choice_id: String) -> void:
	var result: Dictionary = session.resolve_decision(event_id, choice_id)
	notice.text = "Decision recorded. Updated readings are authoritative." if result.get("ok", false) else "Decision was not applied: " + str(result.get("error", "unknown"))
	refresh()

func _dialog_visibility_changed() -> void:
	world.get_node("Outpost/Astronaut").ui_blocked = _modal_visible()
	if _modal_visible():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()

func inspect_station(id: String) -> void:
	if not _modal_visible():
		crew_dialogue.open_conversation(id)

func _crew_action(kind: String, event_id: String) -> void:
	if kind == "dashboard":
		open_dashboard()
	elif kind == "decision":
		var state: Variant = session.dashboard_state
		if state == null or state.mission_outcome.get("status") != "in_progress" or session.action_busy:
			return
		for event in state.pending_events:
			if event.event_id == event_id:
				event_dialog.open_preview(event, event_button, true)
				return

func open_dashboard() -> void:
	if not _modal_visible():
		session.open_dashboard(world.scene_file_path)

func _modal_visible() -> bool:
	if is_instance_valid(orbital_panel) and orbital_panel.visible:
		return true
	return (is_instance_valid(event_dialog) and event_dialog.visible) or (is_instance_valid(operations) and operations.visible) or (is_instance_valid(crew_dialogue) and crew_dialogue.visible)

func _construction_contract() -> Dictionary:
	if session.dashboard_simulator != null:
		return session.dashboard_simulator.construction
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/construction.json"))
	return parsed if parsed is Dictionary else {}

func open_operations(kind: String, invoker: Control = null) -> void:
	if not _modal_visible():
		operations.open_operations(kind, session.dashboard_state, _construction_contract(), invoker, true, kind != "rover")


func _run_operation(kind: String, operation_id: String, distance_km: float) -> void:
	if kind == "rover":
		operations.show_operation_error("lander_control_required")
		return
	var result: Dictionary = session.queue_structure(operation_id) if kind == "build" else session.send_rover(operation_id, distance_km)
	notice.text = ("Operation recorded: " + operation_id.replace("_", " ")) if result.get("ok", false) else ("Operation unavailable: " + str(result.get("error", "unknown")))
	if result.get("ok", false):
		operations.hide()
		world.refresh_feedback()
	else:
		operations.show_operation_error(str(result.get("error", "unknown")))
	refresh()
