extends Node3D
## One physical rover and five existing crew identities across connected locations.
signal hud_changed(view: Dictionary)
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Terrain = preload("res://src/world/expedition_terrain.gd")
const Target = preload("res://src/world/rover_scan_target.gd")
const Circle = preload("res://src/world/expedition_circle.gd")
const Fit = preload("res://src/world/imported_asset_fit.gd")
var scanner := preload("res://src/world/rover_scanner.gd").new()
var driver: Node3D
var session: Node
var bound_state: RefCounted
var data: Dictionary = {}
var targets := {}
var droplets := {}
var landscape: Node3D
var departure: Node3D
var extraction: Node3D
var crew: Node3D
var crew_home: Transform3D
var crew_visual: Node3D
var crew_player: AnimationPlayer
var seat_pose := preload("res://src/world/astronaut_seated_pose.gd").new()
var seated := false
var arm: Node3D
var hud: CanvasLayer
var fade: ColorRect
var lights: SpotLight3D
var transitioning := false
var armed := true
var dwell := 0.0
var busy_id := ""
var busy_elapsed := 0.0
var elapsed := 0.0
var feedback := ""
var dialogue := 0.0
var sound: AudioStreamPlayer
var last_sol := -1
var cinematic_camera: Camera3D
var cinematic_bars: Array[ColorRect] = []
var follower: CharacterBody3D
var stuck_time := 0.0
var generation := 0
var transition_tween: Tween
var motor: AudioStreamPlayer
var cinematic_motion := false
var escort_link := false

