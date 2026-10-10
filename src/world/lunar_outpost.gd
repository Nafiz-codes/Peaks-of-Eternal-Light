class_name LunarOutpost
extends Node3D

## First-pass 3D lunar outpost. It deliberately has no simulation calculations;
## Member 3 can bind its visuals to the authoritative MissionState contract.

const ASTRONAUT_SCENE := preload("res://Assets/animated_astronaut/source/Walking astronaut.glb")
const ROVER_SCENE := preload("res://Assets/curiosity_rover.glb")
const HABITAT_SCENE := preload("res://Assets/outpost/habitat.tscn")
const SOLAR_SCENE := preload("res://Assets/outpost/solar_array.tscn")
const LunarAstronautScript := preload("res://src/world/lunar_astronaut.gd")

const LUNAR_REGOLITH := Color("5b5b63")
const HABITAT := Color("d4d8df")
const SOLAR := Color("203a72")
const STRUCTURE := Color("728096")
# Requested visual adjustment: 25% closer, then another 30% closer (0.75 * 0.70).
const EARTH_DISTANCE_SCALE := 0.525
var site_record: Dictionary = {}
var feedback: Dictionary = {}
var solar_indicator: OmniLight3D
var event_beacon: MeshInstance3D
var feedback_tween: Tween
var overview := false
var camera_tween: Tween
var construction_view: Node3D
var rover_view: Node


func _ready() -> void:
	name = "LunarOutpost"
	var session := get_node("/root/MissionSession")
	if str(session.selected_site_id).is_empty():
		session.select_landing_site("ridge_a")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.get("sites", []):
		if str(site.site_id) == str(session.selected_site_id):
			site_record = site
	_add_environment()
	_add_lighting()
	_add_terrain()
	_add_outpost()
	if session.outpost_pose.get("site_id", "") == str(session.selected_site_id):
		var player := get_node("Outpost/Astronaut")
		player.transform = session.outpost_pose.transform
		player.camera_yaw = session.outpost_pose.yaw
		player.camera_pitch = session.outpost_pose.pitch
		player._sync_camera_rig()
	_add_site_readout()
	_add_feedback_nodes()
	_add_prop_collisions()
	construction_view = preload("res://src/world/construction_presentation.gd").new()
	construction_view.name = "ConstructionPresentation"
	add_child(construction_view)
	rover_view = preload("res://src/world/rover_presentation.gd").new()
	rover_view.name = "RoverPresentation"
	add_child(rover_view)
	add_child(preload("res://src/ui/outpost_hud.gd").new())
	session.state_changed.connect(refresh_feedback)
	refresh_feedback()


func _add_prop_collisions() -> void:
	# Simple hulls keep walking/camera collision predictable around imported art.
	for entry in [["HabitatHull", Vector3(-1.2, 2.4, 0), Vector3(7.2, 4.5, 4.5)], ["AirlockHull", Vector3(2.8, 1.2, 0), Vector3(1.4, 2.4, 1.4)], ["RoverHull", Vector3(5.2, 0.65, -2.8), Vector3(3.0, 1.3, 3.0)], ["SolarHull", Vector3(-6, 0.5, -5.5), Vector3(6.5, 1.0, 2.6)]]:
		var body := StaticBody3D.new()
		body.name = entry[0]
		body.position = entry[1]
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = entry[2]
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


func _add_feedback_nodes() -> void:
	solar_indicator = OmniLight3D.new()
	solar_indicator.name = "SolarOutputIndicator"
	solar_indicator.position = Vector3(-6, 1.4, -5.5)
	solar_indicator.light_color = Color("91cfff")
	solar_indicator.omni_range = 7.0
	add_child(solar_indicator)
	event_beacon = MeshInstance3D.new()
	event_beacon.name = "DecisionBeacon"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	event_beacon.mesh = sphere
	event_beacon.material_override = _material(Color("ffd18a"), 0.4)
	event_beacon.position = Vector3(3.4, 2.1, 3.8)
	add_child(event_beacon)


