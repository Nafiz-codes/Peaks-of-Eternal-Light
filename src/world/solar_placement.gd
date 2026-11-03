extends Node3D
## One camera-aimed panel; confirmation retains the preview's exact transform.
var panel: Node3D
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
const MODELS := {"solar_array": preload("res://Assets/expedition/solar_panel.glb")}
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

func _ready() -> void:
	session = get_node("/root/MissionSession")
	player = get_parent().get_node("Outpost/Astronaut")
	panel = Node3D.new()
	panel.name = "PlacedSolarPanel"
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
	label.position = Vector2(32, 100)
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
	menu_body.add_child(grid)
	menu_body.add_child(UI.label("Press C to delete structures", 15, UI.AMBER))
	build_menu.hide()
	highlight = StandardMaterial3D.new()
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.albedo_color = Color(1.0, 0.12, 0.08, 0.45)

func _open_menu() -> void:
	_refresh_menu()
	build_menu.show()
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_menu_and(action := Callable()) -> void:
	build_menu.hide()
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
		if MODELS.has(id): _add_preview(picture, MODELS[id])
		for line in [[str(structure.get("name", id)), 16, UI.TEXT], [cost_text, 14, UI.BLUE], [status, 13, UI.AMBER if available else UI.MUTED]]:
			var text := UI.label(line[0], line[1], line[2])
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(text)
		if id == "solar_array":
			card.pressed.connect(_close_menu_and.bind(_start))
		else:
			card.pressed.connect(func():
				var result: Dictionary = session.queue_structure(id)
				label.text = "B · Build    " + (str(structure.get("name", id)) + " queued" if result.get("ok", false) else "Cannot build: " + str(result.get("error", "")).replace("_", " "))
				_refresh_menu())

## Studio shot of a real model; structures without one keep a blank frame.
func _add_preview(frame: Control, scene: PackedScene) -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	holder.add_child(view)
	var model := scene.instantiate() as Node3D
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

## Build area: centred on the lander, out to the purple expedition departure circle.
func build_radius() -> float:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	var circle: Vector3 = get_parent().get_node("RoverTraining").departure.global_position
	return Vector2(circle.x - lander.x, circle.z - lander.z).length()

func in_build_area(point: Vector3) -> bool:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	return Vector2(point.x - lander.x, point.z - lander.z).length() <= build_radius()

func _show_area(visible_: bool) -> void:
	if area_ring == null and visible_:
		area_ring = _make_area_ring()
	if area_ring != null: area_ring.visible = visible_

## A thin band laid on the sampled ground so it follows the terrain.
func _make_area_ring() -> MeshInstance3D:
	var lander: Vector3 = get_parent().get_node("Outpost/Habitat").global_position
	var radius := build_radius()
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var space := get_world_3d().direct_space_state
	var ground := func(x: float, z: float) -> Vector3:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, lander.y + 60.0, z), Vector3(x, lander.y - 60.0, z)))
		return Vector3(x, (hit.position.y if not hit.is_empty() else lander.y) + 0.08, z)
	for i in range(160):
		var points: Array[Vector3] = []
		for pair in [[i, radius - 0.15], [i + 1, radius - 0.15], [i, radius], [i + 1, radius]]:
			var angle := TAU * float(pair[0]) / 160.0
			points.append(ground.call(lander.x + cos(angle) * pair[1], lander.z + sin(angle) * pair[1]))
		for j in [0, 1, 2, 1, 3, 2]: band.add_vertex(points[j])
	var ring := MeshInstance3D.new()
	ring.name = "BuildAreaRing"
	ring.mesh = band.commit()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.05, 0.75, 1.0, 0.7)
	ring.material_override = ring_material
	add_child(ring)
	ring.global_transform = Transform3D.IDENTITY
	return ring

func _aim_hit() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return {}
	var origin := camera.project_ray_origin(get_viewport().get_visible_rect().size * 0.5)
	var direction := camera.project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 25.0)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

## kWh per sol the panel adds to the mission; the simulator uses this exact value.
static func panel_output_kwh(face_yield: float, exposure: float) -> float:
	return snappedf(PANEL_RATED_KWH_PER_SOL * clampf(face_yield, 0.0, 1.0) * clampf(exposure, 0.0, 1.0), 0.1)

## Share of a 3×3 grid over the panel with a clear line to the rendered Sun.
func sun_exposure(xform: Transform3D) -> float:
	var sun := get_parent().get_node_or_null("LowPolarSun") as DirectionalLight3D
	if sun == null: return 0.0
	var toward_sun := sun.global_basis.z.normalized()
	if toward_sun.y <= 0.0: return 0.0
	var space := get_world_3d().direct_space_state
	var lit := 0
	for x in [-1.0, 0.0, 1.0]:
		for z in [-1.0, 0.0, 1.0]:
			var start: Vector3 = xform * Vector3(x, 1.0, z)
			var query := PhysicsRayQueryParameters3D.create(start, start + toward_sun * 200.0)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			# Only solid scenery shades; people, the rover and the invisible map edge do not.
			if hit.is_empty() or not hit.collider is StaticBody3D or str(hit.collider.name) == "TerrainBoundary":
				lit += 1
	return lit / 9.0

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
	output_lines.note.text = "Fixed daily output for this spot: %.1f kWh full-sun rating (NASA 1361 W/m² sunlight × NASA 30%% cell efficiency × 4.62 m² × 24 h) × mission sunlight on the panel's face at its current angle × panel in direct sun." % PANEL_RATED_KWH_PER_SOL
	output_card.hide()

