extends Node3D
## World adapter for MissionSession's saved training state. No astronaut transport.
signal hud_changed(view: Dictionary)
const Rules = preload("res://src/simulation/rover_training.gd")
const Target = preload("res://src/world/rover_scan_target.gd")
const Scanner = preload("res://src/world/rover_scanner.gd")
@export_range(60.0, 1800.0) var life_support_seconds := 480.0
@export_range(0.001, 0.1) var battery_drain_per_second := 0.012
@export_range(1.0, 8.0) var scan_seconds := 3.0
var rules := Rules.new()
var scanner := Scanner.new()
var driver: Node3D
var session: Node
var bound_state: RefCounted
var targets: Dictionary = {}
var hud: CanvasLayer
var lights: SpotLight3D
var tool: MeshInstance3D
var tool_arm: MeshInstance3D
var dust: CPUParticles3D
var shadow_patch: MeshInstance3D
var kit: MeshInstance3D
var relay: MeshInstance3D
var astronaut: Node3D
var sound: AudioStreamPlayer
var busy_id := ""
var busy_stage := ""
var busy_elapsed := 0.0
var busy_duration := 0.0
var publish_time := 0.0
var beacon_time := 0.0
var feedback := ""
var grounded := false

func _ready() -> void:
	driver = get_parent().get_node("RoverHull")
	session = get_node("/root/MissionSession")
	rules.changed.connect(_changed)
	scanner.duration = scan_seconds
	if not InputMap.has_action("rover_scan"):
		InputMap.add_action("rover_scan")
		var scan_key := InputEventKey.new()
		scan_key.physical_keycode = KEY_F
		InputMap.action_add_event("rover_scan", scan_key)
	hud = preload("res://src/ui/rover_training_hud.gd").new()
	add_child(hud)
	hud_changed.connect(hud.render)
	_build_targets()
	lights = SpotLight3D.new()
	lights.position = Vector3(0, 0.9, 1.4)
	lights.rotation.y = PI
	lights.spot_range = 22
	lights.spot_angle = 48
	lights.light_energy = 3.5
	lights.shadow_enabled = true
	driver.add_child(lights)
	tool = _box(Vector3(0.12, 0.7, 0.12), Color("8cabb6"))
	tool.position = Vector3(1.05, 0.45, 1.15)
	driver.add_child(tool)
	tool_arm = _box(Vector3(0.08, 0.08, 1.0), Color("738795"))
	add_child(tool_arm)
	tool_arm.hide()
	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.amount = 14
	dust.lifetime = 0.65
	dust.direction = Vector3.UP
	dust.spread = 30
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.6
	dust.gravity = Vector3(0, -1.62, 0)
	dust.mesh = SphereMesh.new()
	dust.mesh.radius = 0.012
	dust.mesh.height = 0.024
	add_child(dust)
	shadow_patch = MeshInstance3D.new()
	shadow_patch.mesh = get_parent().get_node("LunarRegolith").mesh
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://src/world/rover_training_shadow.gdshader")
	shadow_patch.material_override = shadow_material
	shadow_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow_patch)
	shadow_patch.hide()
	kit = _box(Vector3(0.5, 0.3, 0.4), Color("e8b352"))
	add_child(kit)
	relay = _box(Vector3(0.08, 1.5, 0.08), Color("72d8e8"))
	add_child(relay)
	sound = AudioStreamPlayer.new()
	sound.bus = "Gameplay_SFX"
	sound.volume_db = -22
	add_child(sound)
	_sync()