func refresh_feedback() -> void:
	var session := get_node("/root/MissionSession")
	var state: Variant = session.dashboard_state
	var catalog: Dictionary = {} if session.dashboard_simulator == null else session.dashboard_simulator.construction
	construction_view.sync_completed({} if state == null else state.built_structures, catalog.get("structures", []))
	if session.reduce_motion:
		rover_view.finish_immediately(get_node("Outpost/Rover"), get_node("RoverHull"))
		if camera_tween != null and camera_tween.is_running():
			camera_tween.kill()
			var player := get_node("Outpost/Astronaut")
			player.get_node("CameraPivot/SpringArm").spring_length = 12.0 if overview else 4.8
			player.camera_pitch = -0.65 if overview else -0.22
			player._sync_camera_rig()
	feedback = {"solar_kwh": 0.0, "pending": 0, "water": "awaiting mission", "food": "awaiting mission", "oxygen": "awaiting mission", "active_events": []}
	if state != null:
		feedback.solar_kwh = state.power_generated_kwh
		feedback.pending = state.pending_events.size()
		feedback.water = state.life_support_status.get("water", "unavailable")
		feedback.food = state.life_support_status.get("food", "unavailable")
		feedback.oxygen = state.life_support_status.get("oxygen", "unavailable")
		feedback.active_events = state.active_events.duplicate(true)
	var energy_text := "Awaiting mission" if state == null else "%.2f kWh generated / %+.2f balance" % [state.power_generated_kwh, state.power_balance_kwh]
	_set_station_status("power_console", energy_text, state != null and state.consecutive_power_depleted_sols > 0)
	_set_station_status("water_recycler", "WATER / " + str(feedback.water).to_upper(), feedback.water in ["warning", "critical", "depleted"])
	_set_station_status("food_storage", "FOOD / " + str(feedback.food).to_upper(), feedback.food in ["warning", "critical", "depleted"])
	var event_ids := PackedStringArray()
	for event in feedback.active_events:
		event_ids.append(str(event.get("event_id", "")).replace("_", " "))
	_set_station_status("crew_briefing", "%d pending decisions / O2 %s" % [feedback.pending, feedback.oxygen] + ("\nActive: " + ", ".join(event_ids) if not event_ids.is_empty() else ""), feedback.pending > 0)
	if feedback_tween != null:
		feedback_tween.kill()
	event_beacon.visible = feedback.pending > 0
	event_beacon.scale = Vector3.ONE
	# Light intensity is an illustrative indicator; displayed kWh stays exact.
	var energy := clampf(float(feedback.solar_kwh) / 30.0, 0.0, 2.5)
	if session.reduce_motion:
		solar_indicator.light_energy = energy
	else:
		feedback_tween = create_tween()
		feedback_tween.tween_property(solar_indicator, "light_energy", energy, 0.5)
		if event_beacon.visible:
			feedback_tween.tween_property(event_beacon, "scale", Vector3.ONE * 1.35, 0.4)
			feedback_tween.tween_property(event_beacon, "scale", Vector3.ONE, 0.4)


func _set_station_status(id: String, text: String, alert: bool) -> void:
	var label := get_node("Outpost/" + id + "/StatusLabel") as Label3D
	label.text = str(label.get_meta("station_title")) + " [E]\n" + text
	label.modulate = Color("ffd18a") if alert else Color("d9e9ff")


