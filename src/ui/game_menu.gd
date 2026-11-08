extends CanvasLayer
## Always processes while the world is paused. Esc backs out one level at a time.
const UI = preload("res://src/ui/ui_style.gd")
const Save = preload("res://src/runtime/mission_save.gd")
const OUTPOST := "res://scenes/lunar_outpost_3d.tscn"
const SELECTOR := "res://scenes/lunar_landing_selector.tscn"
var overlay: Control
var body: VBoxContainer
var heading: Label
var notice: Label
var page := "home"
var opened := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var previous_focus: WeakRef
var session: Node
var settings: Node
var save_directory := "user://"
var pending_action := Callable()
var confirm_return := "home"
var resume_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	session = get_node("/root/MissionSession")
	settings = get_node("/root/GameSettings")
	overlay = Control.new()
	var menu_theme := Theme.new()
	menu_theme.default_font = preload("res://Assets/fonts/Request.otf")
	overlay.theme = menu_theme
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var space_material := ShaderMaterial.new()
	space_material.shader = preload("res://src/ui/menu_space.gdshader")
	space_material.set_shader_parameter("earth_texture", preload("res://Assets/earth/Earth_Diffuse_6K.jpg"))
	backdrop.material = space_material
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := MarginContainer.new()
	overlay.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 28)
	var layout := UI.box()
	frame.add_child(layout)
	var title := UI.label("PEAKS OF ETERNAL LIGHT", 34)
	title.add_theme_color_override("font_shadow_color", Color("28607d"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	layout.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 46)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.follow_focus = true
	nav_scroll.custom_minimum_size.x = 250
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(nav_scroll)
	var nav := UI.box()
	nav.add_theme_constant_override("separation", 4)
	nav_scroll.add_child(nav)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	nav.add_child(spacer)
	resume_button = UI.button("Resume mission", close_menu)
	nav.add_child(resume_button)
	_style_navigation(resume_button)
	for entry in [["Mission status", "home"], ["Outposts", "outposts"], ["Objectives", "objectives"], ["Save & load", "saves"], ["Settings", "settings"], ["Controls", "controls"], ["Mission help", "help"], ["Science & sources", "science"]]:
		var destination: String = entry[1]
		var button := UI.button(entry[0], func(): show_page(destination))
		button.set_meta("menu_page", destination)
		nav.add_child(button)
		_style_navigation(button)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _space_style(Color(0.015, 0.045, 0.075, 0.76), Color(0.16, 0.48, 0.65, 0.55)))
	columns.add_child(panel)
	var content := UI.box()
	panel.add_child(content)
	heading = UI.label("MISSION PAUSED", 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var line := HSeparator.new()
	var separator_style := StyleBoxLine.new()
	separator_style.color = Color(0.12, 0.36, 0.48, 0.6)
	separator_style.thickness = 1
	line.add_theme_stylebox_override("separator", separator_style)
	content.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	body = UI.box()
	scroll.add_child(body)
	notice = UI.label("", 14, UI.AMBER)
	layout.add_child(notice)
	overlay.hide()
	get_tree().scene_changed.connect(_scene_changed)

func _process(_delta: float) -> void:
	# The menu owns the cursor until Resume, including after a window focus change.
	if opened and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _scene_changed() -> void:
	if opened:
		close_menu()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	var scene := get_tree().current_scene
	if not opened and scene != null and scene.has_method("handle_navigation_cancel") and scene.handle_navigation_cancel():
		get_viewport().set_input_as_handled()
		return
	if not opened and _modal_visible():
		return # Esc belongs to the current decision/operations dialog first.
	get_viewport().set_input_as_handled()
	if not opened:
		open_menu()
	elif page == "home":
		close_menu()
	elif page == "confirm":
		pending_action = Callable()
		show_page(confirm_return)
	else:
		show_page("home")

func _modal_visible() -> bool:
	var scene := get_tree().current_scene
	if scene != null:
		for window in scene.find_children("*", "Window", true, false):
			if window.visible:
				return true
	return false

func open_menu() -> void:
	if opened or get_tree().current_scene == null or _modal_visible():
		return
	previous_mouse_mode = Input.mouse_mode
	var focus := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focus) if focus != null else null
	session.remember_pose()
	get_tree().paused = true
	opened = true
	overlay.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	notice.text = ""
	show_page("home")

