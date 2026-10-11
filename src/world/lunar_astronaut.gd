class_name LunarAstronaut
extends CharacterBody3D

## Third-person player controller using NASA's 1.62 m/s² lunar gravity and the
## imported animated astronaut's idle/moon-walk clips.

const LUNAR_GRAVITY_MPS2 := 1.62
const WALK_SPEED_MPS := 3.0
const TURN_SPEED_RAD_PER_SEC := 7.0
## Tuned for a roughly 1.5 m apex and 2.7 s airtime under lunar gravity.
const JUMP_VELOCITY_MPS := 2.2
const LOOK_SENSITIVITY := 0.003
const MIN_CAMERA_PITCH := -0.75
const MAX_CAMERA_PITCH := 0.5

signal interaction_requested(interaction_id: String)

var nearby_interactable: Area3D
var camera_yaw := 0.0
var camera_pitch := -0.22
var animation_player: AnimationPlayer
var moving := false
var jump_requested := false
var ui_blocked := false
var first_person := false

func set_first_person(enabled: bool) -> void:
	first_person = enabled
	var first_camera := get_node_or_null("CameraPivot/FirstPersonCamera") as Camera3D
	var third_camera := get_node_or_null("CameraPivot/SpringArm/ThirdPersonCamera") as Camera3D
	if first_camera != null and third_camera != null:
		if first_person:
			first_camera.make_current()
		else:
			third_camera.make_current()
	var visual := get_node_or_null("AnimatedAstronaut") as Node3D
	if visual != null:
		visual.visible = true
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var key := "original_material_%d" % surface
				if not mesh.has_meta(key):
					mesh.set_meta(key, mesh.get_active_material(surface))
				if first_person:
					var original := mesh.get_meta(key) as StandardMaterial3D
					var material := ShaderMaterial.new()
					material.shader = preload("res://src/world/first_person_suit.gdshader")
					if original != null:
						material.set_shader_parameter("suit_color", original.albedo_color)
						material.set_shader_parameter("has_texture", original.albedo_texture != null)
						material.set_shader_parameter("suit_texture", original.albedo_texture)
					mesh.set_surface_override_material(surface, material)
				else:
					mesh.set_surface_override_material(surface, mesh.get_meta(key))
		for skeleton in visual.find_children("*", "Skeleton3D", true, false):
			for bone in range(skeleton.get_bone_count()):
				if str(skeleton.get_bone_name(bone)).to_lower().begins_with("head"):
					var pose: Transform3D = skeleton.get_bone_global_pose_no_override(bone)
					pose.basis = pose.basis.scaled(Vector3.ONE * 0.001)
					skeleton.set_bone_global_pose_override(bone, pose, 1.0 if first_person else 0.0, true)
	if first_person:
		rotation.y = camera_yaw
	else:
		camera_pitch = clampf(camera_pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
	_sync_camera_rig()


func jump_apex_height_m() -> float:
	return JUMP_VELOCITY_MPS * JUMP_VELOCITY_MPS / (2.0 * LUNAR_GRAVITY_MPS2)


func jump_flight_time_s() -> float:
	return 2.0 * JUMP_VELOCITY_MPS / LUNAR_GRAVITY_MPS2


func _ready() -> void:
	# The lander's stair walking surface rises at approximately 48 degrees.
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	set_process_unhandled_input(true)
	_sync_camera_rig()
	var spring_arm := get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
	if spring_arm != null:
		spring_arm.add_excluded_object(get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if ui_blocked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.keycode == KEY_SPACE:
			jump_requested = true
		elif event.keycode == KEY_C:
			camera_yaw = wrapf(camera_yaw + PI, -PI, PI)
			_sync_camera_rig()
		elif event.keycode == KEY_V:
			set_first_person(not first_person)
		elif event.keycode == KEY_I:
			var session := get_node_or_null("/root/MissionSession")
			if session != null and get_tree().current_scene != null:
				session.call("open_dashboard", get_tree().current_scene.scene_file_path)
		elif event.keycode == KEY_E and nearby_interactable != null:
			interaction_requested.emit(str(nearby_interactable.get_meta("interaction_id", "")))
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw = wrapf(camera_yaw - event.relative.x * LOOK_SENSITIVITY, -PI, PI)
		camera_pitch = clampf(camera_pitch - event.relative.y * LOOK_SENSITIVITY, -1.45 if first_person else MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
		_sync_camera_rig()


func _physics_process(delta: float) -> void:
	if ui_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		jump_requested = false
		velocity.x = 0.0
		velocity.z = 0.0
		_update_animation(false)
		return
	if not is_on_floor():
		velocity.y -= LUNAR_GRAVITY_MPS2 * delta
	if jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY_MPS
	jump_requested = false

	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var movement := movement_direction_for_input(input_vector)
	velocity.x = movement.x * WALK_SPEED_MPS
	velocity.z = movement.z * WALK_SPEED_MPS
	if first_person:
		rotation.y = camera_yaw
	elif movement.length_squared() > 0.0025:
		var target_yaw := atan2(-movement.x, -movement.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, TURN_SPEED_RAD_PER_SEC * delta)
	_sync_camera_rig()
	move_and_slide()
	_update_animation(movement.length() > 0.05)

func movement_direction_for_input(input_vector: Vector2) -> Vector3:
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var world_direction := Basis(Vector3.UP, camera_yaw) * local_direction
	world_direction.y = 0.0
	return world_direction.normalized()


func _sync_camera_rig() -> void:
	var pivot := get_node_or_null("CameraPivot") as Node3D
	if pivot != null:
		pivot.rotation = Vector3(camera_pitch, camera_yaw - rotation.y, 0.0)
		if first_person:
			var camera := get_node("CameraPivot/FirstPersonCamera") as Camera3D
			# Eye position must not orbit into the chest when looking down.
			camera.global_position = global_transform * Vector3(0.0, 1.57, -0.10)
			for mesh in get_node("AnimatedAstronaut").find_children("*", "MeshInstance3D", true, false):
				for surface in range(mesh.mesh.get_surface_count()):
					var material := mesh.get_surface_override_material(surface) as ShaderMaterial
					if material != null:
						material.set_shader_parameter("world_to_body", global_transform.affine_inverse())


func set_animation_player(player: AnimationPlayer) -> void:
	animation_player = player
	if animation_player == null:
		return
	var idle := animation_player.get_animation("idle")
	if idle != null:
		idle.loop_mode = Animation.LOOP_LINEAR
	animation_player.play("idle")


func _update_animation(should_move: bool) -> void:
	if animation_player == null or moving == should_move:
		return
	moving = should_move
	var animation_name := "moon_walk" if moving else "idle"
	var animation := animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(animation_name, 0.18)


func set_nearby_interactable(area: Area3D) -> void:
	nearby_interactable = area


func clear_nearby_interactable(area: Area3D) -> void:
	if nearby_interactable == area:
		nearby_interactable = null
