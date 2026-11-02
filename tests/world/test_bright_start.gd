extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var simulator = preload("res://src/simulation/mission_simulator.gd").new()
	assert(simulator.load_contracts() == OK)
	var solar = preload("res://src/simulation/polar_solar.gd")
	for site in simulator.sites:
		var start: float = solar.bright_start(site)
		for hour in range(7):
			var sample: Dictionary = solar.observation_at(site, start + hour * 3600.0)
			assert(solar.visibility(site, sample) >= 0.99, str(site.site_id) + ": six bright hours required")
		print(site.site_id, ": bright start at modeled hour ", start / 3600.0, "; 6 hours of sunlight verified")
	quit()


