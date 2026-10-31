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
var fieldwork: Node
var field_status: Label
var field_summary: Label
var field_phase := ""

func _ready() -> void:
	title = "Crew radio"
	exclusive = true
	min_size = Vector2i(320, 300)
	get_ok_button().text = "End conversation · Esc"
	get_ok_button().custom_minimum_size.y = 44
	session = get_node("/root/MissionSession")
	fieldwork = get_parent().get_parent().get_node_or_null("CrewFieldwork")
	if fieldwork != null:
		fieldwork.changed.connect(func():
			if visible:
				var phase: String = "" if fieldwork.data.is_empty() or not fieldwork.data.crew.has(specialist_id) else str(fieldwork.data.crew[specialist_id].phase)
				if phase != field_phase:
					refresh_report()
				elif is_instance_valid(field_status):
					field_status.text = fieldwork.describe(specialist_id))
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
	field_phase = ""
	field_status = null
	title = report.role + " · Crew radio"
	add_theme_stylebox_override("panel", UI.style(Color("101a29"), report.color))
	content.add_child(UI.label(report.role.to_upper(), 24, report.color.lightened(0.25)))
	if fieldwork != null and specialist_id in fieldwork.IDS:
		_add_fieldwork()
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

func _field_action(action: String, argument := "") -> void:
	fieldwork.command(specialist_id, action, argument)
	refresh_report()
	if action == "status" and is_instance_valid(field_status):
		field_status.show()

func _add_fieldwork() -> void:
	field_status = UI.label(fieldwork.describe(specialist_id), 16, UI.TEXT)
	field_phase = "" if fieldwork.data.is_empty() or not fieldwork.data.crew.has(specialist_id) else str(fieldwork.data.crew[specialist_id].phase)
	field_summary = UI.label(fieldwork.SPECIALTIES[specialist_id] + " · " + field_phase, 19, UI.AMBER)
	content.add_child(field_summary)
	if fieldwork.data.is_empty():
		content.add_child(field_status)
		return
	var c: Dictionary = fieldwork.data.crew[specialist_id]
	content.add_child(UI.label(c.message, 16))
	var row := HFlowContainer.new()
	content.add_child(row)
	for entry in [["Talk / status", "status"], ["Assist current step", "assist"], ["Pause", "pause"], ["Resume / retry", "resume"], ["Follow", "follow"], ["Return to base", "return"], ["Regroup crew", "regroup"]]:
		var action: String = entry[1]
		var button := UI.button(entry[0], func(): _field_action(action))
		button.custom_minimum_size.x = 160
		row.add_child(button)
	field_status.visible = false
	var details := UI.button("Status / records and activity log", func(): field_status.visible = not field_status.visible)
	content.add_child(details)
	content.add_child(field_status)
	if c.phase == "Available" and session.can_advance():
		match specialist_id:
			"water_recycler":
				content.add_child(UI.button("Assign: sample A (accompany on foot)", func(): _field_action("sample", "sample_a")))
				content.add_child(UI.button("Approve optional sample B detour", func(): _field_action("sample", "sample_b")))
				content.add_child(UI.button("Decline detour / stay at base", func(): _field_action("decline")))
				for site in ["instrument_a", "instrument_b"]:
					content.add_child(UI.button("Assign deployment: " + site.replace("_", " "), func(): _field_action("deploy", site)))
			"food_storage":
				content.add_child(UI.button("Assign rover readiness / dust inspection", func(): _field_action("inspect")))
				content.add_child(UI.button("Assign rover maintenance (1 kit + %.1f material, +%.0f health)" % [fieldwork.config.repair_materials, fieldwork.config.repair_points], func(): _field_action("repair")))
			"crew_briefing":
				content.add_child(UI.button("Assign local route / return-reserve review", func(): _field_action("navigate", "sample_a")))
	if specialist_id == "crew_briefing":
		for site in fieldwork.SITES:
			content.add_child(UI.button("Assess destination: " + site.replace("_", " "), func(): _field_action("assess", site)))
	if c.phase == "Blocked":
		content.add_child(UI.button("Assess alternate approach", func(): _field_action("alternative")))
		content.add_child(UI.button("Approve assessed alternative", func(): _field_action("approve")))
	if specialist_id == "food_storage":
		content.add_child(UI.button("Allocate limited power to maintenance", func(): _field_action("priority", "maintenance")))
		content.add_child(UI.button("Allocate limited power to science", func(): _field_action("priority", "science")))
	content.add_child(UI.label("Field supplies: pick up one item near the marked locker, then deliver it beside the specialist. Supplies are finite.", 14, UI.MUTED))
	for item in ["container", "repair_kit"]:
		content.add_child(UI.button("Pick up " + item.replace("_", " ") + " at locker", func(): _field_action("collect", item)))
		if (specialist_id == "water_recycler" and item == "container") or (specialist_id == "food_storage" and item == "repair_kit"):
			content.add_child(UI.button("Deliver " + item.replace("_", " "), func(): _field_action("deliver", item)))