func close_menu() -> void:
	if not opened:
		return
	opened = false
	get_tree().paused = false
	overlay.hide()
	pending_action = Callable()
	Input.set_mouse_mode(previous_mouse_mode)
	if previous_focus != null:
		var focus: Variant = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()

func _clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func show_page(destination: String) -> void:
	page = destination
	_clear_body()
	heading.text = "MISSION PAUSED" if page == "home" else page.replace("_", " ").to_upper()
	match page:
		"home": _home()
		"outposts": _outposts()
		"objectives": _objectives()
		"saves": _saves()
		"settings": _settings()
		"controls": _controls()
		"help": _help()
		"science": _science()
	if page != "home":
		body.add_child(UI.button("Back  ·  Esc", func(): show_page("home")))
	_focus_first()

func _focus_first() -> void:
	_refresh_space_style()

	for control in overlay.find_children("*", "Control", true, false):
		if control is BaseButton or control is Slider:
			control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if page == "home":
		resume_button.grab_focus()
		return
	for control in body.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and (not control is BaseButton or not control.disabled):
			control.grab_focus()
			return

func _site_name() -> String:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.sites:
		if site.site_id == session.selected_site_id:
			return site.name
	return "Choose a landing site"

func _home() -> void:
	body.add_child(UI.label(_site_name(), 23, UI.BLUE))
	body.add_child(UI.label(session.commander_name() + " · Commander", 18, UI.AMBER))
	var state: Variant = session.dashboard_state
	if state == null:
		body.add_child(UI.label("Exploration · Mission not started", 17, UI.MUTED))
	else:
		body.add_child(UI.label("SOL %02d / %d   ·   %s" % [state.sol, state.mission_length_sols, str(state.mission_outcome.get("status", "")).replace("_", " ").to_upper()], 18, UI.PURPLE))
		var cards := GridContainer.new()
		cards.columns = 2
		cards.add_theme_constant_override("h_separation", 12)
		cards.add_theme_constant_override("v_separation", 8)
		body.add_child(cards)
		for text_ in ["Energy  %.2f kWh" % state.power_kwh, "Water  %.2f L" % state.water_l, "Oxygen  %.2f kg" % state.oxygen_kg, "Food  %.2f kg" % state.food_kg, "Dose  %.3f mSv (modeled)" % state.radiation_msv, "Materials  %.1f" % state.materials]:
			UI.panel(cards).add_child(UI.label(text_, 16))
		body.add_child(UI.label("%d pending decisions  ·  %d active effects" % [state.pending_events.size(), state.active_events.size()], 16, UI.AMBER))
		for effect in state.active_events:
			body.add_child(UI.label(str(effect.get("title", effect.get("event_id", "Active effect"))).replace("_", " "), 14, UI.MUTED))
	body.add_child(UI.button("Mission dashboard / report", _dashboard, session.selected_site_id.is_empty()))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 8)
	body.add_child(actions)
	actions.add_child(UI.button("Restart current sol", func(): confirm("Restart this sol?", "Restore the start of this sol, before its decisions and actions. Later changes will be lost. Saved slots are kept.", _restart_sol), session.sol_checkpoint.is_empty()))
	actions.add_child(UI.button("Restart mission", func(): confirm("Restart the mission?", "Start again at Sol 0 at this outpost. Current progress will be lost. Saved slots are kept.", _restart_mission), state == null))
	actions.add_child(UI.button("Landing site selection", func(): confirm("Return to landing sites?", "Your current mission stays in memory until another site is selected. Save first to keep a copy across restarts.", _landing)))
	actions.add_child(UI.button("Quit to desktop", func(): confirm("Quit the game?", "Unsaved progress will be lost. You can cancel and save from Save & load.", func(): get_tree().quit())))
	for button in actions.get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _outposts() -> void:
	body.add_child(UI.label("Travel to another outpost", 23, UI.BLUE))
	body.add_child(UI.label("Choose a destination to enter it directly. Switching starts a fresh visit; save your current mission in Save & load if you want to return to its progress later.", 16, UI.MUTED))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.sites:
		var site_id: String = site.site_id
		var site_name: String = site.name
		var current: bool = site_id == session.selected_site_id
		var card := UI.panel(body)
		card.add_child(UI.label(site_name + (" · Current outpost" if current else ""), 18, UI.BLUE))
		card.add_child(UI.button("Current outpost" if current else "Travel here", func():
			confirm("Travel to %s?" % site_name, "Leave this outpost and enter %s? Unsaved mission progress will be lost. Your saved slots will be kept." % site_name, func(): _travel_to_outpost(site_id)), current or session.action_busy))
	body.add_child(UI.button("Open landing map", func(): confirm("Open landing map?", "Choose an outpost on the globe. Save your current mission first if you want to keep its progress when selecting another site.", _landing)))

