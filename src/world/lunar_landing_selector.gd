class_name LunarLandingSelector
extends Node3D

## Clickable view of the four selected lunar south-pole locations. Marker
## positions use the sourced planetocentric latitude/east-positive longitude in
## sites.json and a local south-polar stereographic projection. This is a local
## selection map; it is not a replacement for a rendered LOLA elevation raster.

const SITES_PATH := "res://Resources/sites.json"
const POLAR_MAP_SCALE := 400.0

signal site_selected(site_id: String)

var site_records: Array[Dictionary] = []
var selected_site_id := ""
var launch_outpost_on_selection := true


func _ready() -> void:
	set_process_unhandled_input(true)
	_add_environment()
	_add_map_surface()
	_load_site_markers()
	_add_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
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
	if _site_by_id(site_id).is_empty():
		push_warning("Unknown lunar landing site: %s" % site_id)
		return
	selected_site_id = site_id
	for marker in get_tree().get_nodes_in_group("lunar_site_marker"):
		if marker is MeshInstance3D:
			var material := marker.material_override as StandardMaterial3D
			if material != null:
				material.emission_enabled = marker.get_meta("site_id", "") == site_id
	site_selected.emit(site_id)
	if launch_outpost_on_selection:
		var session := get_node_or_null("/root/MissionSession")
		if session != null:
			session.set("selected_site_id", site_id)
		call_deferred("_open_selected_outpost")


func _open_selected_outpost() -> void:
	get_tree().change_scene_to_file("res://scenes/lunar_outpost_3d.tscn")


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050710")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9caac5")
	environment.ambient_light_energy = 0.4
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LowPolarSun"
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 1.8
	sun.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
	add_child(sun)


func _add_map_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "SouthPoleMap"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 10.0
	mesh.bottom_radius = 10.0
	mesh.height = 0.35
	surface.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("53545d")
	material.roughness = 1.0
	surface.material_override = material
	surface.position.y = -0.2
	add_child(surface)
	var label := Label3D.new()
	label.text = "LUNAR SOUTH POLE / CLICK A VERIFIED SITE"
	label.font_size = 42
	label.outline_size = 8
	label.position = Vector3(0.0, 0.35, 8.5)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(label)


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
	var coordinates: Variant = site.get("coordinates", {})
	if site_id.is_empty() or not coordinates is Dictionary:
		return
	var latitude := float(coordinates.get("latitude_deg", 0.0))
	var longitude := float(coordinates.get("longitude_deg", 0.0))
	var position_ := _south_polar_position(latitude, longitude)
	var marker := MeshInstance3D.new()
	marker.name = site_id
	marker.set_meta("site_id", site_id)
	marker.add_to_group("lunar_site_marker")
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.24
	marker_mesh.bottom_radius = 0.42
	marker_mesh.height = 1.2
	marker.mesh = marker_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("91cfff")
	material.emission_enabled = false
	material.emission = Color("b7a2ff")
	marker.material_override = material
	marker.position = position_ + Vector3(0.0, 0.6, 0.0)
	add_child(marker)
	var label := Label3D.new()
	label.text = str(site.get("name", site_id)) + "\n%.4f°, %.4f°E" % [latitude, longitude]
	label.font_size = 28
	label.outline_size = 6
	label.position = marker.position + Vector3(0.0, 0.9, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var area := Area3D.new()
	area.name = site_id + "_ClickArea"
	area.set_meta("site_id", site_id)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collision.shape = shape
	collision.position = marker.position
	area.add_child(collision)
	add_child(area)


func _south_polar_position(latitude_deg: float, longitude_deg: float) -> Vector3:
	var latitude_rad := deg_to_rad(latitude_deg)
	var radial_distance := POLAR_MAP_SCALE * tan(PI * 0.25 + latitude_rad * 0.5)
	var longitude_rad := deg_to_rad(longitude_deg)
	return Vector3(sin(longitude_rad) * radial_distance, 0.0, -cos(longitude_rad) * radial_distance)


func _site_by_id(site_id: String) -> Dictionary:
	for site in site_records:
		if site.get("site_id", "") == site_id:
			return site
	return {}


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "SelectorCamera"
	camera.position = Vector3(0.0, 16.0, 12.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
