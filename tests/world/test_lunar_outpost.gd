extends SceneTree

const OUTPOST_SCENE := preload("res://scenes/lunar_outpost_3d.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var outpost := OUTPOST_SCENE.instantiate()
	root.add_child(outpost)
	await process_frame
	for _frame in range(45):
		await physics_frame
	_assert(outpost.get_node_or_null("LunarEnvironment") != null, "The 3D scene includes a world environment.")
	var ephemeris: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/earth_ephemeris.json"))
	var earth: Dictionary = ephemeris.sites.ridge_a
	var sky_material: ShaderMaterial = outpost.get_node("LunarEnvironment").environment.sky.sky_material
	var earth_position: Vector3 = sky_material.get_shader_parameter("earth_position_km")
	_assert(absf(earth_position.length() - float(earth.observer_to_earth_center_km) * 0.525) < 0.1, "Earth renders at 52.5% of the NASA surface-observer distance.")
	_assert(absf(rad_to_deg(asin(earth_position.normalized().y)) - float(earth.elevation_deg)) < 0.001, "Earth uses NASA's elevation above the local horizon.")
	for site_id in ephemeris.sites:
		var site: Dictionary = ephemeris.sites[site_id]
		var diameter := rad_to_deg(2.0 * asin(float(ephemeris.earth_equatorial_radius_km) / float(site.observer_to_earth_center_km)))
		_assert(absf(diameter - float(site.angular_diameter_deg)) < 0.0002, "Physical sphere diameter agrees with Horizons for " + str(site_id))
	_assert(float(ephemeris.sites.plateau_d.elevation_deg) < -float(ephemeris.sites.plateau_d.angular_diameter_deg), "Earth is fully below the horizon at the far-side site.")
	_assert(outpost.get_node_or_null("LowPolarSun") != null, "The 3D scene includes lunar lighting.")
	_assert(outpost.get_node_or_null("LunarRegolith") != null, "The 3D scene includes terrain.")
	_assert(outpost.get_node_or_null("Outpost/Astronaut/AnimatedAstronaut") != null, "The animated astronaut is placed in the outpost.")
	var astronaut: CharacterBody3D = outpost.get_node("Outpost/Astronaut")
	_assert(astronaut.global_position.y >= -0.02, "The astronaut collision capsule settles on the lunar surface instead of below it.")
	var visual_root: Node3D = astronaut.get_node("AnimatedAstronaut")
	var animation_players := astronaut.get_node("AnimatedAstronaut").find_children("*", "AnimationPlayer", true, false)
	_assert(not animation_players.is_empty(), "The astronaut scene exposes its animation player.")
	var animation_player := animation_players[0] as AnimationPlayer
	_assert(animation_player.has_animation("moon_walk") and animation_player.has_animation("idle"), "The astronaut has lunar walking and idle animations.")
	_assert(animation_player.current_animation == "idle", "The astronaut starts in its idle animation.")
	astronaut.call("_update_animation", true)
	_assert(animation_player.current_animation == "moon_walk", "Walking switches the astronaut to its moon-walk animation.")
	astronaut.call("_update_animation", false)
	_assert(animation_player.current_animation == "idle", "Stopping switches the astronaut back to idle.")
	_assert(is_equal_approx(visual_root.position.y, -0.04), "The astronaut model root is aligned from the imported skeleton's foot pose.")
	var lowest_foot_bone_y := INF
	for skeleton_node in visual_root.find_children("*", "Skeleton3D", true, false):
		var skeleton := skeleton_node as Skeleton3D
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := skeleton.get_bone_name(bone_index).to_lower()
			if "toe_end" in bone_name:
				var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
				var bone_in_body: Transform3D = astronaut.global_transform.affine_inverse() * skeleton.global_transform * bone_pose
				lowest_foot_bone_y = minf(lowest_foot_bone_y, bone_in_body.origin.y)
	_assert(lowest_foot_bone_y >= -0.03 and lowest_foot_bone_y <= 0.1, "Animated boot toe bones sit on the lunar surface rather than below it.")
	var jump_apex: float = astronaut.call("jump_apex_height_m")
	var jump_airtime: float = astronaut.call("jump_flight_time_s")
	_assert(jump_apex > 1.4 and jump_apex < 1.6, "The lunar jump reaches a high but controlled apex.")
	_assert(jump_airtime > 2.6 and jump_airtime < 2.8, "Reduced lunar gravity gives the jump a floaty descent.")
	var jump_key := InputEventKey.new()
	jump_key.keycode = KEY_SPACE
	jump_key.pressed = true
	astronaut.call("_unhandled_input", jump_key)
	_assert(astronaut.get("jump_requested"), "Space requests a jump through the player input handler.")
	var forward_direction: Vector3 = astronaut.call("movement_direction_for_input", Vector2(0.0, -1.0))
	_assert(forward_direction.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Forward input follows the camera's initial heading.")
	var heading_before_mouse: float = astronaut.rotation.y
	var orbit_event := InputEventMouseMotion.new()
	orbit_event.relative = Vector2(100.0, 0.0)
	astronaut.call("_unhandled_input", orbit_event)
	_assert(is_equal_approx(astronaut.rotation.y, heading_before_mouse), "Orbiting the camera does not directly rotate the astronaut.")
	astronaut.set("camera_yaw", PI * 0.5)
	astronaut.call("_sync_camera_rig")
	var turned_direction: Vector3 = astronaut.call("movement_direction_for_input", Vector2(0.0, -1.0))
	_assert(turned_direction.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "Forward input follows the freely orbited camera direction.")
	astronaut.set("camera_yaw", 0.0)
	var front_view_key := InputEventKey.new()
	front_view_key.keycode = KEY_C
	front_view_key.pressed = true
	astronaut.call("_unhandled_input", front_view_key)
	var front_view_direction: Vector3 = astronaut.call("movement_direction_for_input", Vector2(0.0, -1.0))
	_assert(front_view_direction.is_equal_approx(Vector3(0.0, 0.0, 1.0)), "The front-view toggle orbits the camera to show the astronaut's face.")
	_assert(outpost.get_node_or_null("Outpost/Rover") != null, "A rover is placed in the outpost.")
	var rover := outpost.get_node("Outpost/Rover/ImportedRover") as Node3D
	_assert(not rover.find_children("*", "MeshInstance3D", true, false).is_empty(), "The supplied rover model contains rendered meshes.")
	var rover_bounds := AABB()
	var first_mesh := true
	for node in rover.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		rover_bounds = bounds if first_mesh else rover_bounds.merge(bounds)
		first_mesh = false
	_assert(absf(rover_bounds.position.y) < 0.02, "The imported rover rests on the ground.")
	_assert(rover_bounds.size.x < 4.3 and rover_bounds.size.z < 4.3, "The rover fits the outpost footprint.")
	_assert(outpost.get_node("Outpost/Habitat").scene_file_path == "res://Assets/outpost/habitat.tscn", "The habitat uses its reusable asset scene.")
	_assert(outpost.get_node("Outpost/SolarArray").scene_file_path == "res://Assets/outpost/solar_array.tscn", "The solar array uses its reusable asset scene.")
	_assert(outpost.get_node_or_null("Outpost/Astronaut/CameraPivot/SpringArm/ThirdPersonCamera") != null, "The 3D scene includes a collision-aware orbit camera.")
	_assert(outpost.get_node_or_null("Outpost/water_recycler/InteractionArea") != null, "Life-support interaction stations are present.")
	_assert(outpost.get_node_or_null("SelectedSiteReadout") != null, "The outpost displays the selected landing site.")
	# Sweep the real astronaut capsule toward every edge and corner while airborne.
	# This catches missing walls, corner gaps and barriers that can be jumped over.
	astronaut.set_physics_process(false)
	var terrain_bounds: AABB = outpost.get_node("LunarRegolith").get_aabb()
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		astronaut.position = Vector3(direction.x * (terrain_bounds.size.x * 0.5 - 3.0), terrain_bounds.end.y + jump_apex, direction.z * (terrain_bounds.size.z * 0.5 - 3.0))
		var collision := astronaut.move_and_collide(direction * 10.0)
		_assert(collision != null and collision.get_collider() == outpost.get_node("TerrainBoundary"), "The perimeter blocks airborne movement at every edge and corner.")
		_assert(absf(astronaut.position.x) < terrain_bounds.size.x * 0.5 - 0.4 and absf(astronaut.position.z) < terrain_bounds.size.z * 0.5 - 0.4, "The astronaut's full capsule remains over the surface.")
	print("LunarOutpost tests: %d failures." % failures)
	quit(1 if failures > 0 else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
