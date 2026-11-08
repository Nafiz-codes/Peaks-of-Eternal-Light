extends Node3D
## One visual-only interlude after Frozen Horizon, before Lifeline.
const DURATION := 15.0
const CLOUD = preload("res://src/world/dust_cloud.gdshader")
var session: Node
var expeditions: Node
var environment: Environment
var original: Dictionary = {}
var clouds: Array[MeshInstance3D] = []
var active := false
var elapsed := 0.0
var intensity := 0.0
var bound_data: Dictionary = {}

static func pending(data: Dictionary) -> bool:
	return data.get("completed", []).has(1) and not data.get("completed", []).has(2) and int(data.get("mission", -1)) != 2 and not bool(data.get("dust_storm_complete", false))

func _ready() -> void:
	name = "DustStorm"
	session = get_node("/root/MissionSession")
	expeditions = get_parent().get_node("RoverTraining")
	environment = get_parent().get_node("LunarEnvironment").environment
	var mesh := QuadMesh.new()
	mesh.size = Vector2(9, 7)
	for i in range(36):
		var cloud := MeshInstance3D.new()
		cloud.mesh = mesh
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = CLOUD
		material.set_shader_parameter("phase", float(i) * 7.13)
		cloud.material_override = material
		cloud.hide()
		add_child(cloud)
		clouds.append(cloud)

func _process(delta: float) -> void:
	var data: Dictionary = expeditions.data
	if active and (data != bound_data or not pending(data)):
		_restore()
	if not pending(data) or expeditions.transitioning: return
	if not active:
		bound_data = data
		elapsed = float(data.get("dust_storm_elapsed", 0.0))
		for key in ["fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "fog_sky_affect", "fog_aerial_perspective"]:
			original[key] = environment.get(key)
		active = true
		for cloud in clouds: cloud.show()
	elapsed = minf(DURATION, elapsed + delta)
	data["dust_storm_elapsed"] = elapsed
	# Brief soft edges, with dense near-sight conditions for most of the 15 seconds.
	intensity = smoothstep(0.0, 1.0, elapsed) * (1.0 - smoothstep(13.5, DURATION, elapsed))
	environment.fog_enabled = true
	environment.fog_density = lerpf(float(original.fog_density), 0.85, intensity)
	environment.fog_light_color = Color(0.43, 0.41, 0.37)
	environment.fog_light_energy = 0.8
	environment.fog_sky_affect = intensity
	environment.fog_aerial_perspective = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position
		for i in clouds.size():
			var angle := float(i) * 2.39996 + elapsed * 0.035
			var radius := 2.5 + float(i % 6) * 2.2
			clouds[i].position = Vector3(cos(angle)*radius, sin(float(i)*3.7+elapsed*0.3)*2.0, sin(angle)*radius)
			clouds[i].look_at(camera.global_position, Vector3.UP)
			clouds[i].material_override.set_shader_parameter("opacity", intensity * 0.85)
	if elapsed >= DURATION:
		data["dust_storm_complete"] = true
		_restore()
		session.capture_sol_checkpoint()

func _restore() -> void:
	if active and is_instance_valid(environment):
		for key in original: environment.set(key, original[key])
	active = false
	intensity = 0.0
	for cloud in clouds: cloud.hide()

func _exit_tree() -> void:
	_restore()
