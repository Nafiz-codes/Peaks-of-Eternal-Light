extends Node3D
## Shared camera-aimed placement for the solar panel and three crew stations.
var panel: Node3D
var solar_panel: Node3D
var selected_id := "solar_array"
var stations: Dictionary = {}
var default_homes: Dictionary = {}
var route_checked_at := 0
var route_transform := Transform3D.IDENTITY
var route_ok := false
var build_error_until := 0
const NASABuildings = preload("res://src/world/nasa_buildings.gd")
const Station = preload("res://src/world/crew_station.gd")
var player: Node3D
var session: Node
var build_menu: PanelContainer
var placed := false
var settling := false
var active := false
var valid := false
var yaw := 0.0
var label: Label
var hud: CanvasLayer
var material: StandardMaterial3D
var pose: RefCounted
var meshes: Array[MeshInstance3D] = []
var grid: GridContainer
var destroying := false
var target: Node3D
var highlight: StandardMaterial3D
var area_ring: MeshInstance3D
var pose_hold: SkeletonModifier3D
const UI = preload("res://src/ui/ui_style.gd")
const DESTROY_HINT := "DESTROY  ·  Aim at a structure  ·  Left click destroy  ·  B build menu  ·  C exit"
const MODELS := {
 "solar_array": preload("res://Assets/expedition/solar_panel.glb"),
 "maya_station": preload("res://Assets/stations/maya_station.tscn"),
 "alex_station": preload("res://Assets/stations/alex_station.tscn"),
 "sam_station": preload("res://Assets/stations/sam_station.tscn"),
 "habitat_module": preload("res://Assets/stations/hdu_1.glb"),
 "comms_relay": preload("res://Assets/structures/comms_relay.tscn"),
 "water_extractor": preload("res://Assets/structures/water_extractor.tscn"),
 "greenhouse": preload("res://Assets/structures/greenhouse.tscn"),
 "shielding_wall": preload("res://Assets/structures/radiation_shelter.tscn")
}
const PolarSolar = preload("res://src/simulation/polar_solar.gd")
const Rating = preload("res://src/ui/outpost_hover.gd")
## Panel rating from NASA values; sources in Resources/data_sources.json.
const SOLAR_IRRADIANCE_W_M2 := 1361.0 # nasa_gsfc_total_solar_irradiance (1 AU)
const CELL_EFFICIENCY := 0.30 # nasa_sst_soa_power_solar_cells, nominal multi-junction
const PANEL_AREA_M2 := 4.62 # 3.0 m × 1.54 m face of the fitted solar_panel.glb (game assumption)
const HOURS_PER_SOL := 24.0 # One modeled Earth day per sol, as in the mission simulator
## Full-sun energy per sol: 1361 × 4.62 × 0.30 × 24 / 1000 ≈ 45.3 kWh.
const PANEL_RATED_KWH_PER_SOL := SOLAR_IRRADIANCE_W_M2 * PANEL_AREA_M2 * CELL_EFFICIENCY * HOURS_PER_SOL / 1000.0
var output_card: PanelContainer
var output_lines: Dictionary = {}
var output_bars: Dictionary = {}
var preview_kwh := 0.0
var sun_samples: Array = []
var face_normal := Vector3(0.0, 0.7071, 0.7071) # Replaced by the model's measured cell normal in _ready.
const Orbit = preload("res://src/world/orbital_model.gd")
const SUN_SAMPLES_PER_SOL := 48 # Every 30 minutes
const BUILD_RADIUS_SCALE := 3.0
const MAX_REACH_M := 30.0 # Farthest aimed spot from the astronaut
## Shade is tested every 2 h of Sun positions from five points on the panel; the
## 30-minute samples in between share that result.
const SHADE_STRIDE := 4
const SHADE_POINTS := [Vector3(0, 1, 0), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]
var shade_checked_at := 0
var shade_transform := Transform3D()
var preview_exposure := 1.0