func _travel_to_outpost(site_id: String) -> void:
	# Load the destination before replacing the current session.
	var destination := load(OUTPOST) as PackedScene
	if destination == null:
		notice.text = "Could not open the outpost. Your current mission is intact."
		show_page("outposts")
		return
	session.select_landing_site(site_id)
	session.return_scene_path = ""
	session.action_busy = false
	close_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_packed(destination)

func _objectives() -> void:
	var state: Variant = session.dashboard_state
	if state == null:
		body.add_child(UI.label("Choose an outpost and start the mission from the dashboard or the Alt mission panel.", 18))
		return
	body.add_child(UI.label(str(state.mission_outcome.get("primary_objective", "Sustain the crew.")), 23, UI.BLUE))
	body.add_child(UI.label("Progress: Sol %d of %d" % [state.sol, state.mission_length_sols], 18))
	for entry in [["Water", state.water_l > 0], ["Oxygen", state.oxygen_kg > 0], ["Food", state.food_kg > 0], ["Avoid two consecutive sols without power", state.consecutive_power_depleted_sols < 2], ["Resolve pending decisions", state.pending_events.is_empty()]]:
		body.add_child(UI.label(("✓ " if entry[1] else "! ") + entry[0], 17, UI.TEXT if entry[1] else UI.AMBER))
	body.add_child(UI.label("Outcome: " + str(state.mission_outcome.get("status", "in_progress")).replace("_", " "), 18, UI.PURPLE))
	if state.mission_outcome.get("status") == "failure":
		body.add_child(UI.label(str(state.mission_outcome.get("failure_reason", "")).replace("_", " "), 16, UI.AMBER))
	body.add_child(UI.label("Construction and rover panels currently provide planning previews. They are not additional completion requirements.", 15, UI.MUTED))

func slot_path(index: int) -> String:
	return save_directory.path_join("mission_slot_%d.save" % index)

func _saves() -> void:
	heading.text = "SAVE & LOAD"
	body.add_child(UI.label("Three local slots · includes mission history, decisions, camera position, and the current-sol checkpoint.", 16, UI.MUTED))
	for index in range(1, 4):
		var path := slot_path(index)
		var data := Save.read_file(path)
		var valid := not Save.decode(data).is_empty()
		var card := UI.panel(body)
		var detail := "Empty"
		if FileAccess.file_exists(path):
			detail = "%s · Sol %s · %s" % [data.get("site_id", ""), data.get("state", {}).get("sol", "exploration"), data.get("saved_at", "")] if valid else "Unreadable or incompatible save"
		card.add_child(UI.label("SLOT %d  /  %s" % [index, detail], 16, UI.BLUE))
		var buttons := HBoxContainer.new()
		card.add_child(buttons)
		buttons.add_child(UI.button("Save here", func():
			if FileAccess.file_exists(path):
				confirm("Overwrite slot %d?" % index, "Replace this saved mission with your current progress?", func(): _save(index))
			else:
				_save(index), session.selected_site_id.is_empty() or session.action_busy))
		buttons.add_child(UI.button("Load", func(): confirm("Load slot %d?" % index, "Replace the current session with this saved mission? Unsaved changes will be lost.", func(): _load(index)), not valid))
		for button in buttons.get_children():
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _save(index: int) -> void:
	var error: int = session.save_slot(slot_path(index))
	notice.text = "Saved to slot %d." % index if error == OK else "Could not save: " + error_string(error)
	show_page("saves")

func _load(index: int) -> void:
	var error: int = session.load_slot(slot_path(index))
	if error != OK:
		notice.text = "Could not load this save. Your current mission is intact."
		show_page("saves")
		return
	_go_to(OUTPOST)

