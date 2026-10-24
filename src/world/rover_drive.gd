extends CharacterBody3D

## Slow teleoperation with bicycle steering. Speeds are gameplay tuning values.
const MAX_SPEED := 2.4
const REVERSE_SPEED := 1.0
const ACCELERATION := 0.7
const BRAKING := 1.8
const STEP_HEIGHT := 0.3
const MOUSE_SENSITIVITY := 0.003
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
var impact_cooldown := 0.0
enum Power { INACTIVE, STARTING, READY }
var power_state := Power.INACTIVE
var takeover: CanvasLayer
var camera_yaw := 0.0
var camera_elevation := 0.38
var boost_held := false

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
		if not contacts.has(id) and impact_cooldown <= 0:
			damage = maxf(damage, impact_damage(collision.get_collider(), collision.get_normal(), incoming))
	contacts = touching
	if damage > 0.0:
		impact_cooldown = 1.0
		observed_state.rover_health = maxf(0.0, observed_state.rover_health - damage)
		_update_health()
		session.state_changed.emit()

static func impact_damage(collider: Node, normal: Vector3, incoming: Vector3) -> float:
	var ancestor := collider
	while ancestor != null:
		if ancestor.has_meta("crew_id") or ancestor.get_meta("rover_target", "") == "astronaut" or ancestor.has_meta("rover_safe_terrain"):
			return 0.0
		ancestor = ancestor.get_parent()
	# Only a substantial horizontal impact with a solid obstacle causes damage.
	if absf(normal.y) > 0.35:
		return 0.0
	var impact := maxf(0.0, -Vector3(incoming.x, 0, incoming.z).dot(normal))
	return clampf(8.0 * impact * impact, 0, 30) if impact >= 0.65 else 0.0

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
	boost_held = false
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
	_settle_parked()

