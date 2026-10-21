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
var health_bar: ProgressBar
var repair_label: Label3D
var contacts: Dictionary = {}
enum Power { INACTIVE, STARTING, READY }
var power_state := Power.INACTIVE
var takeover: CanvasLayer

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
	health_bar = ProgressBar.new()
	health_bar.step = 0.0
	health_bar.position = Vector2(20, 185)
	health_bar.size = Vector2(280, 26)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(health_bar)
	var health_title := Label.new()
	health_title.text = "ROVER HEALTH"
	health_title.position = Vector2(20, 160)
	health_title.add_theme_constant_override("outline_size", 6)
	health_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(health_title)
	repair_label = Label3D.new()
	repair_label.position = Vector3(0, 2.4, 0)
	repair_label.font_size = 32
	repair_label.pixel_size = 0.006
	repair_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rover.add_child(repair_label)
	var area := Area3D.new()
	area.name = "RepairArea"
	area.set_meta("interaction_id", "rover_repair")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.8
	shape.shape = sphere
	shape.position.y = 0.8
	area.add_child(shape)
	rover.add_child(area)
	area.body_entered.connect(world._on_interaction_area_entered.bind(area))
	area.body_exited.connect(world._on_interaction_area_exited.bind(area))
	_update_health()
	overlay.hide()
	takeover = preload("res://src/world/rover_takeover.gd").new()
	takeover.name = "RoverTakeover"
	add_child(takeover)
	takeover.completed.connect(_takeover_finished)
	takeover.interrupted.connect(stop_control)

func _update_health() -> void:
	var health: float = 100.0 if session.dashboard_state == null else session.dashboard_state.rover_health
	health_bar.value = health
	health_bar.modulate = Color("ff6868") if health <= 25.0 else Color("83e6a0")
	repair_label.text = "ROVER HEALTH %d / 100" % ceili(health)
	if health < 100.0:
		repair_label.text += "\n[E] Repair rover (on foot)"
	if health <= 0.0:
		repair_label.text += "\nDISABLED"

func repair() -> bool:
	var player := world.get_node("Outpost/Astronaut")
	var state: Variant = session.dashboard_state
	if active or get_tree().paused or player.seated or player.ui_blocked or state == null:
		return false
	if player.global_position.distance_to(rover.global_position + Vector3(0, 0.8, 0)) > 3.2 or state.rover_health >= 100.0:
		return false
	var fieldwork := world.get_node_or_null("CrewFieldwork")
	if fieldwork != null and not fieldwork.consume_manual_repair():
		repair_label.text = "REPAIR BLOCKED\nNeed a kit, mission material and an unreserved worksite.\nAsk the equipment specialist."
		return false
	state.rover_health = 100.0
	_update_health()
	session.capture_sol_checkpoint()
	session.state_changed.emit()
	return true

func _apply_collision_damage(incoming: Vector3) -> void:
	var touching := {}
	var damage := 0.0
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		# Walkable terrain supports the hull; walls and steep rock faces are impacts.
		if collision.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
			continue
		var id := collision.get_collider_id()
		touching[id] = true
		var impact := maxf(0.0, -incoming.dot(collision.get_normal()))
		if not contacts.has(id) and impact > 0.1:
			damage = maxf(damage, maxf(5.0, 35.0 * impact * impact))
	contacts = touching
	if damage > 0.0:
		observed_state.rover_health = maxf(0.0, observed_state.rover_health - damage)
		_update_health()
		session.state_changed.emit()

func available() -> bool:
	var access := world.get_node_or_null("LanderAccess")
	return access != null and access.inside and not access.busy and world.get_node("Outpost/Astronaut").seated

func start_control() -> bool:
	if active:
		return true
	if get_tree().paused or not available() or world.get_node("Outpost/Astronaut").ui_blocked or world.get_node("MissionHUD")._modal_visible():
		return false
	if session.start_selected_mission() != OK or not session.can_advance():
		return false
	active = true
	power_state = Power.STARTING
	var player := world.get_node("Outpost/Astronaut")
	player.ui_blocked = true
	world.get_node("MissionHUD").panel.hide()
	world.get_node("MissionHUD").help_hint.hide()
	world.get_node("MissionHUD").set_process_input(false)
	_update_camera()
	takeover.begin()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func stop_control() -> void:
	if not active:
		return
	active = false
	takeover.cancel()
	get_node("/root/GameAudio").cancel_rover_startup(self)
	power_state = Power.INACTIVE
	speed = 0.0
	steering = 0.0
	velocity = Vector3.ZERO
	rover.get_node("Wheels").update_motion(0.0, 0.0, WHEELBASE)
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
	contacts.clear()
	_update_health()
	var pose: Dictionary = {} if observed_state == null else observed_state.rover_pose
	position = pose.get("position", Vector3(5.2, 0.65, -2.8))
	heading = float(pose.get("heading", deg_to_rad(-50.0)))
	rotation = Vector3(0, heading, 0)
	speed = 0.0
	velocity = Vector3.ZERO
	_sync_visual(1.0)
	rover.get_node("Wheels").reset()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (active or available()):
			if active and power_state == Power.STARTING:
				pass # Repeated takeover requests cannot restart or cancel the cinematic.
			elif active:
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
	if observed_state.rover_health <= 0.0:
		speed = 0.0
		velocity = Vector3.ZERO
		status.text = "ROVER DISABLED\nR: return to lander\nExit the lander, approach the rover and press E to repair."
		return
	if power_state != Power.READY:
		speed = 0.0
		velocity = Vector3.ZERO
		status.text = "ROVER SYSTEMS STARTING…"
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
	var incoming := velocity
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
	_apply_collision_damage(incoming)
	if is_on_wall():
		speed = 0.0
	observed_state.rover_pose = {"position": position, "heading": heading}
	# Roll only for accepted displacement, including reverse and collision stops.
	var travel := (global_position - before).dot(forward)
	rover.get_node("Wheels").update_motion(travel, steering, WHEELBASE)
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

func _takeover_finished() -> void:
	if active and power_state == Power.STARTING:
		power_state = Power.READY
		_update_camera()
		camera.make_current()
		overlay.show()

func _exit_tree() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio: audio.cancel_rover_startup(self)

func _update_camera() -> void:
	var forward := Vector3(sin(heading), 0, cos(heading))
	camera.global_position = global_position - forward * 6 + Vector3(0, 3, 0)
	camera.look_at(global_position + Vector3(0, 0.6, 0), Vector3.UP)
