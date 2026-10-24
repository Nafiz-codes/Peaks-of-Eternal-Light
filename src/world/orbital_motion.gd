extends Node
const Model = preload("res://src/world/orbital_model.gd")
var session: Node
var world: Node3D
var material: ShaderMaterial
var light: DirectionalLight3D
var observation: Dictionary = {}

func _ready() -> void:
	world = get_parent()
	session = get_node("/root/MissionSession")
	material = world.get_node("LunarEnvironment").environment.sky.sky_material
	light = world.get_node("LowPolarSun")
	apply_sky()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused or not is_finite(delta) or delta < 0.0:
		return
	var clock: Dictionary = session.orbital_clock
	if session.dashboard_state != null:
		# One gameplay Sol is one modeled Earth day. Only the mission calendar
		# advances time; interpolate a Sol change over a few seconds for the sky.
		var target: float = session.dashboard_state.sol * Model.DAY
		clock.elapsed_seconds = move_toward(clock.elapsed_seconds, target, delta * Model.DAY / 4.0)
	elif not clock.paused:
		clock.elapsed_seconds = minf(Model.MAX_ELAPSED, clock.elapsed_seconds + delta * clock.time_scale)
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
	light.light_energy = 1.1 * smoothstep(-sin(radius), sin(radius), direction.y)
	world.set_meta("earth_distance_km", observation.earth_position_km.length())
	world.set_meta("earth_render_distance_km", observation.earth_position_km.length() * world.EARTH_DISTANCE_SCALE)
	world.set_meta("earth_render_elevation_deg", rad_to_deg(asin(observation.earth_position_km.normalized().y)))

func set_speed(speed: float) -> void:
	if speed in Model.SPEEDS:
		session.orbital_clock.time_scale = speed

func set_paused(paused_: bool) -> void:
	session.orbital_clock.paused = paused_

func timestamp() -> String:
	var seconds: float = float(Time.get_unix_time_from_datetime_string(Model.START_UTC)) + session.orbital_clock.elapsed_seconds
	return Time.get_datetime_string_from_unix_time(int(seconds)).replace("T", " ") + " UTC (model)"
