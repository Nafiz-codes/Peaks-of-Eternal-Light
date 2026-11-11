extends Node3D
## One visual-only interlude after Frozen Horizon, before Lifeline.
const DURATION := 15.0
const CLOUD = preload("res://src/world/dust_cloud.gdshader")
# Exponential fog: half-hidden at about 3.5 m, mostly hidden past 11 m; nearby crew stay readable.
const FOG_DENSITY := 0.20
const CLOUD_OPACITY := 0.5
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const FLASH_PERIOD := 0.5
# Direct sunbeams lose more than total light: dust scatters the beam into a dim, warm haze.
# Solar power still uses Simulator.DUST_STORM_LIGHT_MULTIPLIER, which counts the scattered light.
const VISUAL_LIGHT_FACTOR := 0.3
const DUSTY_SUN := Color(1.0, 0.7, 0.45)
const DUSTY_AMBIENT := Color("b39c80")
var sun: DirectionalLight3D
var sun_color := Color.WHITE
const FLASH_TINT := Color(1.0, 0.38, 0.2) # Blood orange
var sign_layer: CanvasLayer
var warning_sign: Control

const UI = preload("res://src/ui/ui_style.gd")

## Warning triangle with "!" in the objective style: gold strokes with a dark outline.
class WarningTriangle extends Control:
	const Style = preload("res://src/ui/ui_style.gd")
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var corners := PackedVector2Array([Vector2(w * 0.5, 4), Vector2(4, h - 4), Vector2(w - 4, h - 4), Vector2(w * 0.5, 4)])
		draw_colored_polygon(corners.slice(0, 3), Color(Style.OBJECTIVE_OUTLINE, 0.55))
		draw_polyline(corners, Style.OBJECTIVE_OUTLINE, 7.0, true)
		draw_polyline(corners, Style.OBJECTIVE, 3.5, true)
		var bar := PackedVector2Array([Vector2(w * 0.5 - 4, h * 0.32), Vector2(w * 0.5 + 4, h * 0.32), Vector2(w * 0.5 + 2, h * 0.68), Vector2(w * 0.5 - 2, h * 0.68)])
		draw_polyline(bar + PackedVector2Array([bar[0]]), Style.OBJECTIVE_OUTLINE, 3.0, true)
		draw_colored_polygon(bar, Style.OBJECTIVE)
		draw_circle(Vector2(w * 0.5, h * 0.8), 4.5, Style.OBJECTIVE_OUTLINE)
		draw_circle(Vector2(w * 0.5, h * 0.8), 3.0, Style.OBJECTIVE)
var session: Node
var expeditions: Node
var environment: Environment
var original: Dictionary = {}
var clouds: Array[MeshInstance3D] = []
var active := false
var elapsed := 0.0
var intensity := 0.0
var bound_data: Dictionary = {}

## The storm waits until Alex's Science station is up after Frozen Horizon (storm_ready).
static func pending(data: Dictionary) -> bool:
	return data.get("completed", []).has(1) and not data.get("completed", []).has(2) and int(data.get("mission", -1)) != 2 and not bool(data.get("dust_storm_complete", false)) and bool(data.get("storm_ready", false))

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
	sign_layer = CanvasLayer.new()
	sign_layer.layer = 58 # Above the HUD, below the pause menu.
	add_child(sign_layer)
	# Top-right block mirroring the objective at top-left: icon, then title and detail lines.
	var hazard := VBoxContainer.new()
	hazard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hazard.add_theme_constant_override("separation", 2)
	sign_layer.add_child(hazard)
	hazard.anchor_left = 1.0
	hazard.anchor_right = 1.0
	hazard.offset_left = -164.0
	hazard.offset_right = -22.0
	hazard.offset_top = 20.0
	var triangle := WarningTriangle.new()
	triangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	triangle.custom_minimum_size = Vector2(76, 64)
	triangle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hazard.add_child(triangle)
	var font := UI.objective_font()
	for line in [["Warning", 15], ["Dust storm", 20]]:
		var text := UI.objective_label(font, line[1])
		text.text = line[0]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hazard.add_child(text)
	warning_sign = hazard
	sign_layer.hide()

func _process(delta: float) -> void:
	var data: Dictionary = expeditions.data
	if active and (data != bound_data or not pending(data)):
		_restore()
	if not pending(data) or expeditions.transitioning: return
	if not active:
		bound_data = data
		elapsed = float(data.get("dust_storm_elapsed", 0.0))
		for key in ["fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "fog_sky_affect", "fog_aerial_perspective", "ambient_light_color"]:
			original[key] = environment.get(key)
		sun = get_parent().get_node_or_null("LowPolarSun")
		if sun != null: sun_color = sun.light_color
		active = true
		for cloud in clouds: cloud.show()
		sign_layer.show()
		session.apply_dust_storm()
	elapsed = minf(DURATION, elapsed + delta)
	data["dust_storm_elapsed"] = elapsed
	# Brief soft edges, with a hazy but navigable storm for most of the 15 seconds.
	intensity = smoothstep(0.0, 1.0, elapsed) * (1.0 - smoothstep(13.5, DURATION, elapsed))
	environment.fog_enabled = true
	environment.fog_density = lerpf(float(original.fog_density), FOG_DENSITY, intensity)
	environment.fog_light_color = Color(0.43, 0.41, 0.37)
	environment.fog_light_energy = lerpf(0.8, 0.55, intensity)
	environment.fog_sky_affect = intensity * 0.75
	environment.fog_aerial_perspective = 0.0
	# Dimmer, warmer sun and dust-tinted shadows, eased in and out with the storm.
	get_parent().set_meta("storm_light_factor", lerpf(1.0, VISUAL_LIGHT_FACTOR, intensity))
	if sun != null: sun.light_color = sun_color.lerp(DUSTY_SUN, intensity)
	environment.ambient_light_color = Color(original.ambient_light_color).lerp(DUSTY_AMBIENT, intensity)
	# One blood-orange flash every 0.5 s, fading with the storm.
	var pulse := 1.0 - smoothstep(0.0, 0.25, fposmod(elapsed, FLASH_PERIOD))
	warning_sign.modulate = Color.WHITE.lerp(FLASH_TINT, pulse * 0.6)
	warning_sign.modulate.a = clampf(intensity * 1.5, 0.0, 1.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position
		for i in clouds.size():
			# Faster drift reads as wind; starting farther out keeps dust off the lens.
			var angle := float(i) * 2.39996 + elapsed * 0.08
			var radius := 5.0 + float(i % 6) * 2.4
			clouds[i].position = Vector3(cos(angle)*radius, sin(float(i)*3.7+elapsed*0.2)*2.0, sin(angle)*radius)
			clouds[i].look_at(camera.global_position, Vector3.UP)
			clouds[i].material_override.set_shader_parameter("opacity", intensity * CLOUD_OPACITY)
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
	if is_instance_valid(sign_layer): sign_layer.hide()
	if get_parent() != null: get_parent().remove_meta("storm_light_factor")
	if is_instance_valid(sun): sun.light_color = sun_color

func _exit_tree() -> void:
	_restore()
