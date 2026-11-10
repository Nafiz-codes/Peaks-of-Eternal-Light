class_name LunarOutpost
extends Node3D

## First-pass 3D lunar outpost. It deliberately has no simulation calculations;
## Member 3 can bind its visuals to the authoritative MissionState contract.

const ASTRONAUT_SCENE := preload("res://Assets/animated_astronaut/source/Walking astronaut.glb")
const ROVER_SCENE := preload("res://Assets/curiosity_rover.glb")
const HABITAT_SCENE := preload("res://Assets/outpost/habitat.tscn")
const ASTRONAUT_HEIGHT := 1.7
const LunarAstronautScript := preload("res://src/world/lunar_astronaut.gd")

const LUNAR_REGOLITH := Color("5b5b63")
const HABITAT := Color("d4d8df")
const SOLAR := Color("203a72")
const STRUCTURE := Color("728096")
const TAG_FONT := preload("res://Assets/fonts/PublicSans-Variable.ttf")
# Requested visual adjustment: 25% closer, then another 30% closer (0.75 * 0.70).
const EARTH_DISTANCE_SCALE := 0.525
var maya_dialogue_active := false
var dialogue_speaker := ""
var site_record: Dictionary = {}
var feedback: Dictionary = {}
var solar_indicator: OmniLight3D
var event_beacon: MeshInstance3D
var feedback_tween: Tween
var overview := false
var camera_tween: Tween
var construction_view: Node3D
var skip_repairs_dialog: ConfirmationDialog
const Expedition = preload("res://src/simulation/rover_expedition.gd")


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
	var orbital_motion := preload("res://src/world/orbital_motion.gd").new()
	orbital_motion.name = "OrbitalMotion"
	add_child(orbital_motion)
	_add_terrain()
	_add_outpost()
	if session.outpost_pose.get("site_id", "") == str(session.selected_site_id):
		var player := get_node("Outpost/Astronaut")
		player.transform = session.outpost_pose.transform
		player.camera_yaw = session.outpost_pose.yaw
		player.camera_pitch = session.outpost_pose.pitch
		player.set_first_person(bool(session.outpost_pose.get("first_person", false)))
		player._sync_camera_rig()
	_add_site_readout()
	_add_feedback_nodes()
	_add_prop_collisions()
	construction_view = preload("res://src/world/construction_presentation.gd").new()
	construction_view.name = "ConstructionPresentation"
	add_child(construction_view)
	var fieldwork := preload("res://src/world/crew_fieldwork.gd").new()
	fieldwork.name = "CrewFieldwork"
	add_child(fieldwork)
	add_child(preload("res://src/ui/outpost_hud.gd").new())
	var lander_access := preload("res://src/world/lander_access.gd").new()
	lander_access.name = "LanderAccess"
	add_child(lander_access)
	var training := preload("res://src/world/rover_expedition_controller.gd").new()
	training.name = "RoverTraining"
	add_child(training)
	add_child(preload("res://src/world/easter_eggs.gd").new())
	add_child(preload("res://src/world/dust_storm.gd").new())
	add_child(preload("res://src/world/structure_repairs.gd").new())
	session.state_changed.connect(refresh_feedback)
	refresh_feedback()
	var solar := preload("res://src/world/solar_placement.gd").new()
	solar.name = "SolarPlacement"
	add_child(solar)
	add_child(preload("res://src/ui/mission_tracker.gd").new())
	if OS.is_debug_build():
		var free_camera := preload("res://src/world/developer_free_camera.gd").new()
		free_camera.name = "DeveloperFreeCamera"
		add_child(free_camera)


func _add_prop_collisions() -> void:
	# Simple hulls keep walking/camera collision predictable around imported art.
	for entry in [["RoverHull", Vector3(5.2, 0.65, -2.8), Vector3(3.0, 1.3, 3.0)]]:
		var body: PhysicsBody3D = preload("res://src/world/rover_drive.gd").new() if entry[0] == "RoverHull" else StaticBody3D.new()
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
	construction_view.sync_completed({} if state == null else state.built_structures, catalog.get("structures", []), session.building_placements, [] if state == null else state.construction_queue)
	_sync_rover_action(state, session.reduce_motion)
	if session.reduce_motion:
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
	for id in ["power_console", "water_recycler", "food_storage", "crew_briefing"]:
		_set_station_status(id)
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


