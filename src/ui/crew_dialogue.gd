extends AcceptDialog
const UI = preload("res://src/ui/ui_style.gd")
const Report = preload("res://src/ui/crew_report.gd")
signal action_requested(kind: String, event_id: String)
signal report_read
var specialist_id := ""
var site_id := ""
var session: Node
var content: VBoxContainer
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	title = "Crew radio"
	exclusive = true
	min_size = Vector2i(320, 300)
	get_ok_button().text = "End conversation · Esc"
	get_ok_button().custom_minimum_size.y = 44
	session = get_node("/root/MissionSession")
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 20
	scroll.offset_right = -24
	scroll.offset_bottom = -70
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	content = UI.box()
	scroll.add_child(content)
	session.state_changed.connect(func():
		if visible:
			if site_id != session.selected_site_id:
				hide()
			else:
				refresh_report())
	visibility_changed.connect(func():
		if not visible:
			Input.set_mouse_mode(previous_mouse_mode))
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			set_input_as_handled()
			hide())

func open_conversation(id: String) -> void:
	if not Report.ROLES.has(id):
		return
	specialist_id = id
	site_id = session.selected_site_id
	previous_mouse_mode = Input.mouse_mode
	refresh_report()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	popup_centered_clamped(Vector2i(760, 580), 0.9)
	get_ok_button().grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide()

func refresh_report() -> void:
	var events: Array = [] if session.dashboard_simulator == null else session.dashboard_simulator.events
	var report := Report.build(specialist_id, session.dashboard_state, events)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	title = report.role + " · Crew radio"
	add_theme_stylebox_override("panel", UI.style(Color("101a29"), report.color))
	content.add_child(UI.label(report.role.to_upper(), 24, report.color.lightened(0.25)))
	content.add_child(UI.label(report.status, 16, UI.AMBER))
	content.add_child(UI.label(report.task, 17, UI.MUTED))
	content.add_child(UI.label(report.update, 20))
	for effect in report.effects:
		content.add_child(UI.label("Active: " + effect, 16, UI.AMBER))
	for event in report.decisions:
		var event_id: String = event.event_id
		content.add_child(UI.label(event.get("text", "Decision awaiting orders"), 17))
		content.add_child(UI.button("Review decision", func(): _request("decision", event_id), session.action_busy))
	if session.dashboard_state == null:
		content.add_child(UI.button("Start mission", func():
			if session.start_selected_mission() != OK:
				content.add_child(UI.label("Mission data could not be loaded. Try again or open the dashboard.", 16, UI.AMBER))))
	elif not report.terminal and report.decisions.is_empty():
		content.add_child(UI.label("No decisions awaiting you in my area. I'll update you after the next sol or a change in conditions.", 16, UI.MUTED))
	content.add_child(UI.button("View mission report" if report.terminal else "Open mission dashboard", func(): _request("dashboard", "")))
	for button in content.find_children("*", "Button", true, false):
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	session.crew_read_reports[specialist_id] = report.signature
	report_read.emit()

func _request(kind: String, event_id: String) -> void:
	hide()
	action_requested.emit(kind, event_id)
