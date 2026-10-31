extends SceneTree

const Model = preload("res://src/world/orbital_model.gd")
var failures := 0
var checks := 0

func _init() -> void:
	var validation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/polar/validation.json"))
	var sites: Dictionary = {}
	for site in JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json")).sites:
		sites[site.site_id] = site
	for expected_site in validation.sites:
		var site: Dictionary = sites[expected_site.site_id]
		var coordinates: Dictionary = site.coordinates
		for expected in expected_site.samples:
			var body := "sun" if int(expected.target) == 10 else "earth"
			var observation := Model.observer(
				Model.days_from_j2000(float(expected.elapsed_seconds)),
				float(coordinates.latitude_deg), float(coordinates.longitude_deg),
				float(site.elevation_m.value) / 1000.0
			)
			var vector: Vector3 = observation.sun_direction * observation.sun_distance_km if body == "sun" else observation.earth_position_km
			var azimuth := rad_to_deg(atan2(vector.x, -vector.z))
			var elevation := rad_to_deg(asin(clampf(vector.y / vector.length(), -1.0, 1.0)))
			var delta_azimuth := absf(fposmod(azimuth - float(expected.azimuth_deg) + 180.0, 360.0) - 180.0)
			check(delta_azimuth < 0.08, "%s %s off-grid azimuth matches direct Horizons." % [site.site_id, body])
			check(absf(elevation - float(expected.elevation_deg)) < 0.08, "%s %s off-grid elevation matches direct Horizons." % [site.site_id, body])
			if body == "sun":
				check(absf(float(observation.sun_distance_km) - float(expected.distance_km)) < 150.0, "%s %s off-grid distance matches direct Horizons within 1 ppm." % [site.site_id, body])
	print("Polar ephemeris validation: %d checks, %d failures." % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
