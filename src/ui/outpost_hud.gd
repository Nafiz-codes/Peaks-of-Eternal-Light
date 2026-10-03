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

func _ready() -> void:
	name = "MissionHUD"
	world = get_parent()
	session = get_node("/root/MissionSession")
	help_hint = UI.label("ESC: use HUD / pause walking\nClick terrain: resume exploration", 15, UI.TEXT)
	help_hint.position = Vector2(18, 14)
	help_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	help_hint.add_theme_constant_override("outline_size", 6)
	add_child(help_hint)
	panel = PanelContainer.new()
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
	event_button = UI.button("Review decision", open_pending_event)
	actions.add_child(event_button)
	report_button = UI.button("Dashboard / report", open_dashboard)
	actions.add_child(report_button)
	actions.add_child(UI.button("Overview camera", func(): world.toggle_overview()))
	var reduced := CheckButton.new()
	reduced.text = "Reduce motion"
	reduced.button_pressed = session.reduce_motion
	reduced.toggled.connect(func(enabled: bool):
		session.reduce_motion = enabled
		world.refresh_feedback())
	actions.add_child(reduced)
	for action in actions.get_children():
		action.custom_minimum_size.x = 175
	notice = UI.label("", 14, UI.BLUE)
	content.add_child(notice)
	content.add_child(UI.label("Esc: cursor / pause walking · Click terrain: resume · WASD: move · Mouse: look · Space: jump · E: station · I: dashboard", 13, UI.MUTED))
	content.add_child(UI.label("Illustrative terrain and lighting · NASA coarse terrain samples inform the simulation; solar availability is modeled. Construction and rover operations are not yet available.", 13, UI.MUTED))
	var copy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/mission_copy.json"))
	if copy is Dictionary:
		var brief: Dictionary = copy.get("mission_briefing", {})
		UI.disclosure(content, "Mission briefing and science", str(brief.get("opening", "")) + "\n\n" + str(brief.get("science_notice", "")))
	event_dialog = EVENT_SCENE.instantiate()
	add_child(event_dialog)
	event_dialog.decision_confirmed.connect(_resolve_decision)
	event_dialog.visibility_changed.connect(_dialog_visibility_changed)
	session.state_changed.connect(refresh)
	get_viewport().size_changed.connect(_resize)
	_resize()
	refresh()

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	help_hint.size.x = maxf(240, viewport_size.x - 36)
	panel.position = Vector2(12, maxf(12, viewport_size.y - minf(285, viewport_size.y * 0.48) - 12))
	panel.size = Vector2(maxf(240, viewport_size.x - 24), minf(285, viewport_size.y * 0.48))
	readings.columns = 3 if viewport_size.x >= 850 else (2 if viewport_size.x >= 500 else 1)

func refresh() -> void:
	var state: Variant = session.dashboard_state
	heading.text = str(world.site_record.get("name", "Lunar outpost"))
	if state == null:
		status.text = "READY / Start a 10-sol mission at this site."
		for key in values:
			values[key].text = key + " / Awaiting mission"
		run_button.text = "Start mission"
		run_button.disabled = false
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
	run_button.disabled = not session.can_advance() or event_dialog.visible
	event_button.disabled = terminal or state.pending_events.is_empty() or event_dialog.visible
	report_button.text = "View mission report" if terminal else "Mission dashboard"
	if displayed_sol != state.sol:
		displayed_sol = state.sol
		if not session.reduce_motion:
			readings.modulate = Color(0.65, 0.8, 1.0)
			create_tween().tween_property(readings, "modulate", Color.WHITE, 0.5)

func advance_turn() -> void:
	if event_dialog.visible:
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
	if state == null or state.pending_events.is_empty() or state.mission_outcome.status != "in_progress" or event_dialog.visible:
		return
	event_dialog.open_preview(state.pending_events[0], event_button, true)

func _resolve_decision(event_id: String, choice_id: String) -> void:
	var result: Dictionary = session.resolve_decision(event_id, choice_id)
	notice.text = "Decision recorded. Updated readings are authoritative." if result.get("ok", false) else "Decision was not applied: " + str(result.get("error", "unknown"))
	refresh()

func _dialog_visibility_changed() -> void:
	world.get_node("Outpost/Astronaut").ui_blocked = event_dialog.visible
	if event_dialog.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()

func inspect_station(id: String) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var state: Variant = session.dashboard_state
	if state == null:
		notice.text = "Start the mission to inspect live station readings."
		return
	match id:
		"power_console": notice.text = "Solar generation %.2f kWh / consumption %.2f kWh / balance %+.2f kWh last sol." % [state.power_generated_kwh, state.power_consumed_kwh, state.power_balance_kwh]
		"water_recycler": notice.text = "Water %.2f L / recovered %.2f L last sol / %s." % [state.water_l, state.water_recovered_l, state.life_support_status.get("water", "unavailable")]
		"food_storage": notice.text = "Food %.2f kg / consumed %.2f kg last sol / %s." % [state.food_kg, state.food_consumed_kg, state.life_support_status.get("food", "unavailable")]
		"crew_briefing":
			notice.text = "Crew %d / modeled accumulated dose %.3f mSv. Rover and construction controls await their action systems." % [state.crew_size, state.radiation_msv]
			open_pending_event()

func open_dashboard() -> void:
	if not event_dialog.visible:
		session.open_dashboard(world.scene_file_path)
