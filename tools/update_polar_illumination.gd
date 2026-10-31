extends SceneTree
const Solar = preload("res://src/simulation/polar_solar.gd")

func _init() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	for site in document.sites:
		var total := 0.0
		var days: Array = []
		for day in range(30):
			var fraction := Solar.daily_fraction(site, day)
			days.append(snappedf(fraction, 0.00001))
			total += fraction
		site.illumination_pct.value = snappedf(total / 30.0 * 100.0, 0.01)
		site.illumination_pct.status_label = "Modeled first 30 Earth days"
		site.illumination_pct.source = "NASA/JPL Horizons DE441 Sun/Earth geometry plus NASA LOLA-derived local horizon; 2026-10-19 through 2026-11-18 UTC, 15-minute quadrature. Mean visible fraction of the solar disk, including Earth occultation; not a measured NASA illumination percentage. Regional horizon coverage excludes more distant terrain. Power additionally accounts for solar distance."
		print(site.name, " average yield: ", site.illumination_pct.value, "%; first 7 days: ", days.slice(0,7))
	var file := FileAccess.open("res://Resources/sites.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "  ", false) + "\n")
	quit()