func _ready() -> void:
	session = get_node("/root/MissionSession")
	player = get_parent().get_node("Outpost/Astronaut")
	panel = Node3D.new()
	panel.name = "PlacedSolarPanel"
	solar_panel = panel
	add_child(panel)
	var model := (MODELS.solar_array as PackedScene).instantiate() as Node3D
	panel.add_child(model)
	preload("res://src/world/imported_asset_fit.gd").fit(model, 3.0)
	for node in panel.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
	# Use actual mesh vertices to put the feet at local y=0, not padded bounds.
	var lowest := INF
	for mesh in meshes:
		for vertex in mesh.mesh.get_faces():
			var point: Vector3 = panel.global_transform.affine_inverse() * mesh.global_transform * vertex
			lowest = minf(lowest, point.y)
	if is_finite(lowest): model.position.y -= lowest
	face_normal = _solar_face_normal()
	placed = session.solar_placement.has("transform")
	if placed:
		panel.transform = session.solar_placement.transform
		_add_collision()
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.0, 0.7, 1.0)
	if not placed:
		for mesh in meshes:
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hud = CanvasLayer.new()
	hud.layer = 60
	add_child(hud)
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 32
	label.offset_right = -32
	label.offset_top = -82
	label.offset_bottom = -22
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	hud.add_child(label)
	label.text = "B · Build"
	_build_output_card()
	panel.visible = placed
	build_menu = PanelContainer.new()
	build_menu.position = Vector2(32, 145)
	build_menu.add_theme_stylebox_override("panel", UI.style(Color("171c2b"), UI.BLUE))
	hud.add_child(build_menu)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var menu_body := UI.box()
	build_menu.add_child(menu_body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(665, 450)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_body.add_child(scroll)
	scroll.add_child(grid)
	menu_body.add_child(UI.label("Press C to delete structures", 15, UI.AMBER))
	build_menu.hide()
	highlight = StandardMaterial3D.new()
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.albedo_color = Color(1.0, 0.12, 0.08, 0.45)
	default_homes = get_parent().get_node("CrewFieldwork").homes.duplicate()
	for id in session.station_placements:
		var station := _new_station(id)
		station.transform = session.station_placements[id]
		for mesh in station.find_children("*", "MeshInstance3D", true, false):
			mesh.create_trimesh_collision()
		_apply_station_home(id, station.global_transform, true)

func _new_station(id: String) -> Node3D:
	var station := (MODELS[id] as PackedScene).instantiate() as Node3D
	station.set_meta("crew_station_id", id)
	add_child(station)
	stations[id] = station
	return station

func _select(id: String) -> void:
	if active: _cancel()
	if id == "solar_array" and placed or session.station_placements.has(id): return
	selected_id = id
	build_error_until = 0
	if NASABuildings.MODELS.has(id):
		if session.dashboard_state == null: return
		get_parent().construction_view.editing_id = id
		get_parent().refresh_feedback()
		panel = NASABuildings.make(id, false)
		add_child(panel)
	else:
		panel = solar_panel if id == "solar_array" else _new_station(id)
	meshes.clear()
	for mesh in panel.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mesh)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.hide()
	yaw = 0.0
	valid = false
	route_checked_at = 0
	shade_checked_at = 0
	_start()

func _footprint() -> Vector2:
	if selected_id == "solar_array": return Vector2(1.5, 1.5)
	if NASABuildings.MODELS.has(selected_id):
		var hull: Vector3 = panel.get_meta("hull_size")
		return Vector2(hull.x, hull.z) * 0.5 + Vector2(0.1, 0.1)
	return Station.footprint(selected_id)

func _clearance_height() -> float:
	if selected_id == "solar_array": return 1.5
	if NASABuildings.MODELS.has(selected_id): return panel.get_meta("hull_size").y
	return Station.clearance_height(selected_id)

func _half_extent() -> float:
	return _footprint().length() / sqrt(2.0)

func _station_access_is_clear(id: String, xform: Transform3D) -> bool:
	var dock := xform * Station.dock(id)
	var half := Station.footprint(id) + Vector2(0.6, 0.6)
	for other_id in session.station_placements:
		if other_id == id: continue
		var other: Node3D = stations[other_id]
		var other_dock: Vector3 = other.global_transform * Station.dock(other_id)
		if dock.distance_to(other_dock) < 1.5: return false
		# Reserve each owner's standing space even while that NPC is away working.
		var local := xform.affine_inverse() * other_dock
		if absf(local.x) < half.x and absf(local.z) < half.y: return false
	return true

func _display_name() -> String:
	if selected_id == "habitat_module": return "Habitat Extension"
	if selected_id == "comms_relay": return "Comms Relay"
	if selected_id == "water_extractor": return "Water Extractor"
	if selected_id == "greenhouse": return "Greenhouse Module"
	if selected_id == "shielding_wall": return "Radiation Shielding Habitat"
	return "Solar panel" if selected_id == "solar_array" else str(Station.DEFINITIONS[selected_id].name)

func _apply_station_home(id: String, xform: Transform3D, restoring := false) -> void:
	var crew := get_parent().get_node("CrewFieldwork")
	var npc: String = Station.DEFINITIONS[id].npc
	var dock := xform * Station.dock(id)
	crew.route_service.radius = maxf(crew.route_service.radius, Vector2(dock.x, dock.z).length() + 7.0)
	var hit: Dictionary = crew.route_service.ground(dock)
	if not hit.is_empty(): dock = hit.position
	crew.homes[npc] = crew.actors[npc].get_parent().to_local(dock)
	crew.station_homes[npc] = true
	crew.station_facings[npc] = atan2(xform.basis.z.x, xform.basis.z.z)
	crew.request_station_arrival(npc, restoring)


func _open_menu() -> void:
	# Rebuild when opening so newly placed structures leave the marked ground.
	if is_instance_valid(area_ring):
		remove_child(area_ring)
		area_ring.queue_free()
		area_ring = null
	_show_area(true)
	_refresh_menu()
	build_menu.show()
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_menu_and(action := Callable()) -> void:
	build_menu.hide()
	_show_area(false)
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if action.is_valid(): action.call()

