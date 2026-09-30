class_name LunarLandingSelector
extends Node3D

## Globe coordinates are planetocentric, with east-positive longitude.
## Global NASA LROC maps and LOLA relief share the same longitude convention.
const SITES_PATH := "res://Resources/sites.json"
const MOON_RADIUS := 10.0
const PIN_HEIGHT := 0.045
signal site_selected(site_id: String)

var site_records: Array[Dictionary] = []
var selected_site_id := ""
var launch_outpost_on_selection := true
var polar_view := false
var orbit := Vector2(0.0, -PI * 0.5 + 0.001)
var camera: Camera3D
var view_button: Button
var caption: Label
var map_button: Button
var use_legacy_map := false
var site_callouts: Array[Dictionary] = []
var globe_zoom_size := 24.0
var polar_zoom_size := 0.95
var zoom_in_button: Button
var zoom_out_button: Button
var zoom_reset_button: Button
var landing_in_progress := false
var menu_layer: CanvasLayer

func _ready() -> void:
	set_process_unhandled_input(true)
	_add_environment()
	_add_map_surface()
	_load_site_markers()
	_add_polar_grid()
	_add_camera()
	_add_menu()
	_update_site_callouts()

func _unhandled_input(event: InputEvent) -> void:
	if landing_in_progress:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_open_dashboard()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(0.8)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.25)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT and not polar_view:
		orbit.x = wrapf(orbit.x - event.relative.x * 0.005, -PI, PI)
		orbit.y = clampf(orbit.y + event.relative.y * 0.005, -PI * 0.5 + 0.001, PI * 0.5 - 0.001)
		_update_camera()
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var origin := camera.project_ray_origin(event.position)
	var endpoint := origin + camera.project_ray_normal(event.position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Variant = hit.get("collider")
	if collider is Area3D and collider.has_meta("site_id"):
		select_site(str(collider.get_meta("site_id")))

func select_site(site_id: String) -> void:
	if landing_in_progress:
		return
	if _site_by_id(site_id).is_empty():
		push_warning("Unknown lunar landing site: %s" % site_id)
		return
	selected_site_id = site_id
	landing_in_progress = launch_outpost_on_selection
	for marker in get_tree().get_nodes_in_group("lunar_site_marker"):
		if marker is MeshInstance3D:
			var material := marker.material_override as StandardMaterial3D
			material.albedo_color = Color("ffd18a") if marker.get_meta("site_id", "") == site_id else Color("91cfff")
	site_selected.emit(site_id)
	if launch_outpost_on_selection:
		var session := get_node_or_null("/root/MissionSession")
		if session != null:
			session.set("selected_site_id", site_id)
		_begin_landing()

func _begin_landing() -> void:
	var coordinates: Dictionary = _site_by_id(selected_site_id).coordinates
	var target := _globe_position(float(coordinates.latitude_deg), float(coordinates.longitude_deg))
	var start_transform := camera.transform
	var start_size := camera.size
	var start_offset := camera.h_offset
	# Keep the existing screen-up direction, including when looking down at a pole.
	var normal := target.normalized()
	var up := camera.basis.y
	if absf(up.dot(normal)) > 0.98:
		up = camera.basis.x
	var destination := Transform3D(Basis.looking_at(-normal, up), target + normal * 20.0)
	for control in menu_layer.find_children("*", "Button", true, false):
		(control as Button).disabled = true
	var tween := create_tween()
	tween.tween_method(func(progress: float) -> void:
		# Finish the pan early so the deeper zoom stays centered on the site.
		var pan := smoothstep(0.0, 0.55, progress)
		camera.transform = start_transform.interpolate_with(destination, pan)
		camera.h_offset = lerpf(start_offset, 0.0, pan)
		var zoom := smoothstep(0.15, 1.0, progress)
		camera.size = exp(lerpf(log(start_size), log(0.065), zoom))
		for marker in get_tree().get_nodes_in_group("lunar_site_marker"):
			marker.scale = Vector3.ONE * maxf(0.001, 1.0 - smoothstep(0.3, 0.75, progress))
		for control in menu_layer.get_children():
			if control is Control:
				control.modulate.a = 1.0 - smoothstep(0.0, 0.3, progress)
	, 0.0, 1.0, 1.8)
	tween.tween_callback(_open_selected_outpost)

func _open_selected_outpost() -> void:
	var transition := preload("res://src/world/lunar_landing_blend.gd").new()
	get_tree().root.add_child(transition)
	transition.begin(self)


func _open_dashboard() -> void:
	if landing_in_progress:
		return
	var session := get_node_or_null("/root/MissionSession")
	if session != null:
		session.call("open_dashboard", scene_file_path)

func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050710")
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

func _add_map_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "SouthPoleMap"
	var mesh := SphereMesh.new()
	mesh.radius = MOON_RADIUS
	mesh.height = MOON_RADIUS * 2.0
	mesh.radial_segments = 256
	mesh.rings = 256
	surface.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/moon/globe.gdshader")
	material.set_shader_parameter("color_map", preload("res://Assets/moon/lroc_2025_4k.png"))
	material.set_shader_parameter("legacy_color_map", preload("res://Assets/moon/lroc_2019_4k.png"))
	material.set_shader_parameter("relief_map", preload("res://Assets/moon/lola_relief.png"))
	surface.material_override = material
	add_child(surface)
	# Occlude far-side pins when selecting through the globe.
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = MOON_RADIUS
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _load_site_markers() -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(SITES_PATH))
	if not (document is Dictionary and document.get("sites", []) is Array):
		push_error("Unable to read site records for lunar landing selection.")
		return
	for record in document.get("sites", []):
		if record is Dictionary:
			site_records.append(record)
			_add_site_marker(record)

