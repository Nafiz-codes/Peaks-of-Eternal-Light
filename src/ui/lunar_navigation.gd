extends Node
## One camera owner for the planetary overview, free orbit, focus and return.
## The supplied reference defines composition; both planets are independently live.
enum Mode { DORMANT, ENTRANCE, OVERVIEW, APPROACH, FOCUS, EXPLORE, RETURNING, LANDING }
var mode := Mode.DORMANT
var selector: Node3D
var camera: Camera3D
var earth: MeshInstance3D
var layer: CanvasLayer
var canvas: Control
var sidebar: Control
var sidebar_buttons: Array[Button] = []
var zoom_in: Button
var zoom_out: Button
var back_button: Button
var sequence: Tween
var moon_entry := 0.0
var earth_entry := 0.0
var approach := 0.0
var pending_site := ""
var focused_site := ""
var press_position := Vector2.ZERO
var pointer_down := false
var dragged := false
var initial_orbit := Vector2(0.12, -0.12)
var zoom_target := 24.0
var focus_start: Transform3D
var focus_end: Transform3D
var return_start: Transform3D
var return_size := 24.0
var return_progress := 0.0
signal overview_ready

func _ready() -> void:
	selector = get_parent()
	camera = selector.camera
	_build_earth()
	_build_ui()
	# Preserve legacy controls for other entry points, but remove them from this flow.
	for control in selector.menu_layer.get_children():
		if control is Control: control.hide()
	for callout in selector.site_callouts:
		var label: Button = callout.button
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.focus_mode = Control.FOCUS_NONE
		label.add_theme_color_override("font_color", Color("e7f4ff"))
		label.add_theme_color_override("font_outline_color", Color("030810"))
		label.add_theme_constant_override("outline_size", 5)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.06, 0.1, 0.62)
		style.border_color = Color(0.55, 0.78, 0.93, 0.6)
		style.border_width_bottom = 1
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		label.add_theme_stylebox_override("normal", style)
		# Hide the old expensive screen-reading glass layer for these small labels.
		var glass := label.get_node_or_null("FrostedGlass")
		if glass: glass.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _build_earth() -> void:
	earth = MeshInstance3D.new()
	earth.name = "OverviewEarth"
	var mesh := SphereMesh.new()
	mesh.radius = 22.0
	mesh.height = 44.0
	mesh.radial_segments = 96
	mesh.rings = 48
	earth.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/earth/overview_earth.gdshader")
	material.set_shader_parameter("surface_map", preload("res://Assets/earth/Earth_Diffuse_6K.jpg"))
	material.set_shader_parameter("cloud_map", preload("res://Assets/earth/Earth_Clouds_6K.jpg"))
	material.set_shader_parameter("night_map", preload("res://Assets/earth/Earth_Illumination_6K.jpg"))
	earth.material_override = material
	selector.add_child(earth)
	earth.hide()

