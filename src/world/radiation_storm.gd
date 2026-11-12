extends Node3D
## Radiation wave between Surface Survey and Frozen Horizon. Runs the countdown while the
## Commander orders the crew into the radiation habitat, hides sheltered crew, charges
## the exposure once when the wave hits, and shows the wave: glowing particle fronts
## sweeping in from the Sun in solar-flare orange, a warm tint and a flashing warning sign.
const Rules = preload("res://src/simulation/rover_expedition.gd")
const UI = preload("res://src/ui/ui_style.gd")
const ORDERS_SECONDS := 75.0 # Time to reach every crew member (paused during dialogue).
const PREP_SECONDS := 150.0 # After Maya's advice: time to build before the wave is detected.
const COMMS_EXTRA_SECONDS := 60.0 # A Comms Relay's early warning adds this to the orders.
const WAVE_SECONDS := 15.0
const FRONT_PERIOD := 5.0 # One particle front sweeps over the base every 5 s.
## Solar-flare colours: hot yellow-white fronts burning to orange-red at their edges.
const WAVE_TINT := Color(1.0, 0.5, 0.12)
const WAVE_HOT := Color(1.0, 0.88, 0.5)
const FLASH_PERIOD := 0.5
const FLASH_TINT := Color(1.0, 0.42, 0.12)
const FRONT_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float opacity = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 hot : source_color = vec3(1.0, 0.88, 0.5);
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float bands = 0.55 + 0.45 * sin(UV.y * 90.0 - TIME * 5.0);
	ALBEDO = mix(hot, tint, clamp(rim * 1.6, 0.0, 1.0)) * bands;
	ALPHA = clamp(opacity * (0.12 + rim * 0.6), 0.0, 1.0);
}
"""
var session: Node
var world: Node3D
var expeditions: Node
var environment: Environment
var sun: DirectionalLight3D
var original: Dictionary = {}
var sun_color := Color.WHITE
var fronts: Array[MeshInstance3D] = []
var sign_layer: CanvasLayer
var warning_sign: Control
var active := false
var bound_data: Dictionary = {}
var hidden_crew: Dictionary = {} # crew id -> true while hidden in the habitat
const WALK_SPEED := 1.6 # Ordered crew walk to the habitat door, then go inside.
var player_inside := false
var shelter_camera: Camera3D
var previous_camera: Camera3D
var door_hint: Label

func _ready() -> void:
	name = "RadiationStorm"
	world = get_parent()
	session = get_node("/root/MissionSession")
	expeditions = world.get_node("RoverTraining")
	environment = world.get_node("LunarEnvironment").environment
	sun = world.get_node_or_null("LowPolarSun")
	var shader := Shader.new()
	shader.code = FRONT_SHADER
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	for i in 3:
		var front := MeshInstance3D.new()
		front.mesh = sphere
		front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", WAVE_TINT)
		material.set_shader_parameter("hot", WAVE_HOT)
		front.material_override = material
		front.hide()
		add_child(front)
		fronts.append(front)
	sign_layer = CanvasLayer.new()
	sign_layer.layer = 58 # Above the HUD, below the pause menu.
	add_child(sign_layer)
	var hazard := VBoxContainer.new()
	hazard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hazard.add_theme_constant_override("separation", 2)
	sign_layer.add_child(hazard)
	hazard.anchor_left = 1.0
	hazard.anchor_right = 1.0
	hazard.offset_left = -164.0
	hazard.offset_right = -22.0
	hazard.offset_top = 20.0
	var triangle := preload("res://src/world/dust_storm.gd").WarningTriangle.new()
	triangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	triangle.custom_minimum_size = Vector2(76, 64)
	triangle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hazard.add_child(triangle)
	var font := UI.objective_font()
	for line in [["Warning", 15], ["Radiation wave", 20]]:
		var text := UI.objective_label(font, line[1])
		text.text = line[0]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hazard.add_child(text)
	warning_sign = hazard
	sign_layer.hide()

func shelter_built() -> bool:
	var state: Variant = session.dashboard_state
	return state != null and state.built_structures.has("shielding_wall")

func comms_built() -> bool:
	var state: Variant = session.dashboard_state
	return state != null and state.built_structures.has("comms_relay")

func orders_seconds() -> float:
	return ORDERS_SECONDS + (COMMS_EXTRA_SECONDS if comms_built() else 0.0)

func seconds_left() -> int:
	return ceili(maxf(0.0, orders_seconds() - float(expeditions.data.get("radiation_elapsed", 0.0))))

## Seconds until the wave is detected (the Comms Relay shows this early warning).
func incoming_seconds_left() -> int:
	return ceili(maxf(0.0, PREP_SECONDS - float(expeditions.data.get("radiation_prep_elapsed", 0.0))))

## After Maya's preparation advice the Commander has PREP_SECONDS to build.
func begin_incoming() -> void:
	var data: Dictionary = expeditions.data
	if Rules.radiation(data) != "prep": return
	data["radiation"] = "incoming"
	data["radiation_prep_elapsed"] = 0.0
	session.capture_sol_checkpoint()
	session.state_changed.emit()

## Nearest crew member still to be ordered into the habitat (null when none).
func next_crew_position(from: Vector3) -> Variant:
	var best: Variant = null
	for id in Rules.RADIATION_CREW:
		if expeditions.data.get("radiation_told", []).has(id): continue
		var at: Vector3 = world.get_node("Outpost/" + id).global_position
		if best == null or from.distance_to(at) < from.distance_to(best): best = at
	return best

func begin_orders() -> void:
	var data: Dictionary = expeditions.data
	if Rules.radiation(data) != "alert": return
	data["radiation"] = "orders"
	data["radiation_told"] = []
	data["radiation_elapsed"] = 0.0
	session.capture_sol_checkpoint()
	session.state_changed.emit()

func order_into_shelter(id: String) -> void:
	var data: Dictionary = expeditions.data
	if Rules.radiation(data) != "orders" or data.get("radiation_told", []).has(id): return
	var told: Array = data.get("radiation_told", []).duplicate()
	told.append(id)
	data["radiation_told"] = told
	session.capture_sol_checkpoint()
	session.state_changed.emit()

## The wave hits: the stage change and the exposure charge happen together, once.
func start_wave() -> void:
	var data: Dictionary = expeditions.data
	if Rules.radiation(data) not in ["alert", "orders"]: return
	# Only crew who actually reached the habitat are sheltered; anyone still outside is exposed.
	var sheltered: int = data.get("radiation_inside", []).size() if shelter_built() else 0
	data["radiation"] = "wave"
	data["radiation_elapsed"] = 0.0
	session.apply_radiation_wave(Rules.RADIATION_CREW.size() - sheltered)

func _process(delta: float) -> void:
	var data: Dictionary = expeditions.data
	var stage := Rules.radiation(data)
	_sync_crew(data.get("radiation_inside", []) if shelter_built() and stage in ["orders", "wave"] else [])
	_update_player_shelter(stage)
	if stage in ["orders", "wave"] and shelter_built() and not get_tree().paused:
		_walk_to_shelter(delta)
		if stage == "orders" and data.get("radiation_inside", []).size() >= Rules.RADIATION_CREW.size():
			start_wave()
			return
	if active and (data != bound_data or stage != "wave"):
		_restore()
	if get_tree().paused or session.dashboard_state == null: return
	if stage == "incoming":
		if world.maya_dialogue_active: return
		data["radiation_prep_elapsed"] = float(data.get("radiation_prep_elapsed", 0.0)) + delta
		if float(data.radiation_prep_elapsed) >= PREP_SECONDS:
			data["radiation"] = "alert" # Maya now comes to warn the Commander.
			session.capture_sol_checkpoint()
			session.state_changed.emit()
		return
	if stage == "orders":
		# The countdown waits while someone is talking.
		if world.maya_dialogue_active: return
		data["radiation_elapsed"] = float(data.get("radiation_elapsed", 0.0)) + delta
		if float(data.radiation_elapsed) >= orders_seconds(): start_wave()
		return
	if stage != "wave": return
	if not active:
		bound_data = data
		for key in ["fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "fog_sky_affect", "ambient_light_color"]:
			original[key] = environment.get(key)
		if sun != null: sun_color = sun.light_color
		active = true
		sign_layer.show()
	var elapsed := minf(WAVE_SECONDS, float(data.get("radiation_elapsed", 0.0)) + delta)
	data["radiation_elapsed"] = elapsed
	var intensity := smoothstep(0.0, 1.5, elapsed) * (1.0 - smoothstep(WAVE_SECONDS - 2.0, WAVE_SECONDS, elapsed))
	environment.fog_enabled = true
	environment.fog_density = lerpf(float(original.fog_density), 0.025, intensity)
	environment.fog_light_color = WAVE_TINT.darkened(0.5)
	environment.fog_light_energy = 0.7
	environment.fog_sky_affect = intensity * 0.35
	environment.ambient_light_color = Color(original.ambient_light_color).lerp(WAVE_TINT, intensity * 0.5)
	if sun != null: sun.light_color = sun_color.lerp(WAVE_HOT, intensity * 0.5)
	var pulse := 1.0 - smoothstep(0.0, 0.25, fposmod(elapsed, FLASH_PERIOD))
	warning_sign.modulate = Color.WHITE.lerp(FLASH_TINT, pulse * 0.6)
	warning_sign.modulate.a = clampf(intensity * 1.5, 0.0, 1.0)
	_sweep_fronts(elapsed, intensity)
	if elapsed >= WAVE_SECONDS:
		data["radiation"] = "done"
		_leave_shelter()
		_restore()
		session.capture_sol_checkpoint()
		session.state_changed.emit()

## Particle fronts grow out of the Sun's direction and sweep past the camera.
func _sweep_fronts(elapsed: float, intensity: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var reduced: bool = session.reduce_motion
	for i in fronts.size():
		var front := fronts[i]
		front.visible = camera != null
		if camera == null: continue
		var toward_sun := Vector3(0.6, 0.15, -0.8).normalized()
		if sun != null: toward_sun = sun.global_basis.z.normalized()
		var source := camera.global_position + toward_sun * 260.0
		# Reduced motion: one steady front surrounding the camera instead of sweeps.
		# (Scale 400 keeps the camera, 260 from the centre, well inside that front.)
		var phase := 0.95 if reduced else fposmod(elapsed / FRONT_PERIOD + float(i) / fronts.size(), 1.0)
		front.global_position = source
		front.scale = Vector3.ONE * lerpf(20.0, 420.0, phase)
		var fade := sin(phase * PI) if not reduced else (0.6 if i == 0 else 0.0)
		front.material_override.set_shader_parameter("opacity", intensity * fade * 0.9)

## Sheltered crew are inside the habitat: hidden, untouchable and not interactive.
## Standable entry points around the habitat (open regolith clear of the mound, rocks and
## other structures), nearest to `from` first. Empty only when nothing around it is open.
func door_candidates(from: Vector3) -> Array[Vector3]:
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
	var model := shelter.get_node_or_null("NASAModel")
	var hull: Vector3 = model.get_meta("hull_size") if model != null and model.has_meta("hull_size") else Vector3(13, 4, 13)
	var routes: RefCounted = world.get_node("CrewFieldwork").route_service
	routes.refresh_layout()
	var found: Array[Vector3] = []
	for margin in [DOOR_MARGIN, DOOR_MARGIN + 1.0, DOOR_MARGIN + 2.2]:
		for step in DOOR_DIRECTIONS:
			var outward := Vector3(maxf(hull.x, hull.z) * 0.5 + margin, 0, 0).rotated(Vector3.UP, TAU * step / DOOR_DIRECTIONS)
			var spot: Array = routes.standing(shelter.global_position + outward)
			if spot[1]: found.append(spot[0])
		if found.size() >= 4: break # Enough open sides: no need to search farther out.
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(from) < b.distance_to(from))
	return found

## Where someone at `from` enters the habitat: the nearest standable point around it
## (the side facing them only if that side is open ground).
func shelter_door(from: Vector3) -> Vector3:
	var candidates := door_candidates(from)
	if not candidates.is_empty(): return candidates[0]
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
	var outward := from - shelter.global_position
	outward.y = 0.0
	if outward.length() < 0.01: outward = shelter.global_basis.z
	return shelter.global_position + outward.normalized() * (6.5 + DOOR_MARGIN)

const DOOR_DIRECTIONS := 16
const DOOR_MARGIN := 1.6
const PLAYER_EXIT_EXTRA := 3.0
const ROUTE_RETRY_SECONDS := 1.0
var shelter_paths: Dictionary = {} # crew id -> remaining waypoints to the door
var route_waits: Dictionary = {} # crew id -> [seconds until the next route search]

## Ordered crew walk to the habitat along checked crew routes (around structures, never
## through them); at its door they go inside (hidden until the wave passes).
func _walk_to_shelter(delta: float) -> void:
	var data: Dictionary = expeditions.data
	var inside: Array = data.get("radiation_inside", []).duplicate()
	var fieldwork := world.get_node("CrewFieldwork")
	for id in data.get("radiation_told", []):
		if inside.has(id): continue
		var actor := world.get_node("Outpost/" + id) as Node3D
		if not shelter_paths.has(id):
			var wait: Array = route_waits.get(id, [0.0])
			wait[0] -= delta
			route_waits[id] = wait
			if wait[0] > 0.0: continue
			fieldwork.route_service.routing_crew.clear()
			# Nearest open entry first; if no route reaches it, try the next few round the mound.
			var path := PackedVector3Array()
			var tries := 0
			for door in door_candidates(actor.global_position):
				path = fieldwork.route_service.route(actor.position, actor.get_parent().to_local(door))
				tries += 1
				if not path.is_empty() or tries >= 4: break
			if path.is_empty():
				# No teleporting: they keep trying, and the Commander is told why they are stuck.
				wait[0] = ROUTE_RETRY_SECONDS
				fieldwork.path_failed(id, "to the radiation habitat")
				continue
			shelter_paths[id] = path
		var waypoints: PackedVector3Array = shelter_paths[id]
		if waypoints.is_empty():
			shelter_paths.erase(id)
			route_waits.erase(id)
			inside.append(id)
			continue
		var next: Vector3 = waypoints[0]
		var after := actor.position.move_toward(next, WALK_SPEED * delta)
		var ground_hit: Dictionary = fieldwork.route_service.ground(after)
		if not ground_hit.is_empty(): after.y = ground_hit.position.y
		if Vector2(after.x - actor.position.x, after.z - actor.position.z).length() > 0.001:
			# Face the way they walk (-Z forward), as CrewFieldwork turns walking crew.
			actor.rotation.y = atan2(actor.position.x - next.x, actor.position.z - next.z)
		actor.position = after
		fieldwork.data.crew[id].position = after
		fieldwork._update_visual(id, true)
		if Vector2(after.x - next.x, after.z - next.z).length() < 0.05:
			waypoints.remove_at(0)
			shelter_paths[id] = waypoints
	if inside.size() != data.get("radiation_inside", []).size():
		data["radiation_inside"] = inside
		session.capture_sol_checkpoint()

## After the wave everyone steps out on the base side of the habitat, spread along its
## edge so nobody overlaps, then walks back to their work.
func _leave_shelter() -> void:
	var data: Dictionary = expeditions.data
	var fieldwork := world.get_node("CrewFieldwork")
	var leaving: Array = data.get("radiation_inside", [])
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall") if shelter_built() else null
	for index in leaving.size():
		var id: String = leaving[index]
		var actor := world.get_node("Outpost/" + id) as Node3D
		if shelter != null:
			var spot := exit_spot(index, leaving.size())
			var local: Vector3 = actor.get_parent().to_local(spot)
			var ground_hit: Dictionary = fieldwork.route_service.ground(local)
			# Never step out into a structure built beside the habitat.
			actor.position = fieldwork.route_service.free_spot(ground_hit.position if not ground_hit.is_empty() else local)
			fieldwork.data.crew[id].position = actor.position
		fieldwork.return_to_base(id)
	data["radiation_inside"] = []
	shelter_paths.clear()
	route_waits.clear()
	_exit_player_shelter()

## Where crew member `index` of `count` steps out: around the habitat edge facing the
## lander, 35 degrees apart (about 4.5 m at a 13 m habitat).
func exit_spot(index: int, count: int) -> Vector3:
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
	var base: Vector3 = world.get_node("Outpost/Habitat").global_position
	var door := shelter_door(base)
	var offset := shelter.global_position
	var arm := door - offset
	return offset + arm.rotated(Vector3.UP, deg_to_rad(35.0) * (float(index) - float(count - 1) * 0.5))

## The Commander may shelter too: E at the door watches the wave through the habitat window.
func _update_player_shelter(stage: String) -> void:
	if door_hint == null:
		var hint_layer := CanvasLayer.new()
		hint_layer.layer = 58
		add_child(hint_layer)
		door_hint = UI.objective_label(UI.objective_font(), 18)
		door_hint.position = Vector2(40, 260)
		hint_layer.add_child(door_hint)
	var player := world.get_node("Outpost/Astronaut")
	var near := false
	if stage in ["orders", "wave"] and shelter_built() and not player_inside and not player.seated:
		near = player.global_position.distance_to(shelter_door(player.global_position)) < 3.5
	door_hint.text = "E: leave the radiation habitat" if player_inside else ("E: enter the radiation habitat" if near else "")
	door_hint.visible = not door_hint.text.is_empty()
	if player_inside and stage not in ["orders", "wave"]: _exit_player_shelter()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E): return
	if door_hint == null or not door_hint.visible or get_tree().paused: return
	var player := world.get_node("Outpost/Astronaut")
	if player.nearby_interactable != null and not player_inside: return # Talking to crew comes first.
	get_viewport().set_input_as_handled()
	if player_inside: _exit_player_shelter()
	else: _enter_player_shelter()

func _enter_player_shelter() -> void:
	var player := world.get_node("Outpost/Astronaut")
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
	if shelter == null: return
	player_inside = true
	player.ui_blocked = true
	player.hide()
	previous_camera = get_viewport().get_camera_3d()
	# A window on the base side of the mound, looking out over the outpost.
	var base: Vector3 = world.get_node("Outpost/Habitat").global_position
	var window := shelter_door(base) + Vector3.UP * 2.2
	shelter_camera = Camera3D.new()
	shelter_camera.name = "ShelterWindowCamera"
	shelter_camera.fov = 70.0
	world.add_child(shelter_camera)
	shelter_camera.global_position = window
	shelter_camera.look_at(base + Vector3.UP * 1.5, Vector3.UP)
	shelter_camera.make_current()

func _exit_player_shelter() -> void:
	if not player_inside: return
	player_inside = false
	var player := world.get_node("Outpost/Astronaut")
	if shelter_built():
		# 3 m beyond the crew's exit spots (which surround the base-side door), so the
		# Commander never lands on a crew member.
		var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
		var door := shelter_door(world.get_node("Outpost/Habitat").global_position)
		var outward := door - shelter.global_position
		outward.y = 0.0
		var exit := door + outward.normalized() * PLAYER_EXIT_EXTRA
		var routes: RefCounted = world.get_node("CrewFieldwork").route_service
		var ground_hit: Dictionary = routes.ground(exit)
		player.global_position = routes.free_spot(ground_hit.position if not ground_hit.is_empty() else exit) + Vector3.UP * 0.2
	player.show()
	player.ui_blocked = false
	if is_instance_valid(previous_camera): previous_camera.make_current()
	if is_instance_valid(shelter_camera): shelter_camera.queue_free()

func _sync_crew(sheltered: Array) -> void:
	for id in Rules.RADIATION_CREW:
		var hide_it := sheltered.has(id)
		if hidden_crew.get(id, false) == hide_it: continue
		hidden_crew[id] = hide_it
		var actor := world.get_node("Outpost/" + id) as Node3D
		actor.visible = not hide_it
		var body := actor.get_node_or_null("CrewBody") as CollisionObject3D
		if body != null: body.collision_layer = 0 if hide_it else 1
		var area := actor.get_node_or_null("InteractionArea") as Area3D
		if area != null:
			area.monitoring = not hide_it
			if hide_it: world.get_node("Outpost/Astronaut").clear_nearby_interactable(area)

func _restore() -> void:
	if active and is_instance_valid(environment):
		for key in original: environment.set(key, original[key])
	active = false
	for front in fronts: front.hide()
	if is_instance_valid(sign_layer): sign_layer.hide()
	if is_instance_valid(sun): sun.light_color = sun_color

func _exit_tree() -> void:
	_restore()