func _box(size_: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	return node

func _build_targets() -> void:
	# All tasks fit the existing 120 m playable patch, away from the base props.
	var entries := [
		["alpha", "SURVEY ALPHA", Vector3(16, 0, -8), Color("6ce8ea")],
		["beta", "SURVEY BETA", Vector3(26, 0, 6), Color("af9fff")],
		["gamma", "SURVEY GAMMA", Vector3(18, 0, 23), Color("ffd188")],
		["uplink", "OUTPOST DATA UPLINK", Vector3(8, 0, 9), Color("91edae")],
		["perimeter", "SHADOW-REGION TRAINING PERIMETER", Vector3(28, 0, -9), Color("7ec7e9")],
		["ice_a", "CANDIDATE A", Vector3(32, 0, -19), Color("93c7e2")],
		["ice_b", "CANDIDATE B", Vector3(40, 0, -11), Color("93c7e2")],
		["ice_c", "CANDIDATE C", Vector3(35, 0, 0), Color("93c7e2")],
		["search_area", "DISTRESS SEARCH AREA ±10 m", Vector3(30, 0, 27), Color("ffbc70")],
		["astronaut", "STRANDED ASTRONAUT", Vector3(37, 0, 29), Color("ffbc70")]]
	for entry in entries:
		var target := Target.new()
		target.setup(entry[0], entry[1], entry[3])
		add_child(target)
		target.position = entry[2]
		target.hide()
		targets[entry[0]] = target
	astronaut = Node3D.new()
	targets.astronaut.add_child(astronaut)
	preload("res://src/world/station_astronaut.gd").populate(astronaut,
		preload("res://Assets/animated_astronaut/source/Walking astronaut.glb"), Color("edab57"))
	astronaut.get_node("CrewBody").collision_layer = 0
	# Small modular deposits identify the science tools' contact points.
	for id in Rules.READINGS:
		var deposit := _box(Vector3(0.8, 0.22, 0.7), Color("414954"))
		deposit.position.y = 0.2
		targets[id].add_child(deposit)

func _ground_targets() -> void:
	for target in targets.values():
		var ray := PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 30, target.global_position - Vector3.UP * 30, 1)
		# Terrain only: don't place the stranded astronaut on its own capsule.
		var bodies: Array[Node] = target.find_children("*", "PhysicsBody3D", true, false)
		var excluded: Array[RID] = []
		for body in bodies: excluded.append(body.get_rid())
		ray.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): target.global_position.y = hit.position.y
	grounded = true

func _sync() -> void:
	if bound_state == session.dashboard_state: return
	bound_state = session.dashboard_state
	_cancel_tool()
	scanner.reset()
	if bound_state == null:
		rules.data = {}
	else:
		if bound_state.rover_training.is_empty(): rules.begin(0, life_support_seconds)
		else: rules.data = bound_state.rover_training
		bound_state.rover_training = rules.data
	_changed()

func remote_ready() -> bool:
	return driver.active and driver.power_state == driver.Power.READY and driver.available() and session.can_advance() and not get_tree().paused

func locks_drive() -> bool:
	return busy_id != "" or (not rules.data.is_empty() and rules.data.status != "active")

func handle_key(key: int) -> void:
	if not remote_ready() or rules.data.is_empty(): return
	if key == KEY_ENTER and rules.data.status in ["success", "failed"]:
		if rules.data.status == "success" and rules.data.mission == 2: return
		var index: int = rules.data.mission + (1 if rules.data.status == "success" else 0)
		_restart(index)
		return
	if rules.data.status != "active" or busy_id != "": return
	if key == KEY_L:
		rules.data.lights = not rules.data.lights
		_tone(620, 0.06)
	elif key == KEY_E:
		var id: String = rules.action_target()
		if id == "":
			feedback = "Complete the current scans first."
			return
		feedback = scanner.validate(driver, targets[id], id != "uplink" and id != "perimeter")
		if feedback != "": return
		if rules.data.stage == "perimeter" and not rules.data.lights:
			feedback = "Press L to enable headlights."
			return
		busy_id = id
		busy_stage = rules.data.stage
		busy_elapsed = 0.0
		busy_duration = 6.0 if busy_stage == "sample" else 3.0
		scanner.reset()
		_tone(130 if busy_stage == "sample" else 450, 0.3)
	_changed()

func _restart(index: int) -> void:
	_cancel_tool()
	scanner.reset()
	feedback = ""
	rules.begin(index, life_support_seconds)
	bound_state.rover_training = rules.data
	# A training retry returns equipment to its safe deployment pad.
	bound_state.rover_health = 100.0
	driver.position = Vector3(5.2, 0.65, -2.8)
	driver.heading = deg_to_rad(-50.0)
	driver.rotation.y = driver.heading
	driver.speed = 0.0
	driver.velocity = Vector3.ZERO
	bound_state.rover_pose = {"position": driver.position, "heading": driver.heading}
	driver._sync_visual(1.0)
	driver._update_health()
	session.capture_sol_checkpoint()
	_changed()