## Rebuilt on open so costs, availability and the stock of materials are current.
func _refresh_menu() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var state: Variant = session.dashboard_state
	var catalog: Array = session.dashboard_simulator.construction.get("structures", []) if session.dashboard_simulator != null else (JSON.parse_string(FileAccess.get_file_as_string("res://Resources/construction.json")) as Dictionary).get("structures", [])
	catalog = catalog.duplicate()
	var station_index := 1
	for id in Station.DEFINITIONS:
		catalog.insert(station_index, {"structure_id": id, "name": Station.DEFINITIONS[id].name, "effect": "Place a work base for this crew member. Their existing duties remain available."})
		station_index += 1
	for structure in catalog:
		var id := str(structure.get("structure_id", ""))
		var cost: Dictionary = structure.get("build_cost", {})
		var materials := float(cost.get("materials", 0.0))
		var affordable: bool = state == null or state.materials >= materials
		var status := ""
		var available := false
		var cost_text := "Materials %d · Energy %d kWh" % [materials, int(cost.get("power", 0))]
		if id == "solar_array":
			# The first panel is free so the outpost can be powered straight away.
			available = not placed
			cost_text = "Free · first panel"
			status = "Placed" if placed else "Click to place"
		elif Station.DEFINITIONS.has(id):
			available = not session.station_placements.has(id)
			cost_text = "Free · one per NPC"
			status = "Placed" if not available else "Click to place"
		elif NASABuildings.MODELS.has(id):
			var started: bool = state != null and (state.built_structures.has(id) or state.construction_queue.any(func(job): return str(job.get("structure_id", "")) == id))
			available = state != null
			if started:
				status = "Relocate" if session.building_placements.has(id) else "Choose location"
				cost_text = "Built" if state.built_structures.has(id) else "Under construction · already paid"
			else:
				status = "Click to aim"
				if state == null:
					status = "Start the mission first"
				elif not placed:
					status = "Preview · place solar first"
				elif not affordable:
					status = "Preview · need materials"
				elif state.power_kwh < float(cost.get("power", 0)):
					status = "Preview · need power"
				elif not session.can_advance():
					status = "Preview · mission action pending"
		elif state != null and state.built_structures.has(id):
			status = "Built"
		elif state != null and state.construction_queue.any(func(job): return str(job.get("structure_id", "")) == id):
			status = "Under construction"
		elif not placed:
			status = "Place the solar panel first"
		elif state == null:
			status = "Start the mission first"
		else:
			available = affordable
			status = "Queue construction" if affordable else "Not enough materials"
		var card := Button.new()
		card.custom_minimum_size = Vector2(200, 214)
		card.disabled = not available
		card.tooltip_text = str(structure.get("effect", ""))
		for entry in [["normal", Color("1d2436")], ["hover", Color("273150")], ["pressed", Color("30364c")], ["disabled", Color("141927")]]:
			card.add_theme_stylebox_override(entry[0], UI.style(entry[1], UI.BLUE if entry[0] == "hover" else Color("3a4560")))
		# Grayed out when it cannot be built now, whatever the reason.
		card.modulate = Color.WHITE if available or status in ["Placed", "Built", "Under construction"] else Color(1, 1, 1, 0.42)
		grid.add_child(card)
		var body := UI.box()
		body.add_theme_constant_override("separation", 6)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(body)
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		var picture := Panel.new()
		picture.custom_minimum_size = Vector2(184, 104)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.add_theme_stylebox_override("panel", UI.style(Color("0d111c"), Color("2a3247")))
		body.add_child(picture)
		if MODELS.has(id): _add_preview(picture, MODELS[id], id)
		for line in [[str(structure.get("name", id)), 16, UI.TEXT], [cost_text, 14, UI.BLUE], [status, 13, UI.AMBER if available else UI.MUTED]]:
			var text := UI.label(line[0], line[1], line[2])
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(text)
		if MODELS.has(id):
			card.pressed.connect(_close_menu_and.bind(_select.bind(id)))
		else:
			card.pressed.connect(func():
				var result: Dictionary = session.queue_structure(id)
				label.text = "B · Build    " + (str(structure.get("name", id)) + " queued" if result.get("ok", false) else "Cannot build: " + str(result.get("error", "")).replace("_", " "))
				_refresh_menu())

## Studio shot of a real model; structures without one keep a blank frame.
func _add_preview(frame: Control, scene: PackedScene, id := "") -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	holder.add_child(view)
	var model := NASABuildings.make(id, false) if NASABuildings.MODELS.has(id) else scene.instantiate() as Node3D
	view.add_child(model)
	preload("res://src/world/imported_asset_fit.gd").fit(model, 3.0)
	var camera := Camera3D.new()
	var eye := Vector3(3.0, 2.2, 3.4)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0, 0.7, 0) - eye), eye)
	view.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	view.add_child(light)

func _start() -> void:
	active = true
	_show_area(true)
	# Camera view and pitch stay exactly as they were while walking.
	player.placing_solar = true
	if player.animation_player != null:
		player.animation_player.play("idle")
		player.animation_player.advance(0.0)
		player.animation_player.pause()
	pose = preload("res://src/world/astronaut_seated_pose.gd").new()
	var visual: Node3D = player.get_node("AnimatedAstronaut")
	pose.original_visual_transform = visual.transform
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		pose.skeleton = skeletons[0]
		var basis: Basis = (player.global_transform.affine_inverse() * pose.skeleton.global_transform).basis.inverse()
		pose._aim("R_Arm.", "R_Elbow.", basis * Vector3(0.1, 0.0, -0.5))
		pose._aim("R_Elbow.", "R_Wrist.", basis * Vector3(0.0, 0.0, -0.4))
		_hold_build_pose(pose.skeleton)