func _settings() -> void:
	body.add_child(UI.label("Audio", 21, UI.BLUE))
	var music_toggle := CheckButton.new()
	music_toggle.text = "Music enabled"
	music_toggle.button_pressed = settings.values.music_enabled
	music_toggle.toggled.connect(func(enabled: bool): settings.change("music_enabled", enabled))
	body.add_child(music_toggle)
	for entry in [["Master volume", "master", 0.0, 1.0, 0.05], ["Music volume", "music", 0.0, 1.0, 0.05], ["Effects volume", "effects", 0.0, 1.0, 0.05]]:
		_slider(entry)
	_slider(["Mission ambience · default 20%", "mission_music", 0.0, 1.0, 0.01])
	body.add_child(UI.label("Mission ambience is reduced further by Music and Master volume.", 13, UI.MUTED))
	body.add_child(UI.label("Camera & display", 21, UI.BLUE))
	_slider(["Mouse sensitivity", "sensitivity", 0.25, 3.0, 0.05])
	_slider(["Brightness", "brightness", 0.6, 1.5, 0.05])
	for entry in [["Invert vertical look", "invert_y"], ["Fullscreen", "fullscreen"], ["Reduce motion", "reduce_motion"]]:
		var key: String = entry[1]
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.custom_minimum_size.y = 40
		toggle.button_pressed = settings.values[key]
		toggle.toggled.connect(func(enabled: bool): settings.change(key, enabled))
		body.add_child(toggle)
	body.add_child(UI.label("Graphics quality / edge smoothing", 16))
	var quality := OptionButton.new()
	quality.custom_minimum_size.y = 44
	for text_ in ["Low · no antialiasing", "Medium · 2× antialiasing", "High · 4× antialiasing"]:
		quality.add_item(text_)
	quality.select(settings.values.quality)
	quality.item_selected.connect(func(index: int): settings.change("quality", index))
	body.add_child(quality)
	body.add_child(UI.label("Settings apply immediately and are saved on this device.", 14, UI.MUTED))

func _slider(entry: Array) -> void:
	var key: String = entry[1]
	var label := UI.label("%s  ·  %.2f" % [entry[0], settings.values[key]], 16)
	body.add_child(label)
	var slider := HSlider.new()
	slider.min_value = entry[2]
	slider.max_value = entry[3]
	slider.step = entry[4]
	slider.value = settings.values[key]
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float):
		settings.change(key, value)
		label.text = "%s  ·  %.2f" % [entry[0], value])
	body.add_child(slider)

func _controls() -> void:
	body.add_child(UI.label("Inside lander: R — Control rover / return to seat. Rover: W/S — forward/reverse, A/D — steer, Space — brake. Esc pauses remote driving.", 17, UI.BLUE))
	for text_ in ["Esc — Open pause menu; go back; resume", "W A S D — Move", "Shift + W — Sprint forward", "Mouse — Look / orbit", "Space — Jump", "E — Talk to station crew / enter or exit the lander", "V — First / third person", "C — Front / rear orbit view", "Alt — Show / hide mission details and release cursor", "I — Mission dashboard / return", "Tab / Shift + Tab — Navigate menu controls", "Enter / Space — Activate a focused button", "Landing globe: right-drag to orbit, wheel to zoom, click a site to land"]:
		body.add_child(UI.label(text_, 17))

func _help() -> void:
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/mission_copy.json"))
	body.add_child(UI.label(copy.mission_briefing.opening, 18, UI.BLUE))
	for step in copy.tutorial_steps:
		body.add_child(UI.label(step.title, 19))
		body.add_child(UI.label(step.body, 16, UI.MUTED))
	body.add_child(UI.label("Queue structures in Construction planning. Drive the rover from inside the lander with R and WASD. Advance the mission with Run the sol; resolve pending decisions before continuing.", 16, UI.AMBER))

func _science() -> void:
	heading.text = "SCIENCE & SOURCES"
	body.add_child(UI.label("NASA data and game assumptions", 22, UI.BLUE))
	body.add_child(UI.label("LOLA elevation comes from 5 m regional polar DEMs; slope is a derived estimate, not a verified slope measurement or landing-pad survey. Solar visibility uses NASA/JPL Horizons geometry and a regional NASA LOLA-derived terrain horizon. Local hydrogen is unmeasured at these study coordinates. Radiation uses a NASA model with a gameplay terrain modifier; water recycling uses an ISS proxy.", 16))
	body.add_child(UI.label("The visible Sun and Earth use NASA/JPL Horizons DE441 positions with linear interpolation and an enlarged Earth for visibility. During a mission the sky advances one modeled Earth day per sol. Solar power uses date-dependent Sun distance, solar-disk visibility, and a NASA LOLA-derived local horizon; tracking-array capacity is a gameplay rating, while the hand-placed solar panel is rated from NASA total solar irradiance (1361 W/m²) and NASA's 30% nominal space solar cell efficiency. Suits, structures, terrain, starting reserves, and event choices include authored game content.", 16, UI.MUTED))
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/data_sources.json"))
	for source in registry.sources:
		var url: String = source.get("landing_page", source.get("url", ""))
		var card := UI.panel(body)
		card.add_child(UI.label(source.get("title", "Source"), 17, UI.BLUE))
		card.add_child(UI.label(source.get("data_kind", ""), 14, UI.MUTED))
		if url.begins_with("https://"):
			card.add_child(UI.button("Open source ↗", func(): OS.shell_open(url)))
	body.add_child(UI.button("NASA/JPL Horizons ↗", func(): OS.shell_open("https://ssd.jpl.nasa.gov/horizons/")))

