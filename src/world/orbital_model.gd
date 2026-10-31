extends RefCounted
## Orbital display model with sampled NASA/JPL local Sun/Earth geometry.
## Positions are in kilometers and time is measured in Earth days.
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
static var ephemeris: Dictionary = {}

static func lunar_orientation(days: float) -> Basis:
	# NASA/NAIF pck00011.tpc, IAU_MOON (2009 series): body -> J2000
	# equatorial, then ecliptic. Includes pole precession and physical libration.
	# UTC is used as a TT approximation only for this display/star orientation.
	var phases := [125.045, 250.089, 260.008, 176.625, 357.529, 311.589, 134.963, 276.617, 34.226, 15.134, 119.743, 239.961, 25.053]
	var rates := [-0.0529921, -0.1059842, 13.0120009, 13.3407154, 0.9856003, 26.4057084, 13.0649930, 0.3287146, 1.7484877, -0.1589763, 0.0036096, 0.1643573, 12.9590088]
	var ra_terms := [-3.8787, -0.1204, 0.0700, -0.0172, 0.0, 0.0072, 0.0, 0.0, 0.0, -0.0052, 0.0, 0.0, 0.0043]
	var dec_terms := [1.5419, 0.0239, -0.0278, 0.0068, 0.0, -0.0029, 0.0009, 0.0, 0.0, 0.0008, 0.0, 0.0, -0.0009]
	var pm_terms := [3.5610, 0.1208, -0.0642, 0.0158, 0.0252, -0.0066, -0.0047, -0.0046, 0.0028, 0.0052, 0.0040, 0.0019, -0.0044]
	var ra := 269.9949 + 0.0031 * days / 36525.0
	var dec := 66.5392 + 0.0130 * days / 36525.0
	var prime := 38.3213 + 13.17635815 * days - 1.4e-12 * days * days
	for i in range(13):
		var angle := deg_to_rad(fposmod(phases[i] + rates[i] * days, 360.0))
		ra += ra_terms[i] * sin(angle)
		dec += dec_terms[i] * cos(angle)
		prime += pm_terms[i] * sin(angle)
	return Basis(Vector3.RIGHT, deg_to_rad(-23.439291111)) * Basis(Vector3(0, 0, 1), deg_to_rad(ra + 90.0)) * Basis(Vector3.RIGHT, deg_to_rad(90.0 - dec)) * Basis(Vector3(0, 0, 1), deg_to_rad(fposmod(prime, 360.0)))

static func sampled_body_vectors(days: float) -> Dictionary:
	if ephemeris.is_empty():
		ephemeris = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/polar/ephemeris.json"))
	var elapsed := (days - days_from_j2000(0.0)) * DAY
	if elapsed < -0.01 or elapsed > MAX_ELAPSED + 0.01:
		return {}
	var index := clampf(elapsed / float(ephemeris.step_seconds), 0.0, float(ephemeris.sun.size() - 1))
	var left := int(floor(index))
	var right := mini(left + 1, ephemeris.sun.size() - 1)
	var result := {}
	for body in ["sun", "earth"]:
		var a: Array = ephemeris[body][left]
		var b: Array = ephemeris[body][right]
		var components: Array = []
		for axis in range(3):
			components.append(lerpf(float(a[axis]), float(b[axis]), index - left))
		result[body + "_components"] = components
		result[body] = Vector3(components[0], components[1], components[2])
	for body in ["sun", "earth"]:
		var distance_key: String = body + "_distance_km"
		if ephemeris.has(distance_key):
			var distances: Array = ephemeris[distance_key]
			result[distance_key] = lerpf(float(distances[left]), float(distances[right]), index - left)
	return result

static func default_clock() -> Dictionary:
	return {"elapsed_seconds": 0.0, "time_scale": 1.0, "paused": false}

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
	var spin := deg_to_rad(fposmod(mean_longitude + 180.0, 360.0))
	var moon_basis := lunar_orientation(days)
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
	# Sun/Earth geometry uses the frozen NASA/JPL Horizons table throughout the
	# supported clock range. Unlike the old mean orbit, this resolves polar seasons.
	var sampled := sampled_body_vectors(days)
	var sun_distance := sun_local.length()
	if not sampled.is_empty():
		var body_to_local := Basis(east, up, -north).transposed()
		var body_offset := up * (MOON_RADIUS_KM + altitude_km)
		earth_local = body_to_local * (sampled.earth - body_offset)
		sun_local = body_to_local * (sampled.sun - body_offset)
		var sun_components: Array = sampled.sun_components
		var site_offset := (MOON_RADIUS_KM + altitude_km) * up
		# Interpolating a 6-hour solar position chord shortens its radius by tens
		# of thousands of km. Restore the independently interpolated Horizons
		# range, then translate from the reference 0N/0E observer to this site.
		var los_x := float(sun_components[0]) - MOON_RADIUS_KM
		var los_y := float(sun_components[1])
		var los_z := float(sun_components[2])
		var los_length := sqrt(los_x * los_x + los_y * los_y + los_z * los_z)
		var range_km := float(sampled.get("sun_distance_km", los_length))
		var sx := MOON_RADIUS_KM + range_km * los_x / los_length - site_offset.x
		var sy := range_km * los_y / los_length - site_offset.y
		var sz := range_km * los_z / los_length - site_offset.z
		sun_distance = sqrt(sx * sx + sy * sy + sz * sz)
	var earth_body_from_local: Basis = system.earth_basis.transposed() * local_to_inertial
	# Earth texture coordinates use X=east, Y=north, Z=prime meridian.
	var body_to_texture := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	return {"earth_position_km": earth_local, "sun_direction": sun_local.normalized(),
		"sun_distance_km": sun_distance, "earth_texture_basis": body_to_texture * earth_body_from_local,
		"star_basis": local_to_inertial, "system": system}
