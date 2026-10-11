class_name LunarAstronaut
extends CharacterBody3D

## Third-person player controller using NASA's 1.62 m/s² lunar gravity and the
## imported animated astronaut's idle/moon-walk clips.

const LUNAR_GRAVITY_MPS2 := 1.62
const WALK_SPEED_MPS := 1.6
const SPRINT_SPEED_MPS := 3.0
const GROUND_ACCELERATION_MPS2 := 1.2
const GROUND_BRAKING_MPS2 := 1.6
const TURN_SPEED_RAD_PER_SEC := 7.0
## Moderate suited hop: approximately 0.60 m high and 1.73 s airborne.
const JUMP_VELOCITY_MPS := 1.4
const LOOK_SENSITIVITY := 0.003
const MIN_CAMERA_PITCH := -0.75
const MAX_CAMERA_PITCH := 0.5
# Keep the eye ahead of the visor/chest; pitch rotates the view, not this offset.
const FIRST_PERSON_EYE := Vector3(0.0, 1.70, -0.48)

signal interaction_requested(interaction_id: String)

var nearby_interactable: Area3D
var camera_yaw := 0.0
var camera_pitch := -0.22
var animation_player: AnimationPlayer
var moving := false
var jump_requested := false
var ui_blocked := false
var first_person := false
var seated := false
var seated_eye := Vector3.ZERO
var seated_yaw := PI

func set_seated(enabled: bool, eye: Vector3 = Vector3.ZERO) -> void:
	seated = enabled
	seated_eye = eye
	velocity = Vector3.ZERO
	jump_requested = false
	if enabled:
		camera_yaw = seated_yaw
		camera_pitch = 0.35
		set_first_person(true)
	get_node("CameraPivot/FirstPersonCamera").fov = 75.0 if enabled else 90.0
	# The imported couch surrounds the seated eye. Hide the standing full-body
	# avatar in this first-person seat view to avoid helmet and torso clipping.
	get_node("AnimatedAstronaut").visible = not enabled
	if animation_player != null:
		animation_player.speed_scale = 0.0 if enabled else 1.0
	_sync_camera_rig()

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
		visual.visible = not seated
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
		if seated and event.keycode in [KEY_SPACE, KEY_C, KEY_V]:
			return
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
		camera_pitch = clampf(camera_pitch - event.relative.y * LOOK_SENSITIVITY, -0.25 if seated else (-1.45 if first_person else MIN_CAMERA_PITCH), 1.15 if seated else MAX_CAMERA_PITCH)
		if seated:
			camera_yaw = seated_yaw + clampf(wrapf(camera_yaw - seated_yaw, -PI, PI), -0.9, 0.9)
			camera_pitch = clampf(camera_pitch, -0.25, 1.15)
		_sync_camera_rig()


func _physics_process(delta: float) -> void:
	if seated:
		return
	var controls_active := not ui_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input_vector := Vector2.ZERO
	if controls_active:
		input_vector = Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)
	var wants_sprint := controls_active and Input.is_key_pressed(KEY_SHIFT) and input_vector.y < 0.0
	_step_locomotion(delta, input_vector, controls_active and jump_requested, wants_sprint)
	jump_requested = false


func _step_locomotion(delta: float, input_vector: Vector2, wants_jump: bool, wants_sprint: bool = false) -> void:
	var grounded := is_on_floor()
	var movement := movement_direction_for_input(input_vector)
	var horizontal := Vector2(velocity.x, velocity.z)
	if grounded:
		var speed := SPRINT_SPEED_MPS if wants_sprint and input_vector.y < 0.0 else WALK_SPEED_MPS
		var target := Vector2(movement.x, movement.z) * speed
		var acceleration := GROUND_ACCELERATION_MPS2 if not input_vector.is_zero_approx() else GROUND_BRAKING_MPS2
		horizontal = horizontal.move_toward(target, acceleration * delta)
		velocity.y = JUMP_VELOCITY_MPS if wants_jump else 0.0
	# No airborne steering or drag in vacuum; preserve takeoff momentum.
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var airborne := not grounded or wants_jump
	if airborne:
		velocity.y -= LUNAR_GRAVITY_MPS2 * delta * 0.5
	# Stair snapping must not pull an airborne astronaut down before contact.
	floor_snap_length = 0.0 if airborne else 0.4
	if first_person:
		rotation.y = camera_yaw
	elif grounded and horizontal.length_squared() > 0.0025:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, TURN_SPEED_RAD_PER_SEC * delta)
	move_and_slide()
	# Split gravity around movement for tick-rate-independent ballistic motion.
	if airborne and not is_on_floor() and not is_on_ceiling():
		velocity.y -= LUNAR_GRAVITY_MPS2 * delta * 0.5
	_sync_camera_rig()
	_update_animation(horizontal.length() > 0.05 or not is_on_floor())
	if animation_player != null:
		animation_player.speed_scale = clampf(horizontal.length() / WALK_SPEED_MPS, 0.25, SPRINT_SPEED_MPS / WALK_SPEED_MPS) if moving else 1.0
		# Continue the forward arm/leg cycle through the jump at a slower lunar cadence.
		if not is_on_floor():
			animation_player.speed_scale = 0.65

func movement_direction_for_input(input_vector: Vector2) -> Vector3:
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var world_direction := Basis(Vector3.UP, camera_yaw) * local_direction
	world_direction.y = 0.0
	return world_direction.normalized()


func _sync_camera_rig() -> void:
	if first_person:
		rotation.y = camera_yaw
	var pivot := get_node_or_null("CameraPivot") as Node3D
	if pivot != null:
		pivot.rotation = Vector3(camera_pitch, camera_yaw - rotation.y, 0.0)
		if first_person:
			var camera := get_node("CameraPivot/FirstPersonCamera") as Camera3D
			camera.global_position = seated_eye if seated else global_transform * FIRST_PERSON_EYE


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