func _label(text: String, size_: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(button: Button, font_size: int = 18) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for entry in [["normal", 0.16, 1], ["hover", 0.3, 3], ["focus", 0.3, 3], ["pressed", 0.45, 4], ["disabled", 0.09, 1]]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.30, 0.48, 0.62, entry[1])
		style.border_color = Color(0.65, 0.83, 0.96, 0.75)
		style.border_width_left = entry[2]
		style.border_width_right = entry[2]
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(entry[0], style)

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	canvas = Control.new()
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	if font != null:
		font.multichannel_signed_distance_field = true
		canvas.add_theme_font_override("font", font)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar = Control.new()
	sidebar.size = Vector2(410, 560)
	# Blocks clicks in the actual panel, including spaces between entries.
	sidebar.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(sidebar)
	var title := _label("SELECT YOUR\nOUTPOST", 43, Color("edf5fa"))
	title.position.y = 34
	sidebar.add_child(title)
	for i in range(selector.site_records.size()):
		var site: Dictionary = selector.site_records[i]
		var button := Button.new()
		button.text = site.name
		button.name = site.site_id + "_OverviewButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.position = Vector2(0, 185 + i * 59)
		button.size = Vector2(400, 50)
		_style(button)
		button.pressed.connect(enter_moon.bind(str(site.site_id)))
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))
		button.focus_entered.connect(_hover.bind(button, true))
		button.focus_exited.connect(_hover.bind(button, false))
		sidebar.add_child(button)
		sidebar_buttons.append(button)
	var hint := _label("Click the Moon to select a site on its surface.", 14, Color("8ea2b3"))
	hint.position.y = 443
	sidebar.add_child(hint)
	back_button = Button.new()
	back_button.text = "BACK TO START MENU"
	back_button.position = Vector2(0, 505)
	back_button.size = Vector2(400, 44)
	_style(back_button, 16)
	back_button.pressed.connect(go_back)
	sidebar.add_child(back_button)
	sidebar.modulate.a = 0.0
	sidebar.hide()
	zoom_in = Button.new()
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoom in"
	zoom_out = Button.new()
	zoom_out.text = "−"
	zoom_out.tooltip_text = "Zoom out"
	for button in [zoom_in, zoom_out]:
		canvas.add_child(button)
		_style(button, 28)
		button.hide()
	zoom_in.pressed.connect(zoom_by.bind(0.8))
	zoom_out.pressed.connect(zoom_by.bind(1.25))
	preload("res://src/ui/menu_navigation.gd").configure(sidebar_buttons, [back_button, zoom_in, zoom_out])

func _hover(button: Button, active: bool) -> void:
	if mode != Mode.OVERVIEW: return
	if active and not button.has_focus(): button.grab_focus()
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		old.kill()
	var tween := create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "position:x", 6.0 if active or button.has_focus() else 0.0, 0.14)

func _layout() -> void:
	if sidebar == null: return
	var size_ := get_viewport().get_visible_rect().size
	var factor := minf(size_.x / 1360.0, size_.y / 820.0)
	sidebar.scale = Vector2.ONE * factor
	sidebar.position = Vector2(size_.x * 0.065, (size_.y - sidebar.size.y * factor) * 0.5)
	var button_size := Vector2.ONE * clampf(52 * factor, 44, 72)
	zoom_in.size = button_size
	zoom_out.size = button_size
	var margin := clampf(28 * factor, 16, 40)
	zoom_out.position = Vector2(size_.x - margin - button_size.x, margin)
	zoom_in.position = zoom_out.position - Vector2(button_size.x + 10, 0)
	if mode in [Mode.ENTRANCE, Mode.OVERVIEW, Mode.APPROACH, Mode.RETURNING]:
		_compose()
	selector._update_site_callouts()

func _process(_delta: float) -> void:
	if mode in [Mode.ENTRANCE, Mode.APPROACH, Mode.RETURNING]: _compose()
	if mode == Mode.EXPLORE:
		zoom_in.disabled = camera.size <= 0.50001
		zoom_out.disabled = camera.size >= 35.9999

func _compose() -> void:
	var size_ := get_viewport().get_visible_rect().size
	var progress := approach
	camera.size = lerpf(46.0, 24.0, progress)
	var center := Vector2(lerpf(0.71, 0.5, progress), lerpf(lerpf(-0.34, 0.29, moon_entry), 0.5, progress))
	if mode == Mode.RETURNING:
		camera.size = lerpf(return_size, 46.0, return_progress)
		center = Vector2(lerpf(0.5, 0.71, return_progress), lerpf(0.5, 0.29, return_progress))
		camera.transform = return_start.interpolate_with(focus_end, return_progress)
	camera.h_offset = (0.5 - center.x) * camera.size * size_.x / size_.y
	camera.v_offset = (center.y - 0.5) * camera.size
	camera.force_update_transform()
	var earth_y := lerpf(1.72, 1.12, earth_entry) + progress * 1.0
	if mode == Mode.RETURNING: earth_y = lerpf(2.12, 1.12, return_progress)
	earth.global_position = camera.project_position(Vector2(size_.x * 0.71, size_.y * earth_y), 28.0)
	earth.basis = camera.basis * Basis(Vector3.UP, -1.0) * Basis(Vector3.FORWARD, 0.22)
	earth.scale = Vector3.ONE * (camera.size * 0.48 / 22.0)

