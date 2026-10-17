extends CharacterBody3D

## Slow teleoperation with bicycle steering. Speeds are gameplay tuning values.
const MAX_SPEED := 1.2
const REVERSE_SPEED := 0.5
const ACCELERATION := 0.35
const BRAKING := 0.9
const WHEELBASE := 2.2
const MAX_STEER := 0.55
var active := false
var speed := 0.0
var steering := 0.0
var heading := deg_to_rad(-50.0)
var camera: Camera3D
var overlay: CanvasLayer
var status: Label
var observed_state: Variant = null
var publish_elapsed := 0.0
var world: Node3D
var rover: Node3D
var session: Node

func _ready() -> void:
	world = get_parent()
	rover = world.get_node("Outpost/Rover")
	session = get_node("/root/MissionSession")
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(32)
	camera = Camera3D.new()
	camera.name = "RemoteCamera"
	camera.fov = 65
	add_child(camera)
	overlay = CanvasLayer.new()
	overlay.layer = 85
	add_child(overlay)
	status = Label.new()
	status.position = Vector2(20, 20)
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 8)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(status)
	overlay.hide()

func available() -> bool:
	var access := world.get_node_or_null("LanderAccess")
	return access != null and access.inside and not access.busy and world.get_node("Outpost/Astronaut").seated

func start_control() -> bool:
	if active:
		return true
	if not available() or world.get_node("MissionHUD")._modal_visible():
		return false
	if session.start_selected_mission() != OK or not session.can_advance():
		return false
	active = true
	var player := world.get_node("Outpost/Astronaut")
	player.ui_blocked = true
	world.get_node("MissionHUD").panel.hide()
	world.get_node("MissionHUD").help_hint.hide()
	world.get_node("MissionHUD").set_process_input(false)
	_update_camera()
	camera.make_current()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func stop_control() -> void:
	if not active:
		return
	active = false
	speed = 0.0
	steering = 0.0
	velocity = Vector3.ZERO
	overlay.hide()
	var player := world.get_node("Outpost/Astronaut")
	player.ui_blocked = false
	player.set_first_person(true)
	world.get_node("MissionHUD").set_process_input(true)
	world.get_node("MissionHUD").help_hint.show()
	session.capture_sol_checkpoint()
	session.state_changed.emit()

func sync_state() -> void:
	if observed_state == session.dashboard_state:
		return
	stop_control()
	observed_state = session.dashboard_state
	var pose: Dictionary = {} if observed_state == null else observed_state.rover_pose
	position = pose.get("position", Vector3(5.2, 0.65, -2.8))
	heading = float(pose.get("heading", deg_to_rad(-50.0)))
	rotation = Vector3(0, heading, 0)
	speed = 0.0
	velocity = Vector3.ZERO
	_sync_visual(1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (active or available()):
			if active:
				stop_control()
			else:
				start_control()
			get_viewport().set_input_as_handled()
		elif active and event.keycode in [KEY_E, KEY_I, KEY_V, KEY_C, KEY_ALT]:
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not available() or not session.can_advance():
		stop_control()
		return
	step_drive(delta, float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)),
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), Input.is_key_pressed(KEY_SPACE))

func step_drive(delta: float, throttle: float, turn: float, brake: bool) -> void:
	if not active or not available() or not session.can_advance() or get_tree().paused:
		return
	var target := clampf(throttle, -1, 1) * (MAX_SPEED if throttle >= 0 else REVERSE_SPEED)
	var deceleration := brake or is_zero_approx(throttle) or speed * throttle < 0
	if is_on_floor():
		speed = move_toward(speed, 0.0 if brake else target, (BRAKING if deceleration else ACCELERATION) * delta)
	steering = move_toward(steering, clampf(turn, -1, 1) * MAX_STEER, 0.7 * delta)
	# Reverse travel reverses the turn; stationary steering cannot spin the rover.
	if is_on_floor():
		heading -= speed / WHEELBASE * tan(steering) * delta
	rotation.y = heading
	var forward := Vector3(sin(heading), 0, cos(heading))
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y -= 1.62 * delta
	var before := global_position
	move_and_slide()
	var metres := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if metres > 0.000001:
		var result: Dictionary = session.send_rover("traverse", metres / 1000.0)
		if not result.get("ok", false):
			global_position = before
			speed = 0.0
			velocity = Vector3.ZERO
			status.text = "ROVER STOPPED / " + str(result.get("error", "unavailable")).replace("_", " ") + "\nR: return to lander"
			_sync_visual(delta)
			return
	if is_on_wall():
		speed = 0.0
	observed_state.rover_pose = {"position": position, "heading": heading}
	_sync_visual(delta)
	_update_camera()
	status.text = "LANDER / ROVER REMOTE CAMERA\nW/S: forward / reverse · A/D: steer · Space: brake\nR: return to lander · Esc: pause\nSpeed %.2f m/s · Travel %.1f m" % [absf(speed), observed_state.rover_total_distance_km * 1000.0]
	publish_elapsed += delta
	if publish_elapsed >= 0.25:
		publish_elapsed = 0.0
		session.state_changed.emit()

func _sync_visual(delta: float) -> void:
	rover.position = position - Vector3(0, 0.65, 0)
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	var forward := Vector3(sin(heading), 0, cos(heading)).slide(normal).normalized()
	if forward.length_squared() < 0.5:
		forward = Vector3.FORWARD
	var right := normal.cross(forward).normalized()
	var target := Basis(right, forward.cross(right).normalized(), forward).orthonormalized()
	rover.basis = rover.basis.slerp(target, minf(1, delta * 5)).orthonormalized()

func _update_camera() -> void:
	var forward := Vector3(sin(heading), 0, cos(heading))
	camera.global_position = global_position - forward * 6 + Vector3(0, 3, 0)
	camera.look_at(global_position + Vector3(0, 0.6, 0), Vector3.UP)