func toggle_overview() -> void:
	overview = not overview
	if camera_tween != null:
		camera_tween.kill()
	var arm := get_node("Outpost/Astronaut/CameraPivot/SpringArm") as SpringArm3D
	var player := get_node("Outpost/Astronaut")
	var distance := 12.0 if overview else 4.8
	var pitch := -0.65 if overview else -0.22
	if get_node("/root/MissionSession").reduce_motion:
		arm.spring_length = distance
		player.camera_pitch = pitch
		player._sync_camera_rig()
	else:
		camera_tween = create_tween().set_parallel(true)
		camera_tween.tween_property(arm, "spring_length", distance, 0.6).set_trans(Tween.TRANS_SINE)
		camera_tween.tween_method(func(value: float):
			player.camera_pitch = value
			player._sync_camera_rig(), float(player.camera_pitch), pitch, 0.6)


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var starfield := ShaderMaterial.new()
	starfield.shader = preload("res://src/world/lunar_starfield.gdshader")
	starfield.set_shader_parameter("earth_surface", preload("res://Assets/earth/Earth_Diffuse_6K.jpg"))
	starfield.set_shader_parameter("earth_clouds", preload("res://Assets/earth/Earth_Clouds_6K.jpg"))
	starfield.set_shader_parameter("earth_night", preload("res://Assets/earth/Earth_Illumination_6K.jpg"))
	starfield.set_shader_parameter("earth_gloss", preload("res://Assets/earth/Earth_Glossiness_6K.jpg"))
	var ephemeris: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/earth_ephemeris.json"))
	var earth: Dictionary = ephemeris.sites[str(site_record.site_id)]
	var earth_direction := _sky_direction(float(earth.azimuth_deg), float(earth.elevation_deg))
	starfield.set_shader_parameter("earth_position_km", earth_direction * float(earth.observer_to_earth_center_km) * EARTH_DISTANCE_SCALE)
	starfield.set_shader_parameter("earth_radius_km", float(ephemeris.earth_equatorial_radius_km))
	starfield.set_shader_parameter("earth_sun_direction", _sky_direction(float(earth.sun_azimuth_deg), float(earth.sun_elevation_deg)))
	set_meta("earth_ephemeris_epoch_utc", ephemeris.epoch_utc)
	set_meta("earth_distance_km", earth.observer_to_earth_center_km)
	set_meta("earth_render_distance_km", float(earth.observer_to_earth_center_km) * EARTH_DISTANCE_SCALE)
	set_meta("earth_elevation_deg", earth.elevation_deg)
	sky.sky_material = starfield
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5b8d9")
	environment.ambient_light_energy = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LunarEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _sky_direction(azimuth_deg: float, elevation_deg: float) -> Vector3:
	# Godot local east/up/north: +X/+Y/-Z. Horizons azimuth runs clockwise from north.
	var azimuth := deg_to_rad(azimuth_deg)
	var elevation := deg_to_rad(elevation_deg)
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LowPolarSun"
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-32.0, -58.0, 0.0)
	add_child(sun)


func _add_terrain() -> void:
	var ground := preload("res://src/world/outpost_terrain.gd").build(site_record)
	add_child(ground)
	ground.create_trimesh_collision()
	ground.get_child(0).name = "LunarSurfaceCollision"
	_add_terrain_boundary(ground.get_aabb())
	add_child(preload("res://src/world/outpost_terrain.gd").build_surroundings(site_record, ground.material_override))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(str(site_record.get("site_id", "ridge_a")).hash())
	for index in range(32):
		var rock := MeshInstance3D.new()
		rock.name = "RegolithRock_%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.2, 0.7)
		mesh.height = mesh.radius * 0.75
		rock.mesh = mesh
		rock.material_override = _material(LUNAR_REGOLITH.darkened(rng.randf_range(0.0, 0.2)), 1.0)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(9.0, 11.5)
		rock.position = Vector3(cos(angle) * radius, mesh.height * 0.3, sin(angle) * radius)
		add_child(rock)

func _add_terrain_boundary(bounds: AABB) -> void:
	# Invisible perimeter walls follow the rendered surface, including its corners.
	# Extend above the highest terrain by more than the astronaut's jump height.
	var boundary := StaticBody3D.new()
	boundary.name = "TerrainBoundary"
	add_child(boundary)
	var center := bounds.get_center()
	var wall_height := bounds.size.y + 20.0
	for axis in [0, 2]:
		for edge in [bounds.position[axis], bounds.end[axis]]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(bounds.size.x + 1.0, wall_height, bounds.size.z + 1.0)
			shape.size[axis] = 1.0
			collision.shape = shape
			collision.position = center
			collision.position[axis] = edge
			boundary.add_child(collision)

func _add_outpost() -> void:
	var outpost := Node3D.new()
	outpost.name = "Outpost"
	add_child(outpost)

	_add_habitat(outpost)
	_add_solar_array(outpost)
	_add_astronaut(outpost)
	_add_rover(outpost)
	_add_interaction_station(outpost, "power_console", "ENERGY CONSOLE", Vector3(-5.5, 0.0, 3.2), SOLAR)
	_add_interaction_station(outpost, "water_recycler", "WATER RECYCLER", Vector3(0.8, 0.0, 3.0), Color("79c8df"))
	_add_interaction_station(outpost, "food_storage", "FOOD STORAGE", Vector3(0.0, 0.0, -4.0), Color("b5d878"))
	_add_interaction_station(outpost, "crew_briefing", "CREW BRIEFING", Vector3(3.4, 0.0, 3.8), Color("b7a2ff"))



func _add_habitat(parent: Node3D) -> void:
	parent.add_child(HABITAT_SCENE.instantiate())


func _add_solar_array(parent: Node3D) -> void:
	var array := SOLAR_SCENE.instantiate() as Node3D
	array.position = Vector3(-6.0, 0.0, -5.5)
	parent.add_child(array)

