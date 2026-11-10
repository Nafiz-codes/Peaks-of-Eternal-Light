extends Node3D
## Radiation wave between Surface Survey and Frozen Horizon. Runs the countdown while the
## Commander orders the crew into the radiation habitat, hides sheltered crew, charges
## the exposure once when the wave hits, and shows the wave: glowing particle fronts
## sweeping in from the Sun in solar-flare orange, a warm tint and a flashing warning sign.
const Rules = preload("res://src/simulation/rover_expedition.gd")
const UI = preload("res://src/ui/ui_style.gd")
const ORDERS_SECONDS := 75.0 # Time to reach every crew member (paused during dialogue).
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

func seconds_left() -> int:
	return ceili(maxf(0.0, ORDERS_SECONDS - float(expeditions.data.get("radiation_elapsed", 0.0))))

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
	if told.size() >= Rules.RADIATION_CREW.size(): start_wave()
	else:
		session.capture_sol_checkpoint()
		session.state_changed.emit()

## The wave hits: the stage change and the exposure charge happen together, once.
func start_wave() -> void:
	var data: Dictionary = expeditions.data
	if Rules.radiation(data) not in ["alert", "orders"]: return
	var sheltered: int = data.get("radiation_told", []).size() if shelter_built() else 0
	data["radiation"] = "wave"
	data["radiation_elapsed"] = 0.0
	session.apply_radiation_wave(Rules.RADIATION_CREW.size() - sheltered)

func _process(delta: float) -> void:
	var data: Dictionary = expeditions.data
	var stage := Rules.radiation(data)
	_sync_crew(Rules.sheltered(data) if shelter_built() else [])
	if active and (data != bound_data or stage != "wave"):
		_restore()
	if get_tree().paused or session.dashboard_state == null: return
	if stage == "orders":
		# The countdown waits while someone is talking.
		if world.maya_dialogue_active: return
		data["radiation_elapsed"] = float(data.get("radiation_elapsed", 0.0)) + delta
		if float(data.radiation_elapsed) >= ORDERS_SECONDS: start_wave()
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