func confirm(title: String, message: String, action: Callable) -> void:
	confirm_return = page
	page = "confirm"
	pending_action = action
	_clear_body()
	heading.text = title
	body.add_child(UI.label(message, 19, UI.AMBER))
	body.add_child(UI.button("Cancel  ·  Esc", func():
		pending_action = Callable()
		show_page(confirm_return)))
	body.add_child(UI.button("Confirm", func():
		var callback := pending_action
		pending_action = Callable()
		if callback.is_valid():
			callback.call()))
	_focus_first()

func _restart_sol() -> void:
	session.transition_sol(_restart_sol_now)

func _restart_sol_now() -> void:
	if session.restart_current_sol() == OK:
		_go_to(OUTPOST)
	else:
		notice.text = "No start-of-sol checkpoint is available."
		show_page("home")

func _restart_mission() -> void:
	if session.reset_current_mission() == OK:
		session.outpost_pose = {}
		session.sol_checkpoint.pose = {}
		_go_to(OUTPOST)
	else:
		notice.text = "Mission data could not be loaded."
		show_page("home")

func _landing() -> void:
	session.remember_pose()
	_go_to(SELECTOR)

func _dashboard() -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path
	close_menu()
	if path == "res://scenes/mission_dashboard.tscn":
		return
	session.open_dashboard(path)

func _go_to(path: String) -> void:
	close_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		open_menu()
		notice.text = "Could not open the destination: " + error_string(error)


# Menu-local styles leave the dashboard and all gameplay UI untouched.
func _space_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var result := UI.style(fill, edge)
	result.set_corner_radius_all(0)
	return result

func _style_navigation(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _space_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _space_style(Color(0.02, 0.38, 0.58, 0.55), Color("40cfff")))
	button.add_theme_stylebox_override("pressed", _space_style(Color(0.02, 0.45, 0.65, 0.65), Color("83eaff")))
	button.add_theme_stylebox_override("focus", _space_style(Color(0.04, 0.35, 0.52, 0.25), Color("59dfff")))

func _refresh_space_style() -> void:
	for button in overlay.find_children("*", "Button", true, false):
		if button.has_meta("menu_page"):
			var selected: bool = button.get_meta("menu_page") == page
			button.add_theme_stylebox_override("normal", _space_style(Color(0.02, 0.35, 0.55, 0.6) if selected else Color(0, 0, 0, 0), Color("43cfff") if selected else Color(0, 0, 0, 0)))
	for control in body.find_children("*", "Control", true, false):
		if control is Button:
			control.add_theme_stylebox_override("normal", _space_style(Color(0.02, 0.08, 0.13, 0.8), Color(0.18, 0.45, 0.58, 0.65)))
			control.add_theme_stylebox_override("hover", _space_style(Color(0.02, 0.28, 0.4, 0.85), Color("55dfff")))
			control.add_theme_stylebox_override("focus", _space_style(Color(0, 0, 0, 0), Color("83eaff")))
		elif control is PanelContainer:
			control.add_theme_stylebox_override("panel", _space_style(Color(0.02, 0.06, 0.1, 0.68), Color(0.18, 0.4, 0.53, 0.45)))
		elif control is HSlider:
			var track := _space_style(Color(0.04, 0.12, 0.18, 0.95), Color(0.16, 0.38, 0.48, 0.6))
			track.content_margin_top = 3
			track.content_margin_bottom = 3
			control.add_theme_stylebox_override("slider", track)
			var fill := track.duplicate() as StyleBoxFlat
			fill.bg_color = Color("258bb0")
			control.add_theme_stylebox_override("grabber_area", fill)
			control.add_theme_stylebox_override("grabber_area_highlight", fill)