## Freeze everything above the legs in the build pose; walking then moves only the legs.
class BuildPoseHold extends SkeletonModifier3D:
	var held: Dictionary = {}
	func _process_modification() -> void:
		var skeleton := get_skeleton()
		for bone in held:
			skeleton.set_bone_pose_rotation(bone, held[bone])

func _hold_build_pose(skeleton: Skeleton3D) -> void:
	_release_build_pose()
	var hold := BuildPoseHold.new()
	hold.name = "BuildPoseHold"
	for bone in range(skeleton.get_bone_count()):
		var bone_name := str(skeleton.get_bone_name(bone))
		if not ["Hip", "Thigh", "Knee", "Ankle", "Toe"].any(func(part): return part in bone_name):
			hold.held[bone] = skeleton.get_bone_pose_rotation(bone)
	skeleton.add_child(hold)
	pose_hold = hold

func _release_build_pose() -> void:
	if is_instance_valid(pose_hold):
		pose_hold.get_parent().remove_child(pose_hold)
		pose_hold.queue_free()
	pose_hold = null

## Build area: centred on the lander, three times the distance to the purple departure circle.
func build_radius() -> float:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	var circle: Vector3 = get_parent().get_node("RoverTraining").departure.global_position
	return Vector2(circle.x - lander.x, circle.z - lander.z).length() * BUILD_RADIUS_SCALE

func in_build_area(point: Vector3) -> bool:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	return Vector2(point.x - lander.x, point.z - lander.z).length() <= build_radius()

## Reserve the marker disk plus the 3 m square placement footprint, even when hidden.
func overlaps_rover_circle(point: Vector3) -> bool:
	var controller := get_parent().get_node("RoverTraining")
	for circle in [controller.departure, controller.extraction]:
		var center: Vector3 = circle.global_position
		if Vector2(point.x - center.x, point.z - center.z).length() <= 4.5 + sqrt(2.0) * _half_extent():
			return true
	return false

func _show_area(visible_: bool) -> void:
	if area_ring == null and visible_:
		area_ring = _make_area_ring()
	if area_ring != null: area_ring.visible = visible_