func begin_entrance() -> void:
	if mode != Mode.DORMANT: return
	mode = Mode.ENTRANCE
	selector.polar_view = false
	selector.orbit = initial_orbit
	selector._update_camera()
	selector.menu_layer.show()
	earth.show()
	_compose()
	sequence = create_tween().set_parallel(true)
	sequence.tween_property(self, "moon_entry", 1.0, 1.8).set_delay(0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_property(self, "earth_entry", 1.0, 1.8).set_delay(0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	sequence.chain().tween_callback(_show_overview)

func _show_overview() -> void:
	mode = Mode.OVERVIEW
	moon_entry = 1.0
	earth_entry = 1.0
	approach = 0.0
	_compose()
	sidebar.show()
	back_button.disabled = false
	for button in sidebar_buttons:
		button.disabled = false
		button.modulate = Color.WHITE
	for button in [zoom_in, zoom_out]:
		button.show()
		button.disabled = false
	sequence = create_tween()
	sequence.tween_property(sidebar, "modulate:a", 1.0, 0.5)
	sequence.tween_callback(func():
		if mode == Mode.OVERVIEW:
			sidebar_buttons[0].grab_focus()
			overview_ready.emit())

func moon_hit(point: Vector2) -> bool:
	# Orthographic ray/sphere tests match rendered silhouettes and foreground depth.
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	var moon_distance := _sphere_distance(origin, ray, selector.global_position, selector.MOON_RADIUS)
	if moon_distance < 0.0: return false
	var earth_distance := _sphere_distance(origin, ray, earth.global_position, 22.0 * earth.scale.x) if earth.visible else -1.0
	return earth_distance < 0.0 or earth_distance > moon_distance

func _sphere_distance(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> float:
	var delta := origin - center
	var b := delta.dot(direction)
	var determinant := b * b - delta.length_squared() + radius * radius
	if determinant < 0.0: return -1.0
	var distance := -b - sqrt(determinant)
	return distance if distance >= 0.0 else -1.0

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.OVERVIEW:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and moon_hit(event.position):
			enter_moon()
			get_viewport().set_input_as_handled()

		return
	if mode != Mode.EXPLORE: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_down = true
				press_position = event.position
				dragged = false
			else:
				if pointer_down and not dragged and press_position.distance_to(event.position) < 6.0:
					for callout in selector.site_callouts:
						if callout.button.visible and callout.button.get_global_rect().has_point(event.position):
							selector.select_site(str(callout.site_id))
							break
				pointer_down = false
	if event is InputEventMouseMotion:
		if pointer_down and press_position.distance_to(event.position) >= 6.0: dragged = true
		if (pointer_down and dragged) or event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_stop_sequence()
			selector.globe_zoom_size = camera.size
			selector.orbit.x = wrapf(selector.orbit.x - event.relative.x * 0.005, -PI, PI)
			selector.orbit.y = clampf(selector.orbit.y + event.relative.y * 0.005, -PI * 0.5 + 0.001, PI * 0.5 - 0.001)
			selector._update_camera()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# A release over a GUI control (or outside the window) must not leave a drag latched.
	if mode != Mode.EXPLORE or not pointer_down: return
	if event is InputEventMouseMotion and not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pointer_down = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			pointer_down = false

func enter_moon(site_id: String = "") -> void:
	if mode != Mode.OVERVIEW: return
	if not site_id.is_empty() and selector._site_by_id(site_id).is_empty(): return
	get_node("/root/GameAudio").play_ui_click()
	_stop_sequence()
	pending_site = site_id
	mode = Mode.APPROACH
	back_button.disabled = true
	for button in sidebar_buttons:
		button.disabled = true
		button.modulate = Color("b8e7ff") if button.name == site_id + "_OverviewButton" else Color(0.7, 0.7, 0.7)
	for button in [zoom_in, zoom_out]: button.disabled = true
	sequence = create_tween().set_parallel(true)
	sequence.tween_property(sidebar, "modulate:a", 0.0, 0.55)
	sequence.tween_property(self, "approach", 1.0, 1.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	sequence.chain().tween_callback(_arrive)

func _arrive() -> void:
	approach = 1.0
	_compose()
	earth.hide()
	sidebar.hide() # Hidden controls cannot intercept exploration input.
	selector.globe_zoom_size = camera.size
	if pending_site.is_empty():
		_explore()
	else:
		mode = Mode.FOCUS
		focused_site = pending_site
		focus_start = camera.transform
		focus_end = selector.site_camera_target(focused_site)
		sequence = create_tween()
		sequence.tween_method(_focus, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		# A sidebar choice is a deployment, not a request for a second confirmation.
		sequence.tween_callback(func(): selector.select_site(focused_site))

func _focus(progress: float) -> void:
	camera.transform = focus_start.interpolate_with(focus_end, progress)
	camera.size = lerpf(24.0, 8.0, progress)
	camera.force_update_transform()

func _explore() -> void:
	mode = Mode.EXPLORE
	pointer_down = false
	_sync_orbit()
	selector.globe_zoom_size = camera.size
	zoom_target = camera.size
	for button in [zoom_in, zoom_out]: button.disabled = false
	selector._update_site_callouts()

func _sync_orbit() -> void:
	var normal := camera.position.normalized()
	selector.orbit = Vector2(atan2(normal.x, normal.z), asin(clampf(normal.y, -1.0, 1.0)))

func labels_visible() -> bool:
	return mode == Mode.EXPLORE

func zoom_by(factor: float) -> void:
	if mode == Mode.OVERVIEW:
		enter_moon()
		return
	if mode != Mode.EXPLORE: return
	_stop_sequence()
	zoom_target = clampf(camera.size * factor, 0.5, 36.0)
	sequence = create_tween()
	sequence.tween_method(_zoom, camera.size, zoom_target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _zoom(value: float) -> void:
	camera.size = value
	selector.globe_zoom_size = value
	selector._update_site_callouts()

func go_back() -> void:
	if mode == Mode.OVERVIEW:
		_stop_sequence()
		mode = Mode.RETURNING
		var session := get_node("/root/MissionSession")
		session.skip_next_startup_intro = true
		var error := get_tree().change_scene_to_file("res://scenes/startup.tscn")
		if error != OK:
			session.skip_next_startup_intro = false
			_show_overview()
		return
	if mode != Mode.EXPLORE: return
	_stop_sequence()
	mode = Mode.RETURNING
	pointer_down = false
	return_start = camera.transform
	return_size = camera.size
	return_progress = 0.0
	# Construct the overview target without moving the live camera first.
	var direction := Vector3(sin(initial_orbit.x) * cos(initial_orbit.y), sin(initial_orbit.y), cos(initial_orbit.x) * cos(initial_orbit.y))
	focus_end = Transform3D(Basis.looking_at(-direction, Vector3.UP), direction * 30.0)
	for button in [zoom_in, zoom_out]: button.disabled = true
	earth.show()
	sequence = create_tween()
	sequence.tween_property(self, "return_progress", 1.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_callback(func():
		selector.orbit = initial_orbit
		_show_overview())

func prepare_landing() -> void:
	_stop_sequence()
	mode = Mode.LANDING
	layer.hide()

func _stop_sequence() -> void:
	if sequence: sequence.kill()

func _exit_tree() -> void:
	_stop_sequence()
