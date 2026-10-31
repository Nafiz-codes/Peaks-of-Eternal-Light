extends RefCounted
## One lighting model for direct scene light and daily solar energy.
const Orbit = preload("res://src/world/orbital_model.gd")
static var daily_cache: Dictionary = {}

static func horizon_degrees(site: Dictionary, azimuth_deg: float) -> float:
	var profile: Array = site.get("horizon", {}).get("elevation_deg", [])
	if profile.is_empty():
		return 0.0
	var sample := fposmod(azimuth_deg, 360.0) * profile.size() / 360.0
	var i := int(floor(sample))
	return lerpf(float(profile[i]), float(profile[(i + 1) % profile.size()]), sample - i)

static func disk_visible(clearance_rad: float, radius_rad: float) -> float:
	var x := clampf(clearance_rad / radius_rad, -1.0, 1.0)
	return (acos(-x) + x * sqrt(maxf(0.0, 1.0 - x * x))) / PI

static func visibility(site: Dictionary, observation: Dictionary) -> float:
	var sun: Vector3 = observation.sun_direction
	var azimuth := rad_to_deg(atan2(sun.x, -sun.z))
	var altitude := asin(clampf(sun.y, -1.0, 1.0))
	var radius := asin(Orbit.SUN_RADIUS_KM / float(observation.sun_distance_km))
	var visible := disk_visible(altitude - deg_to_rad(horizon_degrees(site, azimuth)), radius)
	# Geometric lunar eclipses: Earth can occult the Sun. Atmospheric red light
	# is not included in power generation. Partial overlap uses the disk area.
	var earth: Vector3 = observation.earth_position_km
	var separation := sun.angle_to(earth.normalized())
	var earth_radius := asin(Orbit.EARTH_RADIUS_KM / earth.length())
	if separation >= radius + earth_radius:
		return visible
	if separation <= earth_radius - radius:
		return 0.0
	var d := maxf(separation, 1e-9)
	var a := acos(clampf((d*d + radius*radius - earth_radius*earth_radius) / (2*d*radius), -1.0, 1.0))
	var b := acos(clampf((d*d + earth_radius*earth_radius - radius*radius) / (2*d*earth_radius), -1.0, 1.0))
	var overlap := radius*radius*a + earth_radius*earth_radius*b - 0.5*sqrt(maxf(0.0, (-d+radius+earth_radius)*(d+radius-earth_radius)*(d-radius+earth_radius)*(d+radius+earth_radius)))
	return visible * clampf(1.0 - overlap / (PI * radius * radius), 0.0, 1.0)

static func observation_at(site: Dictionary, elapsed: float) -> Dictionary:
	var coords: Dictionary = site.coordinates
	return Orbit.observer(Orbit.days_from_j2000(elapsed), coords.latitude_deg, coords.longitude_deg, float(site.elevation_m.value) / 1000.0)

static func daily_fraction(site: Dictionary, day_index: int, include_distance := false) -> float:
	# Midpoint quadrature at 15-minute intervals over the COMPLETED Earth day.
	# Capacity assumes Sun-tracking panels, not horizontal panels at the pole.
	var key := "%s:%d:%s" % [site.hash(), day_index, include_distance]
	if daily_cache.has(key):
		return daily_cache[key]
	var total := 0.0
	for i in range(96):
		var observation := observation_at(site, (day_index + (i + 0.5) / 96.0) * Orbit.DAY)
		var distance_factor := pow(Orbit.AU_KM / float(observation.sun_distance_km), 2.0) if include_distance else 1.0
		total += visibility(site, observation) * distance_factor
	if daily_cache.size() > 4096:
		daily_cache.clear()
	daily_cache[key] = total / 96.0
	return total / 96.0
