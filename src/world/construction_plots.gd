extends RefCounted
## Surveyed construction plots in outpost-local metres. Same compact site plan,
## graded against each landing site's own terrain; never generated on selection.
const PLOTS := {
	"solar_array": {"name": "Solar Panel", "center": Vector2(45, -39), "size": Vector2(12, 12)},
	"maya_station": {"name": "Maya · Operations", "center": Vector2(-8, 14), "size": Vector2(22, 22)},
	"alex_station": {"name": "Alex · Science", "center": Vector2(-40, -2), "size": Vector2(22, 22)},
	"sam_station": {"name": "Sam · Engineering", "center": Vector2(43, 41), "size": Vector2(22, 22)},
	"water_extractor": {"name": "Water Extractor", "center": Vector2(-40, 30), "size": Vector2(16, 16)},
	"greenhouse": {"name": "Greenhouse Module", "center": Vector2(-8, 44), "size": Vector2(22, 22)},
	"shielding_wall": {"name": "Radiation Shielding Habitat", "center": Vector2(-40, -40), "size": Vector2(26, 26)},
	"habitat_module": {"name": "Habitat Extension", "center": Vector2(-8, -44), "size": Vector2(22, 22)},
	"comms_relay": {"name": "Comms Relay", "center": Vector2(22, -38), "size": Vector2(14, 14)}
}

static func rect(id: String, margin := 0.0) -> Rect2:
	var plot: Dictionary = PLOTS[id]
	return Rect2(plot.center - plot.size * 0.5, plot.size).grow(margin)

static func contains(id: String, point: Vector3, margin := 0.0) -> bool:
	if not PLOTS.has(id): return false
	var bounds := rect(id, -margin)
	return point.x >= bounds.position.x and point.x <= bounds.end.x and point.z >= bounds.position.y and point.z <= bounds.end.y

static func fits(id: String, transform_: Transform3D, half: Vector2, clearance := 0.6) -> bool:
	for x in [-half.x - clearance, half.x + clearance]:
		for z in [-half.y - clearance, half.y + clearance]:
			if not contains(id, transform_ * Vector3(x, 0, z)): return false
	return true

static func reserved(point: Vector2, margin := 3.0) -> bool:
	for id in PLOTS:
		if rect(id, margin).has_point(point): return true
	return false

static func legacy_regions(session: Node) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var placements: Dictionary = session.station_placements.duplicate()
	placements.merge(session.building_placements)
	if session.solar_placement.has("transform"): placements.solar_array = session.solar_placement.transform
	for id in placements:
		var transform_: Transform3D = placements[id]
		# New placements already rest on the prepared datum. Older transforms
		# retain their original terrain instead of being moved, buried or lifted.
		if contains(id, transform_.origin) and absf(transform_.origin.y) < 0.05: continue
		var radius := 3.0 if id == "solar_array" else 11.0
		regions.append(Rect2(Vector2(transform_.origin.x, transform_.origin.z) - Vector2.ONE * radius, Vector2.ONE * radius * 2))
	return regions

static func grade(point: Vector2, original: float, levels: Dictionary, protected: Array[Rect2] = []) -> float:
	var preserve := 0.0
	for region in protected:
		var outside := (point - region.get_center()).abs() - region.size * 0.5
		preserve = maxf(preserve, 1.0 - smoothstep(0.0, 4.0, maxf(outside.x, outside.y)))
	var influence := 0.0
	var target := 0.0
	var total_weight := 0.0
	for id in PLOTS:
		var plot: Dictionary = PLOTS[id]
		var outside: Vector2 = (point - plot.center).abs() - plot.size * 0.5
		# Rounded shoulders merge adjoining pads without first-match seams.
		var distance := Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()
		var weight := 1.0 - smoothstep(1.0, 28.0, distance)
		influence = maxf(influence, weight)
		target += float(levels[id]) * weight
		total_weight += weight
	if total_weight <= 0.0: return original
	return lerpf(lerpf(original, target / total_weight, influence), original, preserve)