func _sync_rover_action(_state: Variant, _reduced_motion: bool) -> void:
	get_node("RoverHull").sync_state()


# Readings live in the crew report; the tag only shows who it is and whether there is news.
func _set_station_status(id: String) -> void:
	var session := get_node("/root/MissionSession")
	var events: Array = [] if session.dashboard_simulator == null else session.dashboard_simulator.events
	var report := preload("res://src/ui/crew_report.gd").build(id, session.dashboard_state, events)
	get_node("Outpost/" + id + "/StatusLabel/UpdateMarker").visible = session.crew_read_reports.get(id, "") != report.signature


func _set_station_hint(station: Node, near: bool) -> void:
	# Rover repair shares these area handlers but has no crew name tag.
	var label := station.get_node_or_null("StatusLabel") as Label3D
	if label == null or not label.has_meta("station_title"): return
	label.text = str(label.get_meta("station_title")) + ("\nPress E" if near else "")
	var name_label := label.get_node_or_null("CrewName") as Label3D
	if name_label != null:
		name_label.position.y = 0.36 if near else 0.18


func toggle_overview() -> void:
	if get_node("Outpost/Astronaut").seated:
		return
	get_node("Outpost/Astronaut").set_first_person(false)
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
	# OrbitalMotion supplies one coherent, changing Sun/Earth state after lighting setup.
	sky.sky_material = starfield
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5b8d9")
	environment.ambient_light_energy = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LunarEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LowPolarSun"
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func _add_terrain() -> void:
	var ground := preload("res://src/world/outpost_terrain.gd").build(site_record)
	ground.set_meta("rover_safe_terrain", true)
	add_child(ground)
	ground.create_trimesh_collision()
	ground.get_child(0).name = "LunarSurfaceCollision"
	_add_terrain_boundary(ground.get_aabb())
	add_child(preload("res://src/world/outpost_terrain.gd").build_surroundings(site_record, ground.material_override))
	add_child(preload("res://src/world/rock_scatter.gd").build(ground, str(site_record.site_id)))

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
	_add_astronaut(outpost)
	_add_rover(outpost)
	_add_interaction_station(outpost, "power_console", "Energy console", Vector3(-5.5, 0.0, 3.2), SOLAR)
	_add_interaction_station(outpost, "water_recycler", "Dr. Alex Rivera\nScience", Vector3(0.8, 0.0, 3.0), Color("e8ae45"))
	_add_interaction_station(outpost, "food_storage", "Sam Okafor\nEngineering + medical", Vector3(0.0, 0.0, -4.0), Color("f58a28"))
	_add_interaction_station(outpost, "crew_briefing", "Dr. Maya Chen\nTraining + safety", Vector3(3.4, 0.0, 3.8), Color("36b7bd"))



func _add_habitat(parent: Node3D) -> void:
	var habitat := HABITAT_SCENE.instantiate() as Node3D
	if str(site_record.site_id) == "crater_rim_b":
		habitat.position = Vector3(-12.0, 0.0, -14.0)
	parent.add_child(habitat)
	# A low-complexity capsule hull avoids collision against the scanned 90k-triangle
	# shell. Entry is a fade transfer, so the collider need not reproduce the hatch.
	var hull := StaticBody3D.new()
	hull.name = "CapsuleHull"
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for ring in [Vector2(2.65, 0.0), Vector2(1.3, 2.85), Vector2(1.1, 3.73)]:
		for index in range(16):
			var angle := TAU * index / 16.0
			points.append(Vector3(cos(angle) * ring.x, ring.y, sin(angle) * ring.x))
	shape.points = points
	collision.shape = shape
	hull.add_child(collision)
	habitat.add_child(hull)


