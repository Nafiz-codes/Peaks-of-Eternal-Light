extends Control
const UI = preload("res://src/ui/ui_style.gd")
const Report = preload("res://src/ui/crew_report.gd")
const OPTIONS := [["Talk / status", "status"], ["Follow", "follow"], ["Regroup crew", "regroup"], ["Assist current step", "assist"], ["Return to base", "return"], ["Ask about Alex", "alex"]]
signal action_requested(kind: String, event_id: String)
signal report_read
var specialist_id := ""
var site_id := ""
var session: Node
var fieldwork: Node
var world: Node
var view: Control
var buttons: Array[Button] = []
var selected := 0
var saved_speaker := ""
var response_open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	session = get_node("/root/MissionSession")
	world = get_parent().get_parent()
	fieldwork = world.get_node_or_null("CrewFieldwork")
	view = preload("res://src/ui/conversation_view.gd").new()
	add_child(view)
	for index in OPTIONS.size():
		var button := UI.button(str(OPTIONS[index][0]), func(): pass)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.custom_minimum_size.y = 28
		button.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := UI.style(Color(0.025, 0.06, 0.08, 0.85), Color("f3cc74") if state == "focus" else Color(0.55, 0.72, 0.75, 0.5))
			style.set_corner_radius_all(5)
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, style)
		view.choices.add_child(button)
		buttons.append(button)
	hide()
	visibility_changed.connect(func():
		if not visible:
			view.end()
			world.dialogue_speaker = saved_speaker)
	session.state_changed.connect(func():
		if visible and site_id != session.selected_site_id: hide())

func open_conversation(id: String) -> void:
	if not Report.ROLES.has(id): return
	response_open = false
	specialist_id = id
	site_id = session.selected_site_id
	saved_speaker = world.dialogue_speaker
	world.dialogue_speaker = id
	show()
	view.choice_actor = world.get_node("Outpost/" + id)
	view.begin(world)
	view._position_choices()
	view.show_options_only()
	buttons[5].visible = _alex_available()
	view._position_choices()
	view.hint.text = "Mouse wheel: choose · E / left-click: select · Esc: leave"
	_select(0)

func open_status(id: String) -> void:
	open_conversation(id)
	refresh_report()

func refresh_report() -> void:
	var events: Array = [] if session.dashboard_simulator == null else session.dashboard_simulator.events
	var report := Report.build(specialist_id, session.dashboard_state, events)
	var text: String = report.update
	if fieldwork != null and not fieldwork.data.is_empty() and fieldwork.data.crew.has(specialist_id):
		text = str(fieldwork.data.crew[specialist_id].message)
	view.present(specialist_id, text.replace("Commander", session.commander_address()), "neutral")
	response_open = true
	view.choices.hide()
	view.hint.text = "E / left-click: return to gameplay"
	session.crew_read_reports[specialist_id] = report.signature
	report_read.emit()

func _select(index: int) -> void:
	selected = posmod(index, 6 if buttons[5].visible else 5)
	buttons[selected].grab_focus()

func _choose(index: int) -> void:
	if not visible: return
	var action: String = OPTIONS[index][1]
	if action == "alex":
		if not _alex_available(): return
		hide()
		world.maya_dialogue_active = true
		world.dialogue_speaker = "food_storage"
		var dialogue := preload("res://src/ui/maya_introduction.gd").new()
		dialogue.dialogue_id = "sam_alex"
		dialogue.finished.connect(func():
			world.maya_dialogue_active = false
			world.dialogue_speaker = "")
		world.add_child(dialogue)
		return
	if action == "status":
		hide()
		world._on_player_interaction(specialist_id, true)
		return
	if fieldwork == null: return
	fieldwork.command(specialist_id, action)
	refresh_report()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not response_open: _select(selected + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		get_viewport().set_input_as_handled()
		if response_open: hide()
		else:
			# Clicking a visible row selects it; clicking elsewhere confirms the scroll selection.
			for index in buttons.size():
				if buttons[index].visible and buttons[index].get_global_rect().has_point(event.position):
					_select(index)
					break
			_choose(selected)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: hide()
		elif event.keycode == KEY_E:
			if response_open: hide()
			else: _choose(selected)
		# Consume other keys so focused buttons cannot activate via Enter/Space.
		get_viewport().set_input_as_handled()

func _request(kind: String, event_id: String) -> void:
	hide()
	action_requested.emit(kind, event_id)

func _alex_available() -> bool:
	var expedition: Dictionary = world.get_node("RoverTraining").data
	return specialist_id == "food_storage" and bool(expedition.get("dust_storm_complete", false)) and expedition.get("completed", []).has(1) and not expedition.get("completed", []).has(2)