func _add_astronaut(parent: Node3D) -> void:
	var astronaut := LunarAstronautScript.new()
	astronaut.name = "Astronaut"
	astronaut.position = Vector3(3.4, 0.05, 6.5)
	astronaut.floor_snap_length = 0.25
	parent.add_child(astronaut)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	astronaut.add_child(collision)
	var visual := ASTRONAUT_SCENE.instantiate() as Node3D
	visual.name = "AnimatedAstronaut"
	## The imported skeleton's toe bones rest about 0.52 m below its scene origin.
	## Lift the visual root to put the idle boot soles on the collision-floor plane.
	visual.position.y = -0.04
	visual.rotation_degrees.y = 180.0
	astronaut.add_child(visual)
	var animation_players := visual.find_children("*", "AnimationPlayer", true, false)
	if not animation_players.is_empty():
		astronaut.call("set_animation_player", animation_players[0])
	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = 1.45
	astronaut.add_child(camera_pivot)
	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.spring_length = 4.8
	spring_arm.margin = 0.2
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.2
	spring_arm.shape = camera_shape
	camera_pivot.add_child(spring_arm)
	var camera := Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = 70.0
	camera.far = 6000.0
	camera.current = true
	spring_arm.add_child(camera)
	astronaut.interaction_requested.connect(_on_player_interaction)


func _add_rover(parent: Node3D) -> void:
	var rover := Node3D.new()
	rover.name = "Rover"
	rover.position = Vector3(5.2, 0.0, -2.8)
	rover.rotation_degrees.y = -50.0
	parent.add_child(rover)
	var model := ROVER_SCENE.instantiate() as Node3D
	model.name = "ImportedRover"
	rover.add_child(model)
	# Normalize the supplied model's authored units and pivot to a 3 m footprint.
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local_bounds: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	var extent := maxf(bounds.size.x, bounds.size.z)
	if not first and extent > 0.0:
		var factor := 3.0 / extent
		model.scale = Vector3.ONE * factor
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor

func _add_interaction_station(parent: Node3D, interaction_id: String, label_text: String, position_: Vector3, color: Color) -> void:
	var station := Node3D.new()
	station.name = interaction_id
	station.position = position_
	parent.add_child(station)
	var terminal := MeshInstance3D.new()
	var terminal_mesh := BoxMesh.new()
	terminal_mesh.size = Vector3(0.8, 1.25, 0.6)
	terminal.mesh = terminal_mesh
	terminal.material_override = _material(color, 0.45)
	terminal.position.y = 0.625
	station.add_child(terminal)
	var label := Label3D.new()
	label.name = "StatusLabel"
	label.text = label_text + "  [E]"
	label.set_meta("station_title", label_text)
	label.font_size = 28
	label.pixel_size = 0.008
	label.outline_size = 4
	label.modulate = Color("f1f3fa")
	label.position = Vector3(0.0, 1.7, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(label)
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.set_meta("interaction_id", interaction_id)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	shape.shape = sphere
	shape.position.y = 0.9
	area.add_child(shape)
	station.add_child(area)
	area.body_entered.connect(_on_interaction_area_entered.bind(area))
	area.body_exited.connect(_on_interaction_area_exited.bind(area))


func _on_interaction_area_entered(body: Node3D, area: Area3D) -> void:
	if body.get_script() == LunarAstronautScript:
		body.call("set_nearby_interactable", area)


func _on_interaction_area_exited(body: Node3D, area: Area3D) -> void:
	if body.get_script() == LunarAstronautScript:
		body.call("clear_nearby_interactable", area)


func _on_player_interaction(interaction_id: String) -> void:
	# Inspect authoritative readings; stations never modify resource values.
	get_node("MissionHUD").inspect_station(interaction_id)


func _add_site_readout() -> void:
	var site_id := "ridge_a"
	var session := get_node_or_null("/root/MissionSession")
	if session != null and not str(session.get("selected_site_id")).is_empty():
		site_id = str(session.get("selected_site_id"))
	var site_name := site_id.replace("_", " ").to_upper()
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in records.get("sites", []):
		if str(site.get("site_id", "")) == site_id:
			site_name = str(site.get("name", site_name))
	var label := Label3D.new()
	label.name = "SelectedSiteReadout"
	label.text = "LUNAR OUTPOST\n" + site_name
	label.font_size = 38
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color("91cfff")
	label.position = Vector3(-1.2, 6.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