func _settle_parked() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or active: return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 100, global_position - Vector3.UP * 200, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y >= cos(floor_max_angle):
		global_position.y = hit.position.y + 0.65
		velocity = Vector3.ZERO
		_sync_visual(1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_SHIFT and event.location == KEY_LOCATION_LEFT:
		boost_held = event.pressed
	if event is InputEventMouseMotion and active and power_state == Power.READY and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var expedition := world.get_node_or_null("RoverTraining")
		if expedition == null or not expedition.transitioning:
			_apply_mouse_look(event.relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (active or available()):
			var expedition := world.get_node_or_null("RoverTraining")
			if expedition != null and expedition.get("transitioning") == true:
				get_viewport().set_input_as_handled()
				return
			if active and power_state == Power.STARTING:
				pass # Repeated takeover requests cannot restart or cancel the cinematic.
			elif active:
				stop_control()
			else:
				start_control()
			get_viewport().set_input_as_handled()
		elif active and event.keycode in [KEY_E, KEY_I, KEY_V, KEY_C, KEY_ALT]:
			var training := world.get_node_or_null("RoverTraining")
			if training != null: training.handle_key(event.keycode)
			get_viewport().set_input_as_handled()
		elif active and event.keycode in [KEY_L, KEY_F, KEY_ENTER]:
			var training := world.get_node_or_null("RoverTraining")
			if training != null: training.handle_key(event.keycode)
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not Input.is_physical_key_pressed(KEY_SHIFT): boost_held = false
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
	impact_cooldown = maxf(0, impact_cooldown - delta)
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
	var training := world.get_node_or_null("RoverTraining")
	if training != null and training.locks_drive():
		throttle = 0.0
		turn = 0.0
		brake = true
	var boost := 2.0 if boost_held else 1.0
	var target := clampf(throttle, -1, 1) * (MAX_SPEED if throttle >= 0 else REVERSE_SPEED) * boost
	if training != null and training.has_method("speed_limit"):
		var limit: float = training.speed_limit(throttle)
		if limit >= MAX_SPEED: limit *= boost
		target = clampf(target,-limit,limit)
		if limit == 0.0:
			speed = 0.0
			brake = true
	var deceleration := brake or is_zero_approx(throttle) or speed * throttle < 0
	if is_on_floor():
		speed = move_toward(speed, 0.0 if brake else target, (BRAKING * 2.0 if deceleration or absf(speed) > absf(target) else ACCELERATION * boost) * delta)
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
	_try_step(Vector3(velocity.x, 0, velocity.z) * delta)
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
	if is_on_wall() and metres < absf(speed) * delta * 0.1:
		speed = 0.0
	observed_state.rover_pose = {"position": position, "heading": heading}
	# Roll only for accepted displacement, including reverse and collision stops.
	var travel := (global_position - before).dot(forward)
	rover.get_node("Wheels").update_motion(travel, steering, WHEELBASE)
	_sync_visual(delta)
	_update_camera()
	status.text = "LANDER / ROVER REMOTE CAMERA\nW/S: drive · A/D: steer · Left Shift: 2× speed · Space: brake\nMouse: look around · R: return · Esc: pause\nSpeed %.2f m/s · Travel %.1f m" % [absf(speed), observed_state.rover_total_distance_km * 1000.0]
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
	# The upright collision box rests on its uphill edge. Place the visual tires
	# against the surface independently so that this does not lift the whole model.
	var support := 0.0
	var samples := 0
	for wheel in rover.get_node("Wheels").wheels:
		var offset: Vector3 = rover.basis * wheel.center
		var point := global_position + Vector3(offset.x, 0, offset.z)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 2.5, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y >= cos(floor_max_angle):
			support += hit.position.y - offset.y + wheel.radius
			samples += 1
	if samples >= 3 and (is_on_floor() or absf(velocity.y) < 0.1):
		rover.global_position.y = support / samples

func _takeover_finished() -> void:
	if active and power_state == Power.STARTING:
		power_state = Power.READY
		_update_camera()
		camera.make_current()
		overlay.show()

func _exit_tree() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio: audio.cancel_rover_startup(self)

func _apply_mouse_look(relative: Vector2) -> void:
	if not active or power_state != Power.READY or get_tree().paused:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var sensitivity := MOUSE_SENSITIVITY * (float(settings.values.sensitivity) if settings != null else 1.0)
	var vertical := -1.0 if settings != null and settings.values.invert_y else 1.0
	camera_yaw = wrapf(camera_yaw - relative.x * sensitivity, -PI, PI)
	camera_elevation = clampf(camera_elevation + relative.y * sensitivity * vertical, 0.12, 1.2)
	_update_camera()

func _try_step(motion: Vector3) -> void:
	if not is_on_floor() or motion.length_squared() < 0.00000001:
		return
	var hit := KinematicCollision3D.new()
	var probe := motion.normalized() * maxf(motion.length(), 0.08)
	if not test_move(global_transform, probe, hit, safe_margin, false, 8):
		return
	var wall := false
	for index in range(hit.get_collision_count()):
		wall = wall or hit.get_normal(index).dot(Vector3.UP) < cos(floor_max_angle)
	if not wall:
		return
	# Lift only when the entire hull clears the ledge and has walkable support.
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	var raised := global_transform
	raised.origin += lift
	if test_move(raised, probe):
		return
	raised.origin += probe
	if not test_move(raised, Vector3.DOWN * (STEP_HEIGHT + floor_snap_length), hit):
		return
	if hit.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	global_position += lift
	velocity.y = 0.0

func _update_camera() -> void:
	var view_heading := heading + camera_yaw
	var forward := Vector3(sin(view_heading), 0, cos(view_heading))
	var focus := global_position + Vector3(0, 0.6, 0)
	var desired := focus - forward * (6.5 * cos(camera_elevation)) + Vector3.UP * (6.5 * sin(camera_elevation))
	var query := PhysicsRayQueryParameters3D.create(focus, desired)
	query.exclude = [get_rid()]
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	camera.global_position = desired if obstruction.is_empty() else obstruction.position + obstruction.normal * 0.2
	if camera.global_position.distance_squared_to(focus) > 0.01:
		camera.look_at(focus, Vector3.UP)