func _add_astronaut(parent: Node3D) -> void:
	var astronaut := LunarAstronautScript.new()
	astronaut.name = "Astronaut"
	astronaut.position = Vector3(3.4, 0.05, 6.5)
	astronaut.floor_snap_length = 0.25
	parent.add_child(astronaut)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = ASTRONAUT_HEIGHT
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
	# The astronaut's _ready ran before this dynamically built arm existed.
	# Exclude its own capsule here or the arm collapses into the body.
	spring_arm.add_excluded_object(astronaut.get_rid())
	var camera := Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = 70.0
	camera.far = 6000.0
	camera.current = true
	spring_arm.add_child(camera)
	var first_camera := Camera3D.new()
	first_camera.name = "FirstPersonCamera"
	first_camera.position = LunarAstronautScript.FIRST_PERSON_EYE - camera_pivot.position
	first_camera.fov = 90.0
	first_camera.near = 0.02
	first_camera.far = 6000.0
	camera_pivot.add_child(first_camera)
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
	var wheels := preload("res://src/world/rover_wheels.gd").new()
	wheels.name = "Wheels"
	rover.add_child(wheels)
	wheels.setup(model)

func _add_interaction_station(parent: Node3D, interaction_id: String, label_text: String, position_: Vector3, color: Color) -> void:
	var station := Node3D.new()
	station.name = interaction_id
	station.position = position_
	parent.add_child(station)
	if interaction_id != "power_console":
		preload("res://src/world/station_astronaut.gd").populate(station, ASTRONAUT_SCENE, color)
	else:
		var console := MeshInstance3D.new()
		console.name = "PowerTerminal"
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 1.0, 0.5)
		console.mesh = box
		console.position.y = 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		console.material_override = material
		station.add_child(console)
	# Face the arrival area so the crew greet the player rather than face away.
	station.look_at(parent.to_global(Vector3(3.4, 0.0, 6.5)), Vector3.UP)
	var label := Label3D.new()
	label.name = "StatusLabel"
	label.text = label_text
	label.set_meta("station_title", label_text)
	label.font = tag_font()
	label.font_size = 38
	label.pixel_size = 0.004
	label.outline_size = 8
	label.outline_modulate = Color(0.02, 0.03, 0.05, 0.85)
	label.line_spacing = -4
	label.modulate = Color("e8eef6")
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.position = Vector3(0.0, 2.15, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(label)
	var tag_lines := label_text.split("\n", false, 1)
	if tag_lines.size() == 2:
		var name_label := label.duplicate() as Label3D
		name_label.name = "CrewName"
		name_label.text = tag_lines[0]
		name_label.font = tag_font(800)
		name_label.position = Vector3(0.0, 0.18, 0.0)
		label.add_child(name_label)
		label.text = tag_lines[1]
		label.set_meta("station_title", tag_lines[1])
		label.font = tag_font(400)
	var marker := Label3D.new()
	marker.name = "UpdateMarker"
	marker.text = "!"
	marker.font = tag_font(800)
	marker.font_size = 96
	marker.pixel_size = 0.004
	marker.outline_size = 12
	marker.outline_modulate = Color(0.02, 0.03, 0.05, 0.85)
	marker.modulate = Color("ffb84d")
	marker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	marker.position = Vector3(0.0, 0.5, 0.0) # Clears three tag lines; hides with the tag.
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.visible = false
	label.add_child(marker)
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
	if interaction_id == "power_console":
		# Retain the reporting endpoint, but remove the temporary world prop/prompt.
		station.hide()
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
		return
	area.body_entered.connect(_on_interaction_area_entered.bind(area))
	area.body_exited.connect(_on_interaction_area_exited.bind(area))


func _on_interaction_area_entered(body: Node3D, area: Area3D) -> void:
	if body.get_script() == LunarAstronautScript:
		body.call("set_nearby_interactable", area)
		_set_station_hint(area.get_parent(), true)


func _on_interaction_area_exited(body: Node3D, area: Area3D) -> void:
	if body.get_script() == LunarAstronautScript:
		body.call("clear_nearby_interactable", area)
		_set_station_hint(area.get_parent(), false)


static func tag_font(weight := 600) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = TAG_FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _on_player_interaction(interaction_id: String) -> void:
	var session := get_node("/root/MissionSession")
	if maya_dialogue_active: return
	var introduction := ""
	if interaction_id.begins_with("repair:"):
		get_node("StructureRepairs").start(interaction_id.trim_prefix("repair:"))
		return
	# After the dust storm Maya reports the damage, then the lost astronaut.
	var expedition: Dictionary = get_node("RoverTraining").data
	var aftermath := Expedition.aftermath(expedition)
	if interaction_id == "crew_briefing":
		if not session.maya_intro_complete:
			introduction = "crew_briefing"
		elif aftermath == "briefing":
			introduction = "storm_damage"
		elif aftermath == "alert":
			introduction = "storm_lost_contact"
		elif aftermath == "repairs":
			_ask_skip_repairs()
			return
		elif session.crew_introductions.get("water_recycler", false) and session.crew_introductions.get("food_storage", false) and not session.crew_introductions.get("maya_closing", false):
			introduction = "maya_closing"
	elif interaction_id in ["water_recycler", "food_storage"] and not session.crew_introductions.get(interaction_id, false):
		introduction = interaction_id
	if not introduction.is_empty():
		var actor := get_node("Outpost/" + interaction_id) as Node3D
		if get_node("Outpost/Astronaut").global_position.distance_to(actor.global_position) > 2.5: return
		if introduction == "storm_damage":
			# Nothing to damage: go straight to the lost-contact report.
			if session.apply_storm_damage().is_empty(): introduction = "storm_lost_contact"
			else: expedition["aftermath"] = "repairs"
		maya_dialogue_active = true
		dialogue_speaker = interaction_id
		var fieldwork := get_node("CrewFieldwork")
		fieldwork._update_visual(interaction_id, false)
		var dialogue := preload("res://src/ui/maya_introduction.gd").new()
		dialogue.dialogue_id = introduction
		dialogue.finished.connect(func():
			if introduction == "crew_briefing":
				session.maya_intro_complete = true
				if not fieldwork.data.is_empty(): fieldwork.data.crew.crew_briefing.auto_attempted = true
			elif introduction == "storm_lost_contact":
				# Lifeline opens now; the rover controller moves Alex to his last known position.
				expedition["aftermath"] = "done"
				session.capture_sol_checkpoint()
			elif introduction != "storm_damage":
				session.crew_introductions[introduction] = true
			maya_dialogue_active = false
			dialogue_speaker = ""
			session.state_changed.emit())
		add_child(dialogue)
		return
	if interaction_id == "rover_repair":
		get_node("RoverHull").repair()
		return
	if interaction_id == "rover_operations":
		get_node("MissionHUD").open_operations("rover")
		return
	# Inspect authoritative readings; stations never modify resource values.
	get_node("MissionHUD").inspect_station(interaction_id)


## The Commander may leave the storm damage: Maya then moves on to the lost-contact report.
func _ask_skip_repairs() -> void:
	var player := get_node("Outpost/Astronaut")
	if skip_repairs_dialog == null:
		skip_repairs_dialog = ConfirmationDialog.new()
		skip_repairs_dialog.title = "Leave the storm damage?"
		skip_repairs_dialog.dialog_text = "Damaged structures keep working at well under half output until they are repaired. You can still repair them later."
		skip_repairs_dialog.dialog_autowrap = true
		skip_repairs_dialog.min_size = Vector2i(520, 200)
		skip_repairs_dialog.ok_button_text = "Leave them"
		skip_repairs_dialog.cancel_button_text = "Keep repairing"
		skip_repairs_dialog.exclusive = true
		skip_repairs_dialog.confirmed.connect(func():
			get_node("RoverTraining").data["aftermath"] = "alert"
			get_node("/root/MissionSession").capture_sol_checkpoint()
			get_node("/root/MissionSession").state_changed.emit())
		skip_repairs_dialog.visibility_changed.connect(func():
			player.ui_blocked = skip_repairs_dialog.visible
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if skip_repairs_dialog.visible else Input.MOUSE_MODE_CAPTURED))
		add_child(skip_repairs_dialog)
	if not player.ui_blocked: skip_repairs_dialog.popup_centered()

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