func _add_site_marker(site: Dictionary) -> void:
	var site_id := str(site.get("site_id", ""))
	var coordinates: Dictionary = site.get("coordinates", {})
	if site_id.is_empty() or coordinates.is_empty():
		return
	var surface_position := _globe_position(float(coordinates.latitude_deg), float(coordinates.longitude_deg))
	var normal := surface_position.normalized()
	var marker := MeshInstance3D.new()
	marker.name = site_id
	marker.set_meta("site_id", site_id)
	marker.add_to_group("lunar_site_marker")
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.014
	mesh.height = PIN_HEIGHT
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("91cfff")
	marker.material_override = material
	marker.position = surface_position + normal * (PIN_HEIGHT * 0.5 - 0.002)
	marker.quaternion = Quaternion(Vector3.UP, normal)
	add_child(marker)
	var area := Area3D.new()
	area.name = site_id + "_ClickArea"
	area.set_meta("site_id", site_id)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.024
	collision.shape = shape
	collision.position = marker.position
	area.add_child(collision)
	add_child(area)

func _globe_position(latitude_deg: float, longitude_deg: float) -> Vector3:
	var latitude := deg_to_rad(latitude_deg)
	var longitude := deg_to_rad(longitude_deg)
	return MOON_RADIUS * Vector3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))

func _site_by_id(site_id: String) -> Dictionary:
	for site in site_records:
		if site.get("site_id", "") == site_id:
			return site
	return {}

func _add_camera() -> void:
	camera = Camera3D.new()
	camera.name = "SelectorCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	_update_camera()

func _update_camera() -> void:
	if polar_view:
		camera.size = polar_zoom_size
		camera.h_offset = -0.16 * camera.size / 0.95
		camera.position = Vector3(0.0, -30.0, 0.0)
		camera.look_at(Vector3(0.0, -MOON_RADIUS, 0.0), Vector3.FORWARD)
	else:
		camera.size = globe_zoom_size
		camera.h_offset = -5.0 * camera.size / 24.0
		camera.position = Vector3(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y)) * 30.0
		camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.force_update_transform()
	_update_zoom_controls()

func _toggle_polar_view() -> void:
	if landing_in_progress:
		return
	polar_view = not polar_view
	get_node("PolarGrid").visible = polar_view
	_update_camera()
	view_button.text = "RETURN TO MOON" if polar_view else "INSPECT SOUTH POLE"
	caption.text = "SOUTH POLE · Magnified coordinates\nGlobal map · limited polar detail" if polar_view else "GLOBAL MOON · LROC / LOLA\nRight-drag to orbit · Scroll to zoom\nClick a label on the Moon to land"
	_update_site_callouts()

func _add_menu() -> void:
	var layer := CanvasLayer.new()
	menu_layer = layer
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.14, 0.21, 0.3)
	background.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", background)
	layer.add_child(panel)
	_add_glass_backdrop(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)

	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "LUNAR LANDING SELECTOR"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	caption = Label.new()
	caption.text = "GLOBAL MOON · LROC / LOLA\nRight-drag to orbit · Scroll to zoom\nClick a label on the Moon to land"
	column.add_child(caption)
	var dashboard_button := Button.new()
	dashboard_button.text = "MISSION DASHBOARD  [I]"
	dashboard_button.pressed.connect(_open_dashboard)
	column.add_child(dashboard_button)
	view_button = Button.new()
	view_button.text = "INSPECT SOUTH POLE"
	view_button.pressed.connect(_toggle_polar_view)
	column.add_child(view_button)
	map_button = Button.new()
	map_button.text = "SURFACE: LROC 2025"
	map_button.pressed.connect(_toggle_surface_map)
	column.add_child(map_button)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	column.add_child(zoom_row)
	zoom_out_button = Button.new()
	zoom_out_button.text = "- Zoom out"
	zoom_out_button.pressed.connect(_zoom_by.bind(1.25))
	zoom_row.add_child(zoom_out_button)
	zoom_in_button = Button.new()
	zoom_in_button.text = "+ Zoom in"
	zoom_in_button.pressed.connect(_zoom_by.bind(0.8))
	zoom_row.add_child(zoom_in_button)
	zoom_reset_button = Button.new()
	zoom_reset_button.tooltip_text = "Reset zoom for this view"
	zoom_reset_button.pressed.connect(_reset_zoom)
	zoom_row.add_child(zoom_reset_button)
	_update_zoom_controls()
	# Landing controls follow geographic anchors on the globe, not the side menu.
	for site in site_records:
		var button := Button.new()
		button.name = str(site.site_id) + "_SurfaceLabel"
		var coordinates: Dictionary = site.coordinates
		button.text = str(site.name)
		button.tooltip_text = "%.4f°%s / %.4f°E · Click to land" % [ absf(float(coordinates.latitude_deg)), "S" if float(coordinates.latitude_deg) < 0 else "N", float(coordinates.longitude_deg)]
		button.add_theme_font_size_override("font_size", 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.22, 0.32, 0.25)
		style.border_color = Color(0.8, 0.91, 1.0, 0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.28, 0.48, 0.65, 0.45)
		button.add_theme_stylebox_override("hover", hover)
		button.pressed.connect(select_site.bind(str(site.site_id)))
		layer.add_child(button)
		_add_glass_backdrop(button)
		site_callouts.append({"site_id": site.site_id, "button": button})

