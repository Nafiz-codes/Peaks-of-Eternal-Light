class_name LunarAstronaut
extends CharacterBody3D

## Third-person player controller using NASA's 1.62 m/s² lunar gravity and the
## imported animated astronaut's idle/moon-walk clips.

const LUNAR_GRAVITY_MPS2 := 1.62
const WALK_SPEED_MPS := 3.0
## Tuned for a roughly 1.5 m apex and 2.7 s airtime under lunar gravity.
const JUMP_VELOCITY_MPS := 2.2
const LOOK_SENSITIVITY := 0.003

signal interaction_requested(interaction_id: String)

var nearby_interactable: Area3D
var look_pitch := -0.15
var animation_player: AnimationPlayer
var moving := false
var jump_requested := false


func jump_apex_height_m() -> float:
	return JUMP_VELOCITY_MPS * JUMP_VELOCITY_MPS / (2.0 * LUNAR_GRAVITY_MPS2)


func jump_flight_time_s() -> float:
	return 2.0 * JUMP_VELOCITY_MPS / LUNAR_GRAVITY_MPS2


func _ready() -> void:
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.keycode == KEY_SPACE:
			jump_requested = true
		elif event.keycode == KEY_E and nearby_interactable != null:
			interaction_requested.emit(str(nearby_interactable.get_meta("interaction_id", "")))
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		look_pitch = clampf(look_pitch - event.relative.y * LOOK_SENSITIVITY, -0.55, 0.25)
		var camera := get_node_or_null("ThirdPersonCamera") as Camera3D
		if camera != null:
			camera.rotation.x = look_pitch


func _physics_process(delta: float) -> void:
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
	move_and_slide()
	_update_animation(movement.length() > 0.05)

func movement_direction_for_input(input_vector: Vector2) -> Vector3:
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var world_direction := global_transform.basis * local_direction
	world_direction.y = 0.0
	return world_direction.normalized()


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