func _physics_process(delta: float) -> void:
	if not grounded: _ground_targets()
	_sync()
	if rules.data.is_empty():
		lights.hide()
		kit.hide()
		relay.hide()
		_publish()
		return
	var ready := remote_ready()
	if ready and rules.data.status == "active" and rules.data.mission == 1:
		var in_cold := Vector2(driver.position.x - 35.0, driver.position.z + 10.0).length() < 16.0
		rules.data.cold_exposure = maxf(0.0, rules.data.cold_exposure + delta * (1.0 if in_cold else -2.0))
	var clock_delta := 0.0 if driver.active and driver.power_state == driver.Power.STARTING else delta
	rules.tick(clock_delta, ready, absf(driver.speed) > 0.05, busy_id != "" or scanner.progress > 0, bound_state.rover_health, battery_drain_per_second)
	lights.visible = ready and rules.data.lights
	if rules.data.status == "active" and maxf(absf(driver.position.x), absf(driver.position.z)) > 59.0:
		rules.fail("Rover left the marked 120 m training boundary.")
	if not ready or rules.data.status != "active":
		scanner.reset()
		_cancel_tool()
	elif busy_id != "":
		var rejection := scanner.validate(driver, targets[busy_id], busy_id not in ["uplink", "perimeter"])
		if rejection != "" or rules.action_target() != busy_id:
			feedback = "Interaction interrupted: " + rejection
			_cancel_tool()
		else:
			busy_elapsed += delta
			if busy_stage == "sample":
				var socket := driver.to_global(Vector3(1.05, 0.45, 1.15))
				var point: Vector3 = targets[busy_id].global_position + Vector3.UP * 0.45
				var extension := minf(busy_elapsed / 0.7, 1.0) * (1.0 - smoothstep(3.0, 4.0, busy_elapsed))
				tool.global_position = socket.lerp(point, extension)
				tool.rotation.y += delta * 14
				tool_arm.visible = extension > 0.01
				tool_arm.global_position = socket.lerp(tool.global_position, 0.5)
				if socket.distance_to(tool.global_position) > 0.01:
					tool_arm.look_at(tool.global_position)
					tool_arm.scale.z = socket.distance_to(tool.global_position)
				dust.global_position = point - Vector3.UP * 0.3
				dust.emitting = busy_elapsed > 0.7 and busy_elapsed < 3.0
			if busy_stage == "kit":
				kit.show()
				kit.global_position = (driver.global_position + Vector3.UP).lerp(targets.astronaut.global_position + Vector3(0.9, 0.2, 0), clampf(busy_elapsed / busy_duration, 0, 1))
			if busy_elapsed >= busy_duration:
				var id := busy_id
				_cancel_tool()
				if rules.complete_action(id):
					_tone(920, 0.18)
					session.capture_sol_checkpoint()
	else:
		var target := _scan_candidate()
		var id: String = "" if target == null else target.target_id
		var rejection := "Aim at an unscanned mission target" if target == null else scanner.validate(driver, target)
		if scanner.advance(delta, Input.is_action_pressed("rover_scan"), id, rules.eligible(id), rejection):
			if rules.record_scan(id):
				_tone(1000, 0.16)
				feedback = "Scan stored: " + id.to_upper()
				_changed()
		if Input.is_action_pressed("rover_scan") and rejection != "": feedback = rejection
	if ready and rules.data.mission == 2 and rules.data.status == "active" and not rules.data.stabilized:
		beacon_time += delta
		if beacon_time >= lerpf(2.5, 0.4, _beacon()):
			beacon_time = 0.0
			_tone(740, 0.07)
	publish_time += delta
	if publish_time >= 0.1:
		publish_time = 0
		_publish()

func _scan_candidate() -> Area3D:
	var best: Area3D = null
	var distance := INF
	for id in targets:
		if not rules.eligible(id): continue
		var target: Area3D = targets[id]
		var separation := driver.global_position.distance_to(target.global_position)
		if separation < distance:
			distance = separation
			best = target
	return best

func _cancel_tool() -> void:
	busy_id = ""
	busy_stage = ""
	busy_elapsed = 0
	if tool != null:
		tool.position = Vector3(1.05, 0.45, 1.15)
		tool.rotation.y = 0
	if tool_arm != null: tool_arm.hide()
	if dust != null: dust.emitting = false
	if kit != null and not rules.data.is_empty(): kit.visible = rules.data.stabilized

func _changed() -> void:
	if bound_state != null: bound_state.rover_training = rules.data
	if targets.is_empty() or rules.data.is_empty(): return
	shadow_patch.visible = rules.data.mission == 1
	for id in targets:
		var show_target := false
		match rules.data.mission:
			0: show_target = id in Rules.SURVEY or id == "uplink"
			1: show_target = id in Rules.READINGS or id in ["perimeter", "uplink"]
			2: show_target = id in ["search_area", "astronaut"]
		targets[id].visible = show_target
		if id == "astronaut": targets[id].caption.visible = rules.data.scans.has(id)
		elif id == "search_area": targets[id].visible = show_target and not rules.data.scans.has("astronaut")
		targets[id].marker.scale = Vector3.ONE * (1.5 if rules.data.best == id else 1.0)
		targets[id].caption.modulate = Color("91edae") if rules.data.scans.has(id) else Color.WHITE
	kit.visible = rules.data.stabilized
	kit.position = targets.astronaut.position + Vector3(0.9, 0.2, 0)
	relay.visible = rules.data.relay
	relay.position = targets.astronaut.position + Vector3(1.3, 0.75, 0)
	# The separate team's pickup is a radio handoff, not a rover passenger animation.
	astronaut.visible = not (rules.data.mission == 2 and rules.data.status == "success")
	astronaut.get_node("CrewBody").collision_layer = 1 if rules.data.mission == 2 and rules.data.status != "success" else 0
	_publish()