func _add_glass_backdrop(control: Control) -> void:
	var glass := ColorRect.new()
	glass.name = "FrostedGlass"
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.show_behind_parent = true
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/moon/selector_glass.gdshader")
	glass.material = material
	control.add_child(glass, false, Node.INTERNAL_MODE_BACK)
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.resized.connect(func() -> void: material.set_shader_parameter("panel_size", control.size))
	material.set_shader_parameter("panel_size", control.size)

func _process(_delta: float) -> void:
	_update_site_callouts()

func _update_site_callouts() -> void:
	if camera == null:
		return
	var globe := get_node("SouthPoleMap") as MeshInstance3D
	for callout in site_callouts:
		var site := _site_by_id(str(callout.site_id))
		var coordinates: Dictionary = site.coordinates
		var local_anchor := _globe_position(float(coordinates.latitude_deg), float(coordinates.longitude_deg))
		var anchor := globe.to_global(local_anchor)
		# An orthographic camera sees only the hemisphere facing its viewing axis.
		var normal := (globe.global_basis * local_anchor.normalized()).normalized()
		var visible_on_globe := normal.dot(camera.global_basis.z) > 0.015
		callout.button.visible = visible_on_globe
		if not visible_on_globe:
			continue
		var projected := camera.unproject_position(anchor)
		var button := callout.button as Button
		button.size = button.get_combined_minimum_size()
		# Center the block on its geographic anchor through orbit, zoom and resize.
		button.position = projected - button.size * 0.5

func _add_polar_grid() -> void:
	var grid := MeshInstance3D.new()
	grid.name = "PolarGrid"
	grid.visible = false
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("34434c")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for latitude in [-89.0, -88.0]:
		for degree in range(360):
			mesh.surface_add_vertex(_globe_position(latitude, degree) * 1.0002)
			mesh.surface_add_vertex(_globe_position(latitude, degree + 1) * 1.0002)
	for longitude in range(0, 360, 45):
		for step in range(20):
			mesh.surface_add_vertex(_globe_position(-90.0 + step * 0.1, longitude) * 1.0002)
			mesh.surface_add_vertex(_globe_position(-90.0 + (step + 1) * 0.1, longitude) * 1.0002)
	mesh.surface_end()
	grid.mesh = mesh
	add_child(grid)

func _toggle_surface_map() -> void:
	if landing_in_progress:
		return
	use_legacy_map = not use_legacy_map
	var material := get_node("SouthPoleMap").material_override as ShaderMaterial
	material.set_shader_parameter("use_legacy_map", use_legacy_map)
	map_button.text = "SURFACE: LROC 2019" if use_legacy_map else "SURFACE: LROC 2025"


func _zoom_by(factor: float) -> void:
	if landing_in_progress:
		return
	if polar_view:
		polar_zoom_size = clampf(polar_zoom_size * factor, 0.5, 4.0)
	else:
		globe_zoom_size = clampf(globe_zoom_size * factor, 0.5, 36.0)
	_update_camera()
	_update_site_callouts()

func _reset_zoom() -> void:
	if landing_in_progress:
		return
	if polar_view:
		polar_zoom_size = 0.95
	else:
		globe_zoom_size = 24.0
	_update_camera()
	_update_site_callouts()

func _update_zoom_controls() -> void:
	if zoom_in_button == null:
		return
	zoom_in_button.disabled = camera.size <= 0.50001
	zoom_out_button.disabled = camera.size >= (4.0 if polar_view else 36.0) - 0.00001
	var default_size := 0.95 if polar_view else 24.0
	zoom_reset_button.text = "Reset %.0f%%" % (default_size / camera.size * 100.0)