## A faint terrain-conforming grid over clear, level construction ground.
## The selected building preview still checks its complete footprint and crew route.
func _make_area_ring() -> MeshInstance3D:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	var radius := build_radius()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var space := get_world_3d().direct_space_state
	var samples: Dictionary = {}
	var step := 3.0 # Keeps the ground scan near 4,500 rays for the wider area.
	var count := ceili(radius / step)
	var rover := get_parent().get_node("RoverTraining")
	for z in range(-count, count + 1):
		for x in range(-count, count + 1):
			var point := Vector3(lander.x + x * step, lander.y, lander.z + z * step)
			if not in_build_area(point): continue
			var reserved := false
			for circle in [rover.departure, rover.extraction]:
				if Vector2(point.x - circle.global_position.x, point.z - circle.global_position.z).length() < 6.0: reserved = true
			if reserved: continue
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 60, point - Vector3.UP * 60)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and hit.collider.name == "LunarSurfaceCollision" and hit.normal.y > 0.94:
				samples[Vector2i(x,z)] = hit.position + Vector3.UP * 0.025
	for z in range(-count, count):
		for x in range(-count, count):
			var keys := [Vector2i(x,z), Vector2i(x+1,z), Vector2i(x,z+1), Vector2i(x+1,z+1)]
			if not keys.all(func(key): return samples.has(key)): continue
			for index in [0, 1, 2, 1, 3, 2]:
				var point: Vector3 = samples[keys[index]]
				surface.set_uv(Vector2(point.x, point.z))
				surface.add_vertex(point)
	var ring := MeshInstance3D.new()
	ring.name = "BuildAreaRing"
	ring.mesh = surface.commit()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 vec2 cell = abs(fract(UV / 2.0 + 0.5) - 0.5) * 2.0;
 vec2 width = max(fwidth(UV), vec2(0.015));
 float line = 1.0 - smoothstep(0.025, 0.025 + max(width.x, width.y), min(cell.x, cell.y));
 ALBEDO = vec3(0.08, 0.60, 1.0);
 ALPHA = 0.015 + 0.07 * line;
}
"""
	var hologram := ShaderMaterial.new()
	hologram.shader = shader
	ring.material_override = hologram
	add_child(ring)
	ring.global_transform = Transform3D.IDENTITY
	return ring

func _aim_hit() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return {}
	var origin := camera.project_ray_origin(get_viewport().get_visible_rect().size * 0.5)
	var direction := camera.project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * (MAX_REACH_M + 20.0))
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

## kWh per sol the panel adds to the mission; the simulator uses this exact value.
static func panel_output_kwh(face_yield: float, exposure: float) -> float:
	return snappedf(PANEL_RATED_KWH_PER_SOL * clampf(face_yield, 0.0, 1.0) * clampf(exposure, 0.0, 1.0), 0.1)

## Share of this spot's mission sunlight (on the panel face, at its angle) that terrain and
## structures do not block. Every placement position and rotation is scored the same way.
func mission_exposure(xform: Transform3D) -> float:
	var normal := (xform.basis * face_normal).normalized()
	var space := get_world_3d().direct_space_state
	var samples := _sun_samples()
	var open := 0.0
	var total := 0.0
	for block in range(0, samples.size(), SHADE_STRIDE):
		var lit := -1.0
		for i in range(block, mini(block + SHADE_STRIDE, samples.size())):
			var direction: Vector3 = samples[i][0]
			var weight: float = samples[i][1] * maxf(0.0, normal.dot(direction))
			if weight <= 0.0: continue
			if lit < 0.0:
				lit = 0.0
				for point in SHADE_POINTS:
					var start: Vector3 = xform * point
					var query := PhysicsRayQueryParameters3D.create(start, start + direction * 200.0)
					query.exclude = [player.get_rid()]
					var hit := space.intersect_ray(query)
					# Only solid scenery shades; people, the rover and the invisible map edge do not.
					if hit.is_empty() or not hit.collider is StaticBody3D or str(hit.collider.name) == "TerrainBoundary":
						lit += 1.0 / SHADE_POINTS.size()
			open += weight * lit
			total += weight
	return 1.0 if total <= 0.0 else open / total

## Modeled Sun directions and strengths across the mission days the player sees,
## starting from the mission's bright start like the rendered sky.
func _sun_samples() -> Array:
	if sun_samples.is_empty():
		var site: Dictionary = get_parent().site_record
		var days: int = 7 if session.dashboard_state == null else session.dashboard_state.mission_length_sols
		var start := PolarSolar.bright_start(site)
		for day in range(days):
			for i in range(SUN_SAMPLES_PER_SOL):
				var observation := PolarSolar.observation_at(site, start + (day + (i + 0.5) / SUN_SAMPLES_PER_SOL) * Orbit.DAY)
				var strength := PolarSolar.visibility(site, observation) * pow(Orbit.AU_KM / float(observation.sun_distance_km), 2.0)
				sun_samples.append([observation.sun_direction, strength])
	return sun_samples

## Average share of full sunlight a Sun-tracking panel would catch (the best case).
func mean_site_yield() -> float:
	var samples := _sun_samples()
	var total := 0.0
	for sample in samples:
		total += sample[1]
	return total / maxf(1.0, samples.size())

## Same, for a fixed panel whose cells face `normal`: each Sun position counts by the
## cosine of its angle to the panel, so turning or tilting the panel changes output.
func facing_yield(normal: Vector3) -> float:
	var samples := _sun_samples()
	var total := 0.0
	for sample in samples:
		total += sample[1] * maxf(0.0, normal.dot(sample[0]))
	return total / maxf(1.0, samples.size())

## Normal of the largest upward-facing surface of the model (the cells), in panel space.
func _solar_face_normal() -> Vector3:
	var areas := {}
	for mesh in meshes:
		var to_panel := (panel.global_transform.affine_inverse() * mesh.global_transform).basis
		var faces := mesh.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var cross := (to_panel * (faces[i + 1] - faces[i])).cross(to_panel * (faces[i + 2] - faces[i]))
			if cross.length_squared() == 0.0: continue
			var key := (cross.normalized() * 10.0).round()
			areas[key] = float(areas.get(key, 0.0)) + cross.length()
	var best := Vector3.UP
	var best_area := 0.0
	for key in areas:
		if key.y > 0.0 and areas[key] > best_area:
			best = key
			best_area = areas[key]
	return best.normalized()

func _build_output_card() -> void:
	output_card = PanelContainer.new()
	output_card.name = "PlacementOutputCard"
	output_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_card.custom_minimum_size.x = 360 # Wrapped labels need a width to wrap against.
	output_card.add_theme_stylebox_override("panel", UI.style(Color("101a29"), UI.BLUE))
	hud.add_child(output_card)
	var body := UI.box()
	body.add_theme_constant_override("separation", 7)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_card.add_child(body)
	for key in ["title", "exposure", "exposure_bar", "facing", "facing_bar", "site", "site_bar", "energy", "water", "materials", "note"]:
		if key.ends_with("_bar"):
			var bar := ProgressBar.new()
			bar.step = 0.0
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(320, 8)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var background := StyleBoxFlat.new()
			background.bg_color = Color("29384b")
			background.set_corner_radius_all(4)
			bar.add_theme_stylebox_override("background", background)
			var fill := StyleBoxFlat.new()
			fill.set_corner_radius_all(4)
			bar.add_theme_stylebox_override("fill", fill)
			body.add_child(bar)
			output_bars[key] = bar
		else:
			var line := UI.label("", {"title": 20, "energy": 19, "note": 12}.get(key, 15), {"title": UI.BLUE, "note": UI.MUTED}.get(key, UI.TEXT))
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(line)
			output_lines[key] = line
	output_lines.title.text = "Solar panel · output here"
	output_lines.water.text = "Water  +0 L per sol"
	output_lines.materials.text = "Materials  +0 per sol"
	output_lines.note.text = "Fixed daily output for this spot: %.1f kWh full-sun rating (NASA 1361 W/m² sunlight × NASA 30%% cell efficiency × 4.62 m² × 24 h) × mission sunlight on the panel's face at its current angle × share not shaded by terrain or structures at this spot." % PANEL_RATED_KWH_PER_SOL
	output_card.hide()

func _set_bar(key: String, percent: float) -> Color:
	var color: Color = Rating.sunlight_rating(percent).color
	# Recolour the bar's own fill; no new style object every frame.
	(output_bars[key].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color
	output_bars[key].value = clampf(percent, 0.0, 100.0)
	return color

func _update_output_card() -> void:
	# Shade tracing is throttled while the aim and rotation hold still.
	var moved := shade_transform.origin.distance_to(panel.global_position) > 0.05 or not shade_transform.basis.is_equal_approx(panel.global_basis)
	if moved and Time.get_ticks_msec() - shade_checked_at > 150:
		shade_transform = panel.global_transform
		shade_checked_at = Time.get_ticks_msec()
		preview_exposure = mission_exposure(shade_transform)
	var exposure := preview_exposure
	var mean_yield := mean_site_yield()
	# Uses the panel's current yaw and the ground tilt under it.
	var facing := facing_yield((panel.global_basis * face_normal).normalized())
	preview_kwh = panel_output_kwh(facing, exposure)
	var exposure_color := _set_bar("exposure_bar", exposure * 100.0)
	output_lines.exposure.text = "Unshaded over the mission  %d%% · %s" % [roundi(exposure * 100.0), Rating.sunlight_rating(exposure * 100.0).label]
	output_lines.exposure.add_theme_color_override("font_color", exposure_color)
	var facing_share := 0.0 if mean_yield <= 0.0 else facing / mean_yield
	var facing_color := _set_bar("facing_bar", facing_share * 100.0)
	output_lines.facing.text = "Facing the Sun  %d%% of a Sun-tracking panel · Q / R to turn" % roundi(facing_share * 100.0)
	output_lines.facing.add_theme_color_override("font_color", facing_color)
	var site_color := _set_bar("site_bar", mean_yield * 100.0)
	output_lines.site.text = "Site sunlight (mission average)  %d%%" % roundi(mean_yield * 100.0)
	output_lines.site.add_theme_color_override("font_color", site_color)
	output_lines.energy.text = "Energy  +%.1f kWh per sol" % preview_kwh
	output_card.show()
	var bounds := get_viewport().get_visible_rect().size
	output_card.size = output_card.get_combined_minimum_size()
	output_card.position = Vector2(clampf(bounds.x * 0.5 + 60.0, 12.0, maxf(12.0, bounds.x - output_card.size.x - 12.0)), clampf(bounds.y * 0.5 - output_card.size.y * 0.5, 12.0, maxf(12.0, bounds.y - output_card.size.y - 12.0)))

func _physics_process(_delta: float) -> void:
	if not active and not destroying: return
	if player.seated or player.ui_blocked: return
	var hit := _aim_hit()
	if destroying:
		_set_target(null if hit.is_empty() else _structure_at(hit.collider))
		return
	valid = not hit.is_empty() and hit.collider.name == "LunarSurfaceCollision"
	panel.visible = valid
	if valid:
		valid = hit.normal.y > 0.94 and hit.position.distance_to(player.global_position) > 2.0 and hit.position.distance_to(player.global_position) < MAX_REACH_M and in_build_area(hit.position) and not overlaps_rover_circle(hit.position)
		var ground_basis := Basis(Quaternion(Vector3.UP, hit.normal)) * Basis(Vector3.UP, yaw)
		panel.global_transform = Transform3D(ground_basis, hit.position - hit.normal * 0.01)
		# All corners must rest on the same level surface; reject rocks and edges.
		var half := _footprint()
		for corner in [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, half.y)]:
			var point: Vector3 = panel.global_transform * corner
			if not in_build_area(point): valid = false
			var support_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 0.3)
			support_query.exclude = [player.get_rid()]
			var support := get_world_3d().direct_space_state.intersect_ray(support_query)
			if support.is_empty() or support.collider.name != "LunarSurfaceCollision" or absf((support.position - point).dot(hit.normal)) > 0.03 or support.normal.y < 0.94:
				valid = false
		var space := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(half.x * 2.0, _clearance_height(), half.y * 2.0)
		space.shape = box
		space.transform = Transform3D(panel.global_basis, hit.position + hit.normal * (box.size.y * 0.5 + 0.12))
		if selected_id == "solar_array": space.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty(): valid = false
	if valid and NASABuildings.MODELS.has(selected_id):
		# Preserve each crew member's reserved standing space at their outpost.
		for other_id in session.station_placements:
			var dock: Vector3 = stations[other_id].global_transform * Station.dock(other_id)
			var local := panel.global_transform.affine_inverse() * dock
			var half := _footprint() + Vector2(0.6, 0.6)
			if absf(local.x) < half.x and absf(local.z) < half.y: valid = false
	if valid and Station.DEFINITIONS.has(selected_id):
		valid = _station_access_is_clear(selected_id, panel.global_transform)
	if valid and Station.DEFINITIONS.has(selected_id):
		var crew := get_parent().get_node("CrewFieldwork")
		var npc: String = Station.DEFINITIONS[selected_id].npc
		var dock: Vector3 = panel.global_transform * Station.dock(selected_id)
		# Route searches are throttled while aiming at an unchanged spot.
		if route_checked_at == 0 or Time.get_ticks_msec() - route_checked_at > 200:
			route_transform = panel.global_transform
			route_checked_at = Time.get_ticks_msec()
			route_ok = not crew.station_route(npc, dock, panel.global_transform).is_empty()
		valid = route_ok and route_transform.origin.distance_to(panel.global_position) < 0.3 and route_transform.basis.is_equal_approx(panel.global_basis)
	if panel.visible and selected_id == "solar_array": _update_output_card()
	else: output_card.hide()
	material.albedo_color = Color(0.05, 0.75, 1.0, 0.4) if valid else Color(1.0, 0.15, 0.1, 0.4)
	if Time.get_ticks_msec() < build_error_until: return
	label.text = "PLACE " + _display_name().to_upper() + "  ·  Move mouse to aim  ·  Q / R rotate  ·  Left click confirm  ·  B build menu  ·  C destroy\n" + ("Ready to place" if valid else ("Outside the build area: stay inside the blue markings" if not hit.is_empty() and not in_build_area(hit.position) else ("Reserved rover mission area" if not hit.is_empty() and overlaps_rover_circle(hit.position) else "Aim at clear, level ground with a reachable crew access point")))

## Built outpost structures and the placed panel can be destroyed; previews cannot.
func _structure_at(collider: Object) -> Node3D:
	var node := collider as Node
	while node != null and node != get_parent():
		if node == solar_panel: return solar_panel if placed and not settling else null
		if node.has_meta("crew_station_id") and session.station_placements.has(str(node.get_meta("crew_station_id"))):
			return node if not settling else null
		if node.has_meta("structure_id") and str(node.name).begins_with("Completed_"): return node
		node = node.get_parent()
	return null

func _set_target(next: Node3D) -> void:
	if next == target: return
	for owner_ in [target, next]:
		if is_instance_valid(owner_):
			for mesh in owner_.find_children("*", "MeshInstance3D", true, false):
				mesh.material_overlay = highlight if owner_ == next else null
	target = next
	label.text = DESTROY_HINT + ("\nLeft click to destroy " + _target_name() if target != null else "\nAim at a built structure")

func _target_name() -> String:
	if target.has_meta("crew_station_id"): return str(Station.DEFINITIONS[str(target.get_meta("crew_station_id"))].name)
	return "the solar panel (free)" if target == solar_panel else str(target.get_meta("structure_id")).replace("_", " ") + " (cost refunded)"

func _start_destroy() -> void:
	destroying = true
	player.placing_solar = true
	label.text = DESTROY_HINT + "\nAim at a built structure"

func _stop_destroy() -> void:
	_set_target(null)
	destroying = false
	player.placing_solar = false
	label.text = "B · Build"

func _set_panel_output(kwh: float) -> void:
	if session.dashboard_state == null: return # Applied when the mission starts.
	session.dashboard_state.placed_panel_kwh_per_sol = kwh
	session.capture_sol_checkpoint()
	session.state_changed.emit()

func _destroy_target() -> void:
	var doomed := target
	if doomed == null: return
	_set_target(null)
	if doomed.has_meta("crew_station_id"):
		var id := str(doomed.get_meta("crew_station_id"))
		var npc: String = Station.DEFINITIONS[id].npc
		var crew := get_parent().get_node("CrewFieldwork")
		crew.homes[npc] = default_homes[npc]
		crew.station_homes.erase(npc)
		crew.station_facings.erase(npc)
		if not crew.data.is_empty(): crew.data.crew[npc].erase("station_relocation")
		if not crew.data.is_empty() and crew.data.crew[npc].phase == "Returning":
			crew.return_to_base(npc)
		session.station_placements.erase(id)
		stations.erase(id)
		doomed.queue_free()
		label.text = DESTROY_HINT + "\nStation removed · available in B menu"
		_reset_selection()
		return
	if doomed == solar_panel:
		_reset_selection()
		session.solar_placement = {}
		_set_panel_output(0.0)
		placed = false
		for mesh in meshes:
			for body in mesh.get_children():
				if body is StaticBody3D: body.queue_free()
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.hide()
		label.text = DESTROY_HINT + "\nSolar panel removed"
		return
	var result: Dictionary = session.demolish_structure(str(doomed.get_meta("structure_id")))
	if result.get("ok", false):
		label.text = DESTROY_HINT + "\nRefunded %d materials · %d kWh" % [result.materials_refund, result.power_refund]
	else:
		label.text = DESTROY_HINT + "\nCannot destroy: " + str(result.get("error", "")).replace("_", " ")

func _input(event: InputEvent) -> void:
	if get_tree().paused or player.seated or settling: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_B, KEY_C]:
		var building := active or destroying or build_menu.visible
		# Outside build mode C keeps its camera role.
		if event.keycode == KEY_C and not building: return
		if player.ui_blocked and not build_menu.visible: return
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_B:
			if build_menu.visible: _close_menu_and()
			else:
				if active: _cancel()
				if destroying: _stop_destroy()
				_open_menu()
		elif destroying:
			_stop_destroy()
		else:
			if active: _cancel()
			if build_menu.visible: _close_menu_and()
			_start_destroy()
		return
	if destroying:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			get_viewport().set_input_as_handled()
			_destroy_target()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_E, KEY_I, KEY_V, KEY_SPACE]:
			get_viewport().set_input_as_handled()
		return
	if not active or player.ui_blocked: return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_Q, KEY_R]:
			yaw += deg_to_rad(-15.0 if event.keycode == KEY_Q else 15.0)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_E, KEY_I, KEY_V, KEY_C, KEY_SPACE]:
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_viewport().set_input_as_handled()
		if valid: confirm()

func confirm() -> void:
	if not active or not valid or overlaps_rover_circle(panel.global_position): return
	if NASABuildings.MODELS.has(selected_id):
		_confirm_building()
		return
	if selected_id != "solar_array":
		if not _station_access_is_clear(selected_id, panel.global_transform):
			valid = false
			label.text = "Keep the other outposts' entrances and crew standing spaces clear."
			return
		var crew := get_parent().get_node("CrewFieldwork")
		var npc: String = Station.DEFINITIONS[selected_id].npc
		if crew.station_route(npc, panel.global_transform * Station.dock(selected_id), panel.global_transform).is_empty():
			valid = false
			label.text = "Crew access is blocked. Choose another spot or rotation."
			return
	active = false
	_show_area(false)
	output_card.hide()
	if selected_id == "solar_array":
		# Score the exact final transform; the card's shade check may be up to 150 ms old.
		preview_exposure = mission_exposure(panel.global_transform)
		preview_kwh = panel_output_kwh(facing_yield((panel.global_basis * face_normal).normalized()), preview_exposure)
		session.solar_placement = {"transform": panel.transform, "kwh_per_sol": preview_kwh}
		_set_panel_output(preview_kwh)
	else:
		session.station_placements[selected_id] = panel.transform
	for mesh in meshes:
		mesh.material_override = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_finish_build_pose()
	if selected_id == "solar_array": placed = true
	settling = true
	label.text = "Deploying " + _display_name() + "..."
	# Reserve solid ground space immediately so walking during the drop cannot
	# put the astronaut inside a collider that appears on landing.
	_add_collision()
	# Preserve the approved ground transform; only the presentation falls.
	var landing := panel.transform
	panel.position = landing.origin + landing.basis.y.normalized() * 0.12
	var drop := create_tween()
	drop.tween_property(panel, "position", landing.origin, 0.385).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	panel.transform = landing
	_dust_ring()
	settling = false
	label.text = _display_name() + " placed"
	if selected_id != "solar_array": _apply_station_home(selected_id, panel.global_transform)
	_reset_selection()

func _confirm_building() -> void:
	var state: Variant = session.dashboard_state
	var started: bool = state.built_structures.has(selected_id) or state.construction_queue.any(func(job): return str(job.structure_id) == selected_id)
	if not started:
		if not placed:
			label.text = "Place the solar panel before confirming this building."
			build_error_until = Time.get_ticks_msec() + 3500
			return
		var result: Dictionary = session.queue_structure(selected_id)
		if not result.get("ok", false):
			label.text = "Cannot build: " + str(result.get("error", "")).replace("_", " ")
			build_error_until = Time.get_ticks_msec() + 3500
			return
	session.building_placements[selected_id] = panel.global_transform
	# Like the solar panel, a confirmed building stands at once; this also finishes
	# sites left under construction by older saves.
	session.finish_structure(selected_id)
	session.capture_sol_checkpoint()
	var title := _display_name()
	_cancel()
	label.text = title + (" relocated" if started else " built")
	session.state_changed.emit()

func _dust_ring() -> void:
	var dust := Node3D.new()
	dust.name = "LandingDust"
	add_child(dust)
	dust.transform = panel.transform
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.65, 0.62, 0.57, 0.24), Color(0.65, 0.62, 0.57, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.albedo_texture = texture
	dust_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var animation := create_tween().set_parallel(true)
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.65, 0.25)
		puff.mesh = quad
		puff.material_override = dust_material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust.add_child(puff)
		var radius := 1.0 if selected_id == "solar_array" else 1.0 / maxf(absf(outward.x) / _footprint().x, absf(outward.z) / _footprint().y)
		puff.position = outward * radius + Vector3.UP * 0.08
		puff.scale = Vector3.ONE * 0.6
		animation.tween_property(puff, "position", outward * (radius + 0.7) + Vector3.UP * 0.14, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_property(puff, "scale", Vector3(1.3, 1.0, 1.0), 0.85)
		animation.tween_property(puff, "transparency", 1.0, 0.65).set_delay(0.2)
	animation.chain().tween_callback(dust.queue_free)

func _add_collision() -> void:
	for mesh in meshes:
		mesh.create_trimesh_collision()
		for child in mesh.get_children():
			if child is StaticBody3D:
				# Collision stays on the accepted ground transform while art drops.
				child.set_as_top_level(true)

func _cancel() -> void:
	var was_building := NASABuildings.MODELS.has(selected_id)
	active = false
	_show_area(false)
	output_card.hide()
	valid = false
	panel.hide()
	if selected_id != "solar_array":
		stations.erase(selected_id)
		panel.queue_free()
		_reset_selection()
	_finish_build_pose()
	label.text = "B · Build"
	if was_building:
		get_parent().construction_view.editing_id = ""
		get_parent().refresh_feedback()

func _finish_build_pose() -> void:
	player.placing_solar = false
	_release_build_pose()
	if pose != null:
		pose.restore(player.get_node("AnimatedAstronaut"))
		pose = null
	# Resume the current walk/idle intent, retaining velocity and camera direction.
	player._update_animation(player.moving)

func _reset_selection() -> void:
	selected_id = "solar_array"
	panel = solar_panel
	meshes.clear()
	for mesh in panel.find_children("*", "MeshInstance3D", true, false): meshes.append(mesh)
