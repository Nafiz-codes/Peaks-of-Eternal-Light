class_name LunarOutpost
extends Node3D

## First-pass 3D lunar outpost. It deliberately has no simulation calculations;
## Member 3 can bind its visuals to the authoritative MissionState contract.

const ASTRONAUT_SCENE := preload("res://Assets/animated_astronaut/source/Walking astronaut.glb")
const LunarAstronautScript := preload("res://src/world/lunar_astronaut.gd")

const LUNAR_REGOLITH := Color("5b5b63")
const HABITAT := Color("d4d8df")
const SOLAR := Color("203a72")
const STRUCTURE := Color("728096")


func _ready() -> void:
	name = "LunarOutpost"
	_add_environment()
	_add_lighting()
	_add_terrain()
	_add_outpost()
	_add_site_readout()


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050710")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5b8d9")
	environment.ambient_light_energy = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LunarEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LowPolarSun"
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-32.0, -58.0, 0.0)
	add_child(sun)


func _add_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "LunarRegolith"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60.0, 60.0)
	ground.mesh = ground_mesh
	ground.material_override = _material(LUNAR_REGOLITH, 1.0)
	add_child(ground)
	var ground_body := StaticBody3D.new()
	ground_body.name = "LunarSurfaceCollision"
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(60.0, 0.4, 60.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.2
	ground_body.add_child(ground_collision)
	add_child(ground_body)

	for index in range(16):
		var rock := MeshInstance3D.new()
		rock.name = "RegolithRock_%02d" % index
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.35 + float(index % 3) * 0.18
		rock_mesh.height = 0.28 + float(index % 4) * 0.12
		rock.mesh = rock_mesh
		rock.material_override = _material(LUNAR_REGOLITH.darkened(0.08 + float(index % 3) * 0.03), 1.0)
		rock.position = Vector3(float((index * 11) % 23) - 11.0, rock_mesh.height * 0.35, float((index * 7) % 19) - 9.0)
		add_child(rock)


func _add_outpost() -> void:
	var outpost := Node3D.new()
	outpost.name = "Outpost"
	add_child(outpost)

	_add_habitat(outpost)
	_add_solar_array(outpost)
	_add_astronaut(outpost)
	_add_rover(outpost)
	_add_interaction_station(outpost, "power_console", "ENERGY CONSOLE", Vector3(-4.0, 0.0, 2.5), SOLAR)
	_add_interaction_station(outpost, "water_recycler", "WATER RECYCLER", Vector3(0.8, 0.0, 3.0), Color("79c8df"))
	_add_interaction_station(outpost, "food_storage", "FOOD STORAGE", Vector3(0.0, 0.0, -3.0), Color("b5d878"))
	_add_interaction_station(outpost, "crew_briefing", "CREW BRIEFING", Vector3(3.4, 0.0, 3.8), Color("b7a2ff"))
	_add_controls_hint()


func _add_controls_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ControlsHint"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14.0, 14.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var hint := Label.new()
	hint.text = "WASD · MOVE    MOUSE · LOOK\nSPACE · JUMP    E · INTERACT\nI · MISSION DASHBOARD"
	hint.add_theme_font_size_override("font_size", 14)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)


func _add_habitat(parent: Node3D) -> void:
	var habitat := MeshInstance3D.new()
	habitat.name = "HabitatModule"
	var habitat_mesh := CylinderMesh.new()
	habitat_mesh.top_radius = 2.4
	habitat_mesh.bottom_radius = 2.4
	habitat_mesh.height = 7.2
	habitat.mesh = habitat_mesh
	habitat.material_override = _material(HABITAT, 0.45)
	habitat.rotation_degrees.z = 90.0
	habitat.position = Vector3(-1.2, 2.4, 0.0)
	parent.add_child(habitat)

	var airlock := MeshInstance3D.new()
	airlock.name = "HabitatAirlock"
	var airlock_mesh := CylinderMesh.new()
	airlock_mesh.top_radius = 0.7
	airlock_mesh.bottom_radius = 0.7
	airlock_mesh.height = 2.4
	airlock.mesh = airlock_mesh
	airlock.material_override = _material(STRUCTURE, 0.65)
	airlock.position = Vector3(2.8, 1.2, 0.0)
	parent.add_child(airlock)


func _add_solar_array(parent: Node3D) -> void:
	var array := Node3D.new()
	array.name = "SolarArray"
	array.position = Vector3(-2.5, 0.0, -5.0)
	array.rotation_degrees.x = -17.0
	parent.add_child(array)
	for row in range(2):
		for column in range(4):
			var panel := MeshInstance3D.new()
			panel.name = "Panel_%d_%d" % [row, column]
			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(1.5, 0.08, 1.1)
			panel.mesh = panel_mesh
			panel.material_override = _material(SOLAR, 0.35)
			panel.position = Vector3((float(column) - 1.5) * 1.62, 0.85, (float(row) - 0.5) * 1.2)
			array.add_child(panel)


func _add_astronaut(parent: Node3D) -> void:
	var astronaut := LunarAstronautScript.new()
	astronaut.name = "Astronaut"
	astronaut.position = Vector3(3.4, 0.05, 2.3)
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
	camera.current = true
	spring_arm.add_child(camera)
	astronaut.interaction_requested.connect(_on_player_interaction)


func _add_rover(parent: Node3D) -> void:
	## The supplied rover GLB is retained in Assets, but its imported texture cache
	## is unavailable in this checkout. Keep the scene runnable with this marker
	## until Godot reimports that user asset in a normal editor session.
	var rover := Node3D.new()
	rover.name = "Rover"
	rover.position = Vector3(5.2, 0.0, -2.8)
	rover.rotation_degrees.y = -50.0
	parent.add_child(rover)
	var chassis := MeshInstance3D.new()
	chassis.name = "PlaceholderChassis"
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(2.2, 0.55, 1.4)
	chassis.mesh = chassis_mesh
	chassis.material_override = _material(STRUCTURE, 0.55)
	chassis.position.y = 0.72
	rover.add_child(chassis)
	for side in [-1.0, 1.0]:
		for axle in [-0.72, 0.72]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%s" % [side, axle]
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.32
			wheel_mesh.bottom_radius = 0.32
			wheel_mesh.height = 0.24
			wheel.mesh = wheel_mesh
			wheel.material_override = _material(Color("282c36"), 1.0)
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(axle, 0.34, side * 0.72)
			rover.add_child(wheel)


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
	label.text = label_text + "  [E]"
	label.font_size = 36
	label.outline_size = 8
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
	## This is intentionally a presentation event for now. Day 10 maps these IDs
	## to Member 1's authoritative simulation actions and results.
	print("Lunar interaction requested: %s" % interaction_id)


func _add_site_readout() -> void:
	var site_id := "ridge_a"
	var session := get_node_or_null("/root/MissionSession")
	if session != null and not str(session.get("selected_site_id")).is_empty():
		site_id = str(session.get("selected_site_id"))
	var site_name := site_id.replace("_", " ").to_upper()
	var label := Label3D.new()
	label.name = "SelectedSiteReadout"
	label.text = "SELECTED LUNAR SITE / " + site_name
	label.font_size = 38
	label.outline_size = 8
	label.modulate = Color("91cfff")
	label.position = Vector3(-6.0, 5.2, -2.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