func _beacon() -> float:
	return clampf(1.0 - driver.global_position.distance_to(targets.astronaut.global_position) / 70.0, 0, 1)

func _publish() -> void:
	if hud == null: return
	var show_hud: bool = driver.active and driver.power_state == driver.Power.READY
	if rules.data.is_empty():
		hud_changed.emit({"visible": false})
		return
	var d := rules.data
	var target_id: String = rules.action_target()
	if target_id == "":
		var candidate := _scan_candidate()
		if candidate != null: target_id = candidate.target_id
	if d.stage == "search": target_id = "search_area"
	var objective: String = {"survey": "Hold F to map Alpha, Beta and Gamma.", "perimeter": "Reach the training perimeter. Turn on headlights (L), then press E.", "ice_scan": "Hold F to compare three hydrogen-proxy signals.", "search": "Distress call: lost communications near the east ridge. Follow the beacon; hold F to identify the astronaut."}.get(d.stage, rules.action_name() + " [E]")
	var details := ""
	if target_id != "":
		var distance: float = driver.global_position.distance_to(targets[target_id].global_position)
		details = "Target: %s · %.1f m\n" % [target_id.replace("_", " ").to_upper(), distance]
	if d.mission == 0:
		details += "Discovered sectors: %d / 3\n" % d.scans.size()
		for id in Rules.SURVEY: details += id.capitalize() + (" ✓   " if d.scans.has(id) else " —   ")
	elif d.mission == 1:
		details += "Training signal units (not ice concentration)\n"
		for id in Rules.READINGS: details += "%s: %s   " % [id.right(1).to_upper(), str(d.scans[id]) if d.scans.has(id) else "—"]
		details += "\nStrongest: " + ("pending all readings" if d.best == "" else "B · 78")
		details += "\nSIMULATED SHADOW REGION — not a mapped PSR"
		details += "\nTHERMAL WARNING: prolonged cold exposure" if d.cold_exposure >= 60.0 else "\nThermal: nominal / cold exposure %ds" % int(d.cold_exposure)
	else:
		details += "Beacon %d%% · Reserve %d:%02d\nKit: %s · Relay: %s\n" % [roundi(_beacon() * 100), int(d.remaining) / 60, int(d.remaining) % 60, "delivered / stable" if d.stabilized else "available", "online" if d.relay else "offline"]
		details += "Independent team handles pickup."
	var prompt_text := "F: hold scan · E: interact · L: lights\nBrake, face target, operate within 6.5 m."
	if feedback != "": prompt_text += "\n" + feedback
	if d.battery <= 20.0: prompt_text += "\nLOW BATTERY — complete the uplink soon."
	var outcome: String = d.message
	if d.status == "success": outcome = "MISSION COMPLETE\n" + outcome + ("\nEnter: next mission" if d.mission < 2 else "\nTraining complete. R: return to lander.")
	elif d.status == "failed": outcome = "MISSION FAILED\n" + outcome + "\nEnter: retry from deployment pad · R: return"
	var amount := scanner.progress / scan_seconds
	if busy_id != "":
		amount = busy_elapsed / busy_duration
		prompt_text = ("Drilling sample…" if busy_elapsed < 3.0 else "Analyzing sample…") if busy_stage == "sample" else rules.action_name() + "…"
	hud_changed.emit({"visible": show_hud, "title": Rules.TITLES[d.mission], "objective": objective,
		"telemetry": "BAT %d%% · %.2f m/s · LIGHTS %s\nREMOTE LINK: CONNECTED · CAMERA: CHASE" % [ceili(d.battery), absf(driver.speed), "ON" if d.lights else "OFF"],
		"detail": details, "prompt": prompt_text, "progress": amount, "result": outcome})

func _tone(frequency: float, seconds: float) -> void:
	# Procedural onboard telemetry cues, routed through the existing Effects bus.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(seconds * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var envelope := sin(PI * float(i) / count)
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * i / stream.mix_rate) * envelope * 12000))
	stream.data = bytes
	sound.stream = stream
	sound.play()
