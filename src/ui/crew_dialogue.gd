extends Control
const UI = preload("res://src/ui/ui_style.gd")
const Report = preload("res://src/ui/crew_report.gd")
const OPTIONS := [["Follow", "follow"], ["Regroup crew", "regroup"], ["Talk / status", "status"], ["Assist current step", "assist"], ["Return to base", "return"]]
signal action_requested(kind: String, event_id: String)
signal report_read
var specialist_id := ""
var site_id := ""
var session: Node
var fieldwork: Node
var world: Node
var view: Control
var buttons: Array[Button] = []
var selected := 2
var saved_speaker := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	session = get_node("/root/MissionSession")
	world = get_parent().get_parent()
	fieldwork = world.get_node_or_null("CrewFieldwork")
	view = preload("res://src/ui/conversation_view.gd").new()
	add_child(view)
	for index in OPTIONS.size():
		var button := UI.button("%d  %s" % [index + 1, OPTIONS[index][0]], _choose.bind(index))
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := UI.style(Color(0.025, 0.06, 0.08, 0.85), Color("f3cc74") if state == "focus" else Color(0.55, 0.72, 0.75, 0.5))
			style.set_corner_radius_all(20)
			style.content_margin_top = 8
			style.content_margin_bottom = 8
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
	specialist_id = id
	site_id = session.selected_site_id
	saved_speaker = world.dialogue_speaker
	world.dialogue_speaker = id
	show()
	view.begin(world)
	view.present(id, "What do you need, Commander?", "smiling")
	view.hint.text = "Mouse wheel: choose · Enter / E: confirm · 1–5: select · Esc: leave"
	_select(2)

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
	session.crew_read_reports[specialist_id] = report.signature
	report_read.emit()

func _select(index: int) -> void:
	selected = posmod(index, buttons.size())
	buttons[selected].grab_focus()

func _choose(index: int) -> void:
	if not visible: return
	var action: String = OPTIONS[index][1]
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
		_select(selected + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: hide()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5: _choose(event.keycode - KEY_1)
		elif event.keycode in [KEY_ENTER, KEY_E]: _choose(selected)
		elif event.keycode in [KEY_UP, KEY_DOWN]: _select(selected + (-1 if event.keycode == KEY_UP else 1))
		else: return
		get_viewport().set_input_as_handled()

func _request(kind: String, event_id: String) -> void:
	hide()
	action_requested.emit(kind, event_id)