func _ready() -> void:
	driver = get_parent().get_node("RoverHull")
	session = get_node("/root/MissionSession")
	landscape = preload("res://scenes/rover_expedition.tscn").instantiate()
	add_child(landscape)
	departure = Circle.new()
	add_child(departure)
	departure.position = Vector3(32,0,12)
	_label_circle(departure,"EXPEDITION DEPARTURE\nStop in the circle")
	extraction = Circle.new()
	add_child(extraction)
	extraction.position = Terrain.ORIGIN
	_label_circle(extraction,"RETURN TO OUTPOST\nStop in the circle")
	for id in Terrain.SITES:
		var target := Target.new()
		target.setup(id,{"alpha":"FRACTURED PLAIN","beta":"WEST RIDGE","gamma":"CRATER RIM"}.get(id,""),Color("84dce8"))
		add_child(target)
		target.position = Terrain.point(Terrain.SITES[id])
		targets[id] = target
		if id.begins_with("ice"):
			target.caption.hide()
			target.marker.hide()
			var bob := Node3D.new()
			target.add_child(bob)
			var model := preload("res://Assets/expedition/water_droplet.glb").instantiate()
			bob.add_child(model)
			Fit.fit(model,1.5)
			droplets[id] = bob
	var target := Target.new()
	target.setup("astronaut","",Color.WHITE)
	add_child(target)
	target.marker.hide()
	target.caption.hide()
	targets.astronaut = target
	crew = get_parent().get_node("Outpost/crew_briefing")
	for pair in [["Astronaut","player"],["crew_briefing","commander"],["power_console","engineer"],["water_recycler","medic"],["food_storage","botanist"]]:
		get_parent().get_node("Outpost/"+pair[0]).set_meta("crew_id",pair[1])
	crew.get_node("CrewBody").set_meta("rover_target","astronaut")
	crew_home = crew.transform
	crew_visual = crew.get_node("StationAstronaut")
	crew_player = crew_visual.find_children("*","AnimationPlayer",true,false)[0]
	crew_player.get_animation("moon_walk").loop_mode = Animation.LOOP_LINEAR
	follower = CharacterBody3D.new()
	follower.name = "RescuedCrewPhysics"
	follower.set_meta("rover_target","astronaut")
	follower.floor_snap_length = 0.8
	follower.floor_max_angle = deg_to_rad(32)
	follower.collision_layer = 0
	follower.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	follower.add_child(shape)
	add_child(follower)
	arm = preload("res://src/world/rover_sample_arm.gd").new()
	driver.rover.add_child(arm)
	arm.setup(driver.rover.get_node("ImportedRover"))
	hud = preload("res://src/ui/rover_training_hud.gd").new()
	add_child(hud)
	hud_changed.connect(hud.render)
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	fade = ColorRect.new()
	fade.color = Color(0,0,0,0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar.anchor_top = 0.88 if bottom else 0.0
		bar.anchor_bottom = 1.0 if bottom else 0.12
		bar.hide()
		cinematic_bars.append(bar)
	lights = SpotLight3D.new()
	lights.position = Vector3(0,0.9,1.4)
	lights.rotation = Vector3(deg_to_rad(-15),PI,0)
	lights.spot_range = 35
	lights.light_energy = 8
	lights.shadow_enabled = true
	driver.add_child(lights)
	lights.hide()
	sound = AudioStreamPlayer.new()
	sound.bus = "Gameplay_SFX"
	add_child(sound)
	motor = AudioStreamPlayer.new()
	motor.stream = preload("res://Assets/audio/sfx/rover_start.mp3").duplicate()
	motor.stream.loop = true
	motor.bus = "Gameplay_SFX"
	motor.volume_db = -80
	add_child(motor)
	motor.play()
	if not InputMap.has_action("rover_scan"):
		InputMap.add_action("rover_scan")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		InputMap.action_add_event("rover_scan",key)
	_sync()
	call_deferred("_ground_departure")

func _label_circle(circle: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position.y = 2.5
	label.font_size = 30
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d4b3ff")
	circle.add_child(label)

func _ground_departure() -> void:
	if not is_inside_tree(): return
	await get_tree().physics_frame
	if not is_inside_tree(): return
	departure.position.y = ground_y(departure.position)
	departure.conform_to_ground(ground_y)
	extraction.conform_to_ground(ground_y)

func ground_y(p: Vector3) -> float:
	if not is_inside_tree(): return p.y
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*80,p-Vector3.UP*80,1,[driver.get_rid(),crew.get_node("CrewBody").get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else p.y

func _sync() -> void:
	if bound_state == session.dashboard_state: return
	generation += 1
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
		transition_tween.finished.emit()
	transitioning = false
	cinematic_motion = false
	for bar in cinematic_bars: bar.hide()
	fade.color.a = 0
	departure.show()
	if is_instance_valid(cinematic_camera):
		cinematic_camera.queue_free()
		if driver.active: driver.camera.make_current()
	bound_state = session.dashboard_state
	busy_id = ""
	busy_elapsed = 0
	dialogue = 0
	escort_link = false
	motor.volume_db = -80
	scanner.reset()
	arm.pose(0)
	if bound_state == null:
		data = {}
		return
	if bound_state.rover_expedition.is_empty(): bound_state.rover_expedition = Rules.migrate(bound_state.rover_training)
	data = bound_state.rover_expedition
	_stand()
	last_sol = -1
	if data.phase == "returning":
		# A save in a fade/cinematic resumes at the last valid expedition location.
		data.location = "expedition"
		data.phase = "active"
		_place_rover(Terrain.ORIGIN+Vector3(0,0,9))
	_restore_crew()
	escort_link = data.stabilized and driver.position.distance_to(crew.position) < 25
	_refresh_targets()

func _restore_crew() -> void:
	if data.is_empty(): return
	var was_away := follower.collision_layer == 1
	data.missing = bound_state.sol >= 6 and not data.completed.has(2)
	if data.missing:
		if data.crew_position == Vector3.ZERO: data.crew_position = Terrain.point(Vector2(65,255))
		crew.global_position = data.crew_position
		follower.global_position = crew.global_position
		follower.collision_layer = 1
		crew.get_node("CrewBody").collision_layer = 0
		get_parent().get_node("CrewFieldwork")._release("crew_briefing")
		crew.rotation = Vector3.ZERO
		for node_name in ["StatusLabel","FieldworkLabel","FieldTool"]: crew.get_node(node_name).hide()
		crew.get_node("InteractionArea").monitoring = false
		if not data.stabilized and not seated:
			crew_player.play("idle",0)
			crew_player.advance(0)
			crew_player.pause()
			seat_pose.apply(crew_visual,crew)
			seated = true
	else:
		if was_away: _stand()
		follower.collision_layer = 0
		crew.get_node("CrewBody").collision_layer = 1
		if was_away: crew.transform = crew_home
		crew.get_node("StatusLabel").show()
		crew.get_node("FieldworkLabel").show()
		crew.get_node("InteractionArea").monitoring = true
		var fieldwork := get_parent().get_node("CrewFieldwork")
		if was_away and data.completed.has(2) and not fieldwork.data.is_empty():
			fieldwork.data.crew.crew_briefing.position = crew.position
			fieldwork.data.crew.crew_briefing.path = PackedVector3Array()
			fieldwork._finish("crew_briefing")
	targets.astronaut.position = crew.global_position

func _stand() -> void:
	if seated:
		seat_pose.restore(crew_visual)
		seated = false
	crew_player.play("idle")

func remote_ready() -> bool:
	return driver.active and driver.power_state == driver.Power.READY and not transitioning and not get_tree().paused and session.can_advance()

func developer_select_mission(index: int) -> bool:
	if not OS.is_debug_build() or not session.DEV_SOL_SKIP_ENABLED or index < 0 or index >= Rules.TITLES.size(): return false
	if get_tree().paused or transitioning or driver.active or session.action_busy: return false
	if not data.is_empty() and data.location != "outpost": return false
	if session.start_selected_mission() != OK: return false
	if session.dashboard_state.mission_outcome.status != "in_progress": return false
	var fresh: Dictionary = Rules.fresh()
	fresh.mission = index
	session.dashboard_state.rover_expedition = fresh
	session.dashboard_state.sol = maxi(session.dashboard_state.sol, Rules.SOLS[index])
	bound_state = null
	_sync()
	_refresh_targets()
	feedback = "DEV: selected " + Rules.TITLES[index] + ". Drive to departure."
	session.state_changed.emit()
	session.capture_sol_checkpoint()
	return true
func locks_drive() -> bool:
	return transitioning or busy_id != "" or dialogue > 0
func speed_limit(throttle: float = 0.0) -> float:
	if data.is_empty() or data.location != "expedition" or data.mission != 2 or not data.stabilized or not escort_link: return driver.MAX_SPEED
	var distance := driver.global_position.distance_to(crew.global_position)
	if distance >= 18 and throttle != 0:
		var direction := Vector3(sin(driver.heading),0,cos(driver.heading))*signf(throttle)
		if direction.dot((crew.position-driver.position).normalized()) > 0.25: return 0.35
	return 0.0 if distance >= 18 else (0.35 if distance > 12 else driver.MAX_SPEED)

func handle_key(key: int) -> void:
	if not remote_ready() or data.is_empty(): return
	if key == KEY_ENTER and data.location == "expedition":
		_recall()
		return
	if key == KEY_L: lights.visible = not lights.visible
	if key != KEY_E or data.location != "expedition" or busy_id != "" or dialogue > 0: return
	if data.mission == 1:
		var id := _nearest(true)
		if id == "": return
		feedback = scanner.validate(driver,targets[id])
		if feedback != "": return
		if Vector2(driver.position.x-targets[id].position.x,driver.position.z-targets[id].position.z).length() > 2.5:
			feedback = "Approach within 2.5 m so the existing sampling hand can reach the regolith."
			return
		busy_id = id
		busy_elapsed = 0
		_tone(150)
	elif data.mission == 2 and data.discovered and (not data.stabilized or not data.relay):
		feedback = scanner.validate(driver,targets.astronaut)
		if feedback != "": return
		data.stabilized = true
		data.relay = true
		escort_link = true
		data.route = PackedVector3Array([crew.global_position,driver.global_position])
		_stand()
		dialogue = 9
		feedback = "PLAYER: Emergency oxygen connected. Radio link restored.\nCREW: Breathing is steady. I can walk. Keep me in sight.\nCONTROL: Link confirmed. Escort them to extraction."
		_tone(700)
		session.capture_sol_checkpoint()

func _nearest(ice: bool) -> String:
	var best := ""
	var distance := INF
	for id in Terrain.SITES:
		if id.begins_with("ice") != ice or (id in data.samples if ice else id in data.surveys): continue
		var d: float = driver.position.distance_to(targets[id].position)
		if d < distance:
			distance = d
			best = id
	return best

func _physics_process(delta: float) -> void:
	_sync()
	if data.is_empty(): return
	var audible: bool = cinematic_motion or (driver.active and absf(driver.speed)>0.05) or busy_id != ""
	driver.repair_label.visible = not driver.active and not cinematic_motion
	motor.volume_db = move_toward(motor.volume_db,-28.0 if audible else -80.0,delta*35)
	elapsed += delta
	if last_sol != bound_state.sol:
		last_sol = bound_state.sol
		_restore_crew()
		var assignment := Rules.assigned(data,last_sol)
		if assignment >= 0: feedback = "NEW OPERATION AVAILABLE — " + Rules.TITLES[assignment]
	for id in droplets: droplets[id].position.y = 1.3 + sin(elapsed*1.7)*0.18
	if not remote_ready():
		scanner.reset()
		busy_id = ""
		arm.pose(0)
		_publish()
		return
	dialogue = maxf(0,dialogue-delta)
	if data.location == "expedition":
		if data.mission == 0:
			var id := _nearest(false)
			if id != "" and scanner.advance(delta,Input.is_action_pressed("rover_scan"),id,true,scanner.validate(driver,targets[id])):
				data.surveys.append(id)
				feedback = "SURVEY COMPLETE — %d / 3" % data.surveys.size()
				_tone(900)
				_refresh_targets()
				session.capture_sol_checkpoint()
		elif data.mission == 1 and busy_id != "":
			if scanner.validate(driver,targets[busy_id]) != "":
				busy_id = ""
				arm.pose(0)
			else:
				busy_elapsed += delta
				arm.pose(clampf(busy_elapsed/6,0,1))
				if busy_elapsed >= 6:
					data.samples.append(busy_id)
					busy_id = ""
					arm.pose(0)
					feedback = "ICE SAMPLE SECURED — %d / 3" % data.samples.size()
					_tone(900)
					_refresh_targets()
					session.capture_sol_checkpoint()
		elif data.mission == 2:
			targets.astronaut.position = crew.global_position
			if not data.discovered and scanner.validate(driver,targets.astronaut) == "":
				data.discovered = true
				feedback = "STRANDED ASTRONAUT LOCATED\nCritical oxygen. Press E to deliver oxygen and restore communications."
				session.capture_sol_checkpoint()
			if data.stabilized and not escort_link and driver.position.distance_to(crew.position) < 20:
				escort_link = true
				data.route = PackedVector3Array([crew.position,driver.position])
			if data.stabilized and escort_link and dialogue <= 0: _escort(delta)
		var local := driver.position - Terrain.ORIGIN
		if maxf(absf(local.x),absf(local.z)) > 390:
			feedback = "EXPEDITION LIMIT — turn back toward the operational zones."
	_check_circle(delta)
	_publish()

func _escort(delta: float) -> void:
	var route: PackedVector3Array = data.route
	if route.is_empty() or route[-1].distance_to(driver.position) > 2: route.append(driver.position)
	var distance := Vector2(crew.global_position.x-driver.position.x,crew.global_position.z-driver.position.z).length()
	if distance > 12: feedback = "WARNING: Astronaut falling behind. Reduce speed."
	elif feedback.begins_with("WARNING:"): feedback = "Escort the astronaut to extraction."
	# The last breadcrumb is still a destination. Requiring two points here
	# stranded the astronaut after consuming the initial rescue position.
	while route.size() > 1 and Vector2(crew.global_position.x-route[0].x,crew.global_position.z-route[0].z).length() < 1.2:
		route.remove_at(0)
	if not route.is_empty() and distance > 5:
		var goal: Vector3 = route[0]
		var direction := (goal-crew.global_position)
		direction.y = 0
		if direction.length() > 0.05:
			var before := follower.position
			follower.velocity.x = direction.normalized().x
			follower.velocity.z = direction.normalized().z
			follower.velocity.y -= 1.62*delta
			follower.move_and_slide()
			crew.global_position = follower.global_position
			stuck_time = stuck_time+delta if before.distance_to(follower.position) < delta*0.1 else 0.0
			if stuck_time > 3:
				# Retry the next nearby breadcrumb if its straight path is clear.
				if route.size() > 1 and route[1].distance_to(follower.position) < 6:
					var ray := PhysicsRayQueryParameters3D.create(follower.position+Vector3.UP,route[1]+Vector3.UP,1,[follower.get_rid(),driver.get_rid()])
					if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): route.remove_at(0)
				feedback = "Escort path obstructed. Stop and reverse along your approach to help the astronaut catch up."
			crew.rotation.y = lerp_angle(crew.rotation.y,atan2(-direction.x,-direction.z),delta*3)
			if crew_player.current_animation != "moon_walk": crew_player.play("moon_walk",0.3)
	else:
		if crew_player.current_animation != "idle": crew_player.play("idle",0.3)
	data.route = route
	data.crew_position = crew.global_position

func _recall() -> void:
	transitioning = true
	var token := generation
	var tween := create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",1.0,0.65)
	await tween.finished
	if token != generation: return
	_place_rover(Vector3(32,ground_y(Vector3(32,0,20)),20))
	data.location = "outpost"
	data.phase = "active"
	escort_link = false
	feedback = "Expedition suspended. Rover recovered to outpost. Repair or advance the Sol, then resume; objective progress retained."
	_refresh_targets()
	session.capture_sol_checkpoint()
	tween = create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",0.0,0.65)
	await tween.finished
	if token != generation: return
	transitioning = false
	armed = false

func _check_circle(delta: float) -> void:
	var circle := departure if data.location == "outpost" else extraction
	var distance := Vector2(driver.position.x-circle.position.x,driver.position.z-circle.position.z).length()
	if distance > 6:
		armed = true
		dwell = 0
		return
	if not armed or distance > 2.7 or absf(driver.speed) > 0.12:
		dwell = 0
		return
	dwell += delta
	if dwell < 0.8: return
	armed = false
	dwell = 0
	if data.location == "outpost":
		var assignment := Rules.assigned(data,bound_state.sol)
		if assignment < 0:
			feedback = "NO ACTIVE ROVER EXPEDITION — Awaiting the next scheduled operation."
			return
		data.mission = assignment
		_transition(true)
	else:
		if not Rules.ready_to_return(data):
			feedback = "Objectives remain incomplete. Progress is saved; finish the operation before extraction."
			armed = true
			return
		if data.mission == 2 and crew.global_position.distance_to(extraction.position) > 9:
			feedback = "Extraction unavailable. Wait for the rescued astronaut."
			armed = true
			return
		_transition(false)

func _place_rover(p: Vector3) -> void:
	driver.position = p + Vector3.UP*0.7
	driver.speed = 0
	driver.velocity = Vector3.ZERO
	driver.heading = 0
	driver.rotation.y = 0
	driver._sync_visual(1)
	driver._update_camera()
	bound_state.rover_pose = {"position":driver.position,"heading":driver.heading}

func _transition(outward: bool) -> void:
	if transitioning: return
	transitioning = true
	var token := generation
	driver.speed = 0
	driver.velocity = Vector3.ZERO
	data.phase = "active" if outward else "returning"
	var tween := create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",1.0,0.65)
	await tween.finished
	if token != generation: return
	if outward:
		data.location = "expedition"
		_place_rover(Terrain.ORIGIN + Vector3(0,0,10))
	else:
		if data.mission == 2:
			await _arrival()
			if token != generation: return
		else:
			_place_rover(Vector3(32,ground_y(Vector3(32,0,20)),20))
		data.location = "outpost"
		if not data.completed.has(data.mission): data.completed.append(data.mission)
		feedback = Rules.TITLES[data.mission].to_upper()+" COMPLETE"
		if data.mission == 2: feedback += "\nMissing crew member recovered.\nAll five astronauts accounted for."
		data.mission = -1
		data.phase = "completed"
		_restore_crew()
	_refresh_targets()
	session.capture_sol_checkpoint()
	tween = create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",0.0,0.65)
	await tween.finished
	if token != generation: return
	transitioning = false
	armed = false

func _arrival() -> void:
	var token := generation
	cinematic_motion = true
	for bar in cinematic_bars: bar.show()
	hud.hide()
	driver.overlay.hide()
	driver.repair_label.hide()
	departure.hide()
	# Existing outpost's eastern raised terrain supplies the distant approach.
	_place_rover(Vector3(38,ground_y(Vector3(38,0,26)),26))
	driver.heading = atan2(-14,-8)
	driver._sync_visual(1.0)
	crew.global_position = driver.position + Vector3(2.4,0,-3.8)
	crew.position.y = ground_y(crew.position)
	_stand()
	crew_player.play("moon_walk",0.2)
	cinematic_camera = Camera3D.new()
	add_child(cinematic_camera)
	cinematic_camera.fov = 48
	_frame_arrival(0.0)
	cinematic_camera.make_current()
	var tween := create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",0.0,0.6)
	await tween.finished
	if token != generation: return
	var start := driver.position
	var t := 0.0
	while t < 16:
		await get_tree().physics_frame
		if token != generation: return
		if get_tree().paused: continue
		var delta := get_physics_process_delta_time()
		t += delta
		var p := start.lerp(Vector3(24,0,18),clampf(t/16,0,1))
		p.y = ground_y(p)+0.7
		var previous: Vector3 = driver.position
		driver.position = p
		driver.heading = atan2(-14,-8)
		driver._sync_visual(delta)
		driver.rover.get_node("Wheels").update_motion(previous.distance_to(p),0,2.2)
		crew.global_position = p + Vector3(2.4,0,-3.8)
		crew.position.y = ground_y(crew.position)
		crew.rotation.y = atan2(14,8)
		_frame_arrival(clampf(t/16,0,1))
	tween = create_tween()
	transition_tween = tween
	tween.tween_property(fade,"color:a",1.0,0.5)
	await tween.finished
	if token != generation: return
	_place_rover(Vector3(32,ground_y(Vector3(32,0,20)),20))
	driver.camera.make_current()
	cinematic_camera.queue_free()
	cinematic_motion = false
	for bar in cinematic_bars: bar.hide()
	driver.overlay.show()
	departure.show()

func _frame_arrival(progress: float) -> void:
	var forward := Vector3(-14,0,-8).normalized()
	var side := Vector3(-forward.z,0,forward.x)
	var focus: Vector3 = (driver.rover.global_position + crew.global_position) * 0.5 + Vector3.UP * 1.1
	# A distant front three-quarter shot tracks backward with the returning crew.
	var position_ := driver.global_position + forward * lerpf(20,17,progress) + side * 4
	position_.y = maxf(ground_y(position_) + 4.5, focus.y + 3.5)
	# Keep intervening ridges out of the sightline as well as staying above the
	# terrain directly beneath the camera. Heights are never fixed world values.
	for attempt in range(6):
		var ray := PhysicsRayQueryParameters3D.create(focus,position_,1,[driver.get_rid(),crew.get_node("CrewBody").get_rid(),follower.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): break
		position_.y += 1.5
	cinematic_camera.global_position = position_
	cinematic_camera.look_at(focus)

func _refresh_targets() -> void:
	if data.is_empty(): return
	for id in Terrain.SITES:
		targets[id].visible = data.location == "expedition" and ((data.mission == 0 and not id.begins_with("ice") and id not in data.surveys) or (data.mission == 1 and id.begins_with("ice") and id not in data.samples))

func _publish() -> void:
	var assignment := Rules.assigned(data,bound_state.sol)
	var title: String = "ROVER EXPEDITIONS" if assignment < 0 else Rules.TITLES[assignment]
	var objective := "Drive to the violet departure circle. Stop at its center."
	var details := "Sol 2: Surface Survey · Sol 4: Frozen Horizon\nSol 6: Lifeline"
	var prompt := "WASD: drive · Space: brake · R: lander · L: lights"
	if bound_state.rover_health <= 0: prompt = "Enter: recover disabled rover to outpost for repair."
	if data.location == "expedition":
		if data.mission == 0:
			objective = "Investigate three geological formations."
			details = "Geological sites surveyed: %d / 3" % data.surveys.size()
			prompt = "Brake, face the site within 6.5 m, hold F to survey."
		elif data.mission == 1:
			objective = "Investigate subsurface ice-bearing regolith."
			details = "Potential ice deposits sampled: %d / 3\nInspect the shadowed regolith. L: headlights." % data.samples.size()
			prompt = "Brake, face a droplet within 2.5 m, press E to sample."
		else:
			objective = "Search beyond the eastern saddle for the missing crew member."
			details = "Crew: four at outpost, one missing.\nCritical oxygen — locate and assist the astronaut."
			prompt = "Approach carefully. E: emergency oxygen and communications."
			if data.stabilized:
				objective = "Escort the astronaut on foot to extraction."
				details = "Oxygen: stable · Radio: connected\nKeep within 12 m; stop if they fall behind."
		if data.mission < 2:
			var id := _nearest(data.mission == 1)
			if id != "": details += "\nNext science site: %.0f m · bearing %.0f°" % [driver.position.distance_to(targets[id].position),rad_to_deg(atan2(targets[id].position.x-driver.position.x,targets[id].position.z-driver.position.z))]
		if Rules.ready_to_return(data):
			objective = "Return to extraction" if data.mission < 2 else "Escort the astronaut to extraction"
			details += "\nExtraction: %.0f m · bearing %.0f°" % [driver.position.distance_to(extraction.position),rad_to_deg(atan2(extraction.position.x-driver.position.x,extraction.position.z-driver.position.z))]
		prompt += "\nEnter: suspend expedition and recover rover."
	if bound_state.rover_health <= 0: prompt = "Enter: recover disabled rover to outpost for repair."
	hud_changed.emit({"visible":driver.active and driver.power_state == driver.Power.READY and not transitioning,"title":title,"objective":objective,"telemetry":"SOL %d · HEADING %.0f° · LINK CONNECTED" % [bound_state.sol,rad_to_deg(driver.heading)],"detail":details,"prompt":prompt,"progress":busy_elapsed/6 if busy_id != "" else scanner.progress/scanner.duration,"result":feedback,"navigation":_navigation()})

func _navigation() -> Dictionary:
	if data.location != "expedition": return {}
	var destination: Vector3 = extraction.global_position
	var label := "EXTRACTION"
	if not Rules.ready_to_return(data):
		if data.mission < 2:
			var id := _nearest(data.mission == 1)
			if id == "": return {}
			destination = targets[id].global_position
			label = id.replace("_", " ").to_upper()
		else:
			destination = Terrain.point(Vector2(60, 230))
			label = "SEARCH AREA"
	var camera: Camera3D = driver.camera
	var size := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(destination + Vector3.UP * 2) - Vector2(140, 0)
	var behind := camera.is_position_behind(destination)
	if behind:
		var side: float = (destination-camera.global_position).dot(camera.global_basis.x)
		screen = Vector2(size.x-300 if side >= 0 else 30, size.y*0.55)
	var edge := behind or screen.x < 30 or screen.x > size.x-300 or screen.y < 110 or screen.y > size.y-100
	screen = screen.clamp(Vector2(30,110),Vector2(maxf(31,size.x-300),maxf(111,size.y-100)))
	if screen.x + 280 > size.x - 420 and screen.y < size.y * 0.6:
		screen.y = size.y * 0.65
	var arrow := ("▶ " if screen.x > size.x*0.5 else "◀ ") if edge else "▼ "
	return {"screen":screen,"label":arrow+label+" · %.0f m" % driver.global_position.distance_to(destination)}

func _tone(frequency: float) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(6615*2)
	for i in range(6615): bytes.encode_s16(i*2,int(sin(TAU*frequency*i/22050.0)*sin(PI*i/6615.0)*5000))
	stream.data = bytes
	sound.stream = stream
	sound.play()