func _set_bar(key: String, percent: float) -> Color:
	var color: Color = Rating.sunlight_rating(percent).color
	# Recolour the bar's own fill; no new style object every frame.
	(output_bars[key].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color
	output_bars[key].value = clampf(percent, 0.0, 100.0)
	return color

func _update_output_card() -> void:
	var exposure := sun_exposure(panel.global_transform)
	var mean_yield := mean_site_yield()
	# Uses the panel's current yaw and the ground tilt under it.
	var facing := facing_yield((panel.global_basis * face_normal).normalized())
	preview_kwh = panel_output_kwh(facing, exposure)
	var exposure_color := _set_bar("exposure_bar", exposure * 100.0)
	output_lines.exposure.text = "Panel in direct sun  %d%% · %s" % [roundi(exposure * 100.0), Rating.sunlight_rating(exposure * 100.0).label]
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
		valid = hit.normal.y > 0.94 and hit.position.distance_to(player.global_position) > 2.0 and hit.position.distance_to(player.global_position) < 15.0 and in_build_area(hit.position)
		var ground_basis := Basis(Quaternion(Vector3.UP, hit.normal)) * Basis(Vector3.UP, yaw)
		panel.global_transform = Transform3D(ground_basis, hit.position - hit.normal * 0.01)
		# All corners must rest on the same level surface; reject rocks and edges.
		for corner in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			var point: Vector3 = panel.global_transform * corner
			var support_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 0.3)
			support_query.exclude = [player.get_rid()]
			var support := get_world_3d().direct_space_state.intersect_ray(support_query)
			if support.is_empty() or support.collider.name != "LunarSurfaceCollision" or absf((support.position - point).dot(hit.normal)) > 0.03 or support.normal.y < 0.94:
				valid = false
		var space := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 1.5, 3.0)
		space.shape = box
		space.transform = Transform3D(panel.global_basis, hit.position + Vector3.UP * 0.9)
		space.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty(): valid = false
	if panel.visible: _update_output_card()
	else: output_card.hide()
	material.albedo_color = Color(0.05, 0.75, 1.0, 0.4) if valid else Color(1.0, 0.15, 0.1, 0.4)
	label.text = "PLACE SOLAR PANEL  ·  Move mouse to aim  ·  Q / R rotate  ·  Left click confirm  ·  B build menu  ·  C destroy\n" + ("Ready to place" if valid else ("Outside the build area: stay inside the blue ring" if not hit.is_empty() and not in_build_area(hit.position) else "Aim at nearby level ground"))

## Built outpost structures and the placed panel can be destroyed; previews cannot.
func _structure_at(collider: Object) -> Node3D:
	var node := collider as Node
	while node != null and node != get_parent():
		if node == panel: return panel if placed and not settling else null
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
	return "the solar panel (free)" if target == panel else str(target.get_meta("structure_id")).replace("_", " ") + " (cost refunded)"

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
	if doomed == panel:
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
	if not active or not valid: return
	active = false
	_show_area(false)
	output_card.hide()
	# preview_kwh was measured at this exact transform on the last physics frame.
	session.solar_placement = {"transform": panel.transform, "kwh_per_sol": preview_kwh}
	_set_panel_output(preview_kwh)
	for mesh in meshes:
		mesh.material_override = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	player.placing_solar = false
	_release_build_pose()
	pose.restore(player.get_node("AnimatedAstronaut"))
	if player.animation_player != null: player.animation_player.play("idle")
	placed = true
	settling = true
	label.text = "Deploying solar panel..."
	# Preserve the approved ground transform; only the presentation falls.
	var landing := panel.transform
	panel.position = landing.origin + landing.basis.y.normalized() * 0.12
	var drop := create_tween()
	drop.tween_property(panel, "position", landing.origin, 0.385).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	panel.transform = landing
	_add_collision()
	_dust_ring()
	settling = false
	label.text = "Solar panel placed"

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
		puff.position = outward * 1.0 + Vector3.UP * 0.08
		puff.scale = Vector3.ONE * 0.6
		animation.tween_property(puff, "position", outward * 1.7 + Vector3.UP * 0.14, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_property(puff, "scale", Vector3(1.3, 1.0, 1.0), 0.85)
		animation.tween_property(puff, "transparency", 1.0, 0.65).set_delay(0.2)
	animation.chain().tween_callback(dust.queue_free)

func _add_collision() -> void:
	for mesh in meshes:
		mesh.create_trimesh_collision()

func _cancel() -> void:
	active = false
	_show_area(false)
	output_card.hide()
	valid = false
	panel.hide()
	player.placing_solar = false
	_release_build_pose()
	pose.restore(player.get_node("AnimatedAstronaut"))
	if player.animation_player != null: player.animation_player.play("idle")
	label.text = "B · Build"
