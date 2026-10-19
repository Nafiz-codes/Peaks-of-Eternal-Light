extends RefCounted
## Approximate analytic orbits in J2000 ecliptic coordinates, kilometers and days.
## Real NASA/JPL constants; not a numerical DE440/SPICE ephemeris.
const DAY := 86400.0
const AU_KM := 149597870.7
const EARTH_YEAR_DAYS := 365.25636
const EARTH_SPIN_SECONDS := 86164.09054
const MOON_SIDEREAL_DAYS := 27.3217
const MOON_AXIS_TILT_DEG := 1.54 # 6.68 degree obliquity minus 5.145 degree orbit inclination.
const MOON_RADIUS_KM := 1737.4
const EARTH_RADIUS_KM := 6378.137
const SUN_RADIUS_KM := 695700.0
const MOON_MASS_FRACTION := 4902.800118 / (398600.435507 + 4902.800118)
const START_UTC := "2026-10-19T00:00:00"
const J2000_UNIX := 946728000.0
const MAX_ELAPSED := 7305.0 * DAY # Keep within the JPL short-interval element fit.
const SPEEDS := [1.0, 60.0, 3600.0, 86400.0]

static func default_clock() -> Dictionary:
	return {"elapsed_seconds": 0.0, "time_scale": 3600.0, "paused": false}

static func valid_clock(clock: Variant) -> bool:
	return clock is Dictionary and clock.get("elapsed_seconds") is float and is_finite(clock.elapsed_seconds) and clock.elapsed_seconds >= 0.0 and clock.elapsed_seconds <= MAX_ELAPSED and clock.get("time_scale") in SPEEDS and clock.get("paused") is bool

static func days_from_j2000(elapsed: float) -> float:
	return (float(Time.get_unix_time_from_datetime_string(START_UTC)) - J2000_UNIX + elapsed) / DAY

static func eccentric_anomaly(mean_anomaly: float, eccentricity: float) -> float:
	var mean := wrapf(mean_anomaly, -PI, PI)
	var eccentric := mean
	for i in range(12):
		var correction := (eccentric - eccentricity * sin(eccentric) - mean) / (1.0 - eccentricity * cos(eccentric))
		eccentric -= correction
		if absf(correction) < 1e-12:
			break
	return eccentric

static func ellipse(a: float, e: float, mean_deg: float, inclination_deg: float, node_deg: float, periapsis_deg: float) -> Vector3:
	var eccentric := eccentric_anomaly(deg_to_rad(mean_deg), e)
	var plane := Vector3(a * (cos(eccentric) - e), a * sqrt(1.0 - e * e) * sin(eccentric), 0)
	return Basis(Vector3(0, 0, 1), deg_to_rad(node_deg)) * Basis(Vector3.RIGHT, deg_to_rad(inclination_deg)) * Basis(Vector3(0, 0, 1), deg_to_rad(periapsis_deg)) * plane

static func bodies(days: float) -> Dictionary:
	var century := days / 36525.0
	# JPL approximate planets table 1: this orbit belongs to the Earth/Moon barycenter.
	var a := (1.00000261 + 0.00000562 * century) * AU_KM
	var e := 0.01671123 - 0.00004392 * century
	var inclination := -0.00001531 - 0.01294668 * century
	var longitude := 100.46457166 + 35999.37244981 * century
	var perihelion := 102.93768193 + 0.32327364 * century
	var barycenter := ellipse(a, e, longitude - perihelion, inclination, 0.0, perihelion)
	# JPL lunar mean elements at J2000; slow node/apsis precession is approximate.
	var node := 125.08 - 360.0 * days / (18.600 * 365.25)
	var periapsis := 318.15 + 360.0 * days / (5.997 * 365.25)
	var mean_longitude := 125.08 + 318.15 + 135.27 + 360.0 * days / MOON_SIDEREAL_DAYS
	var moon_relative := ellipse(384400.0, 0.0554, mean_longitude - node - periapsis, 5.16, node, periapsis)
	var earth := barycenter - moon_relative * MOON_MASS_FRACTION
	# The Moon's solar orbit is inherited from the Earth/Moon system, never a second independent orbit.
	var moon := earth + moon_relative
	# Mean synchronous rotation. Eccentric motion gives optical longitude libration.
	# Cassini-state approximation: spin pole is on the other side of the ecliptic normal.
	var pole := Basis(Vector3(0, 0, 1), deg_to_rad(node)) * Basis(Vector3.RIGHT, deg_to_rad(-MOON_AXIS_TILT_DEG)) * Vector3(0, 0, 1)
	var spin := deg_to_rad(fposmod(mean_longitude + 180.0, 360.0))
	var prime := Vector3(cos(spin), sin(spin), 0).slide(pole).normalized()
	var moon_basis := Basis(prime, pole.cross(prime).normalized(), pole).orthonormalized()
	var earth_spin := TAU * fposmod(days * DAY / EARTH_SPIN_SECONDS, 1.0)
	var earth_basis := Basis(Vector3.RIGHT, deg_to_rad(23.43928)) * Basis(Vector3(0, 0, 1), earth_spin + deg_to_rad(280.46061837))
	return {"earth_km": earth, "moon_km": moon, "moon_relative_km": moon_relative,
		"barycenter_km": barycenter, "moon_basis": moon_basis, "earth_basis": earth_basis,
		"moon_spin_rad": spin, "earth_spin_rad": earth_spin,
		"earth_orbit_rad": deg_to_rad(fposmod(longitude, 360.0))}

static func observer(days: float, latitude_deg: float, longitude_deg: float, altitude_km := 0.0) -> Dictionary:
	var system := bodies(days)
	var lat := deg_to_rad(latitude_deg)
	var lon := deg_to_rad(longitude_deg)
	var up := Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
	var east := Vector3(-sin(lon), cos(lon), 0)
	var north := Vector3(-sin(lat) * cos(lon), -sin(lat) * sin(lon), cos(lat))
	# Surface gameplay stays in its local east/up/south frame, riding the rotating Moon.
	var local_to_inertial: Basis = system.moon_basis * Basis(east, up, -north)
	var inertial_to_local := local_to_inertial.transposed()
	var surface_offset: Vector3 = system.moon_basis * up * (MOON_RADIUS_KM + altitude_km)
	var earth_local: Vector3 = inertial_to_local * (-system.moon_relative_km - surface_offset)
	var sun_local: Vector3 = inertial_to_local * (-system.moon_km - surface_offset)
	var earth_body_from_local: Basis = system.earth_basis.transposed() * local_to_inertial
	# Earth texture coordinates use X=east, Y=north, Z=prime meridian.
	var body_to_texture := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	return {"earth_position_km": earth_local, "sun_direction": sun_local.normalized(),
		"sun_distance_km": sun_local.length(), "earth_texture_basis": body_to_texture * earth_body_from_local,
		"star_basis": local_to_inertial, "system": system}
