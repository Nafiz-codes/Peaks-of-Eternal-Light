extends Node
const Model = preload("res://src/world/orbital_model.gd")
const Solar = preload("res://src/simulation/polar_solar.gd")
const ExpeditionTerrain = preload("res://src/world/expedition_terrain.gd")
# Dim fill keeps terrain readable without headlights; the beam reveals detail.
const LIFELINE_AMBIENT_ENERGY := 0.16
var session: Node
var world: Node3D
var material: ShaderMaterial
var light: DirectionalLight3D
var observation: Dictionary = {}
var environment: Environment
var daylight_ambient_energy := 0.25

func _ready() -> void:
	world = get_parent()
	session = get_node("/root/MissionSession")
	environment = world.get_node("LunarEnvironment").environment
	daylight_ambient_energy = environment.ambient_light_energy
	material = environment.sky.sky_material
	light = world.get_node("LowPolarSun")
	if session.dashboard_state == null:
		session.orbital_clock.elapsed_seconds = Solar.bright_start(world.site_record)
	apply_sky()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused or not is_finite(delta) or delta < 0.0:
		return
	# Crew draw and production run on play time; conversations hold the clock.
	if not bool(world.get("maya_dialogue_active")): session.tick_play(delta)
	var clock: Dictionary = session.orbital_clock
	if not clock.paused:
		var previous: float = clock.elapsed_seconds
		clock.elapsed_seconds = minf(Model.MAX_ELAPSED, clock.elapsed_seconds + delta * clock.time_scale)
		session.account_elapsed_time(clock.elapsed_seconds - previous)
		if clock.elapsed_seconds >= Model.MAX_ELAPSED:
			clock.paused = true
	apply_sky()

func apply_sky() -> void:
	var coords: Dictionary = world.site_record.coordinates
	var altitude := float(world.site_record.elevation_m.get("value", 0.0)) / 1000.0
	observation = Model.observer(Model.days_from_j2000(session.orbital_clock.elapsed_seconds), coords.latitude_deg, coords.longitude_deg, altitude)
	material.set_shader_parameter("earth_position_km", observation.earth_position_km * world.EARTH_DISTANCE_SCALE)
	material.set_shader_parameter("earth_radius_km", Model.EARTH_RADIUS_KM)
	material.set_shader_parameter("earth_texture_basis", observation.earth_texture_basis)
	material.set_shader_parameter("star_basis", observation.star_basis)
	material.set_shader_parameter("display_sun_direction", observation.sun_direction)
	var radius := asin(Model.SUN_RADIUS_KM / observation.sun_distance_km)
	material.set_shader_parameter("sun_angular_radius", radius)
	var direction: Vector3 = observation.sun_direction
	light.look_at(light.global_position - direction, Vector3.FORWARD if absf(direction.y) > 0.999 else Vector3.UP)
	# No direct sunlight from below the lunar horizon; keep artistic ambient fill.
	# DustStorm sets storm_light_factor while airborne dust blocks part of the sunlight.
	var visibility := Solar.visibility(world.site_record, observation) * float(world.get_meta("storm_light_factor", 1.0))
	# Lifeline takes place in a sheltered basin with no direct sunlight.
	# Check the viewing location as well as the assignment so remote-control exit
	# and the outpost arrival cinematic immediately regain normal lighting.
	var shadowed := is_lifeline_shadowed()
	if shadowed: visibility = 0.0
	environment.ambient_light_energy = LIFELINE_AMBIENT_ENERGY if shadowed else daylight_ambient_energy
	light.light_energy = 1.1 * visibility * pow(Model.AU_KM / float(observation.sun_distance_km), 2.0)
	material.set_shader_parameter("sun_visibility", visibility)
	world.set_meta("sun_visibility", visibility)
	world.set_meta("sun_elevation_deg", rad_to_deg(asin(clampf(direction.y, -1.0, 1.0))))
	world.set_meta("earth_distance_km", observation.earth_position_km.length())
	world.set_meta("earth_render_distance_km", observation.earth_position_km.length() * world.EARTH_DISTANCE_SCALE)
	world.set_meta("earth_render_elevation_deg", rad_to_deg(asin(observation.earth_position_km.normalized().y)))

func is_lifeline_shadowed() -> bool:
	if session.dashboard_state == null: return false
	var expedition: Dictionary = session.dashboard_state.rover_expedition
	if expedition.get("mission", -1) != 2 or expedition.get("location", "outpost") != "expedition": return false
	var camera := world.get_viewport().get_camera_3d()
	if camera == null: return false
	var offset := camera.global_position - ExpeditionTerrain.ORIGIN
	return absf(offset.x) < 1500.0 and absf(offset.z) < 1500.0

func set_speed(speed: float) -> void:
	if speed in Model.SPEEDS:
		session.orbital_clock.time_scale = speed

func set_paused(paused_: bool) -> void:
	session.orbital_clock.paused = paused_

func timestamp() -> String:
	var seconds: float = float(Time.get_unix_time_from_datetime_string(Model.START_UTC)) + session.orbital_clock.elapsed_seconds
	return Time.get_datetime_string_from_unix_time(int(seconds)).replace("T", " ") + " UTC (model)"


