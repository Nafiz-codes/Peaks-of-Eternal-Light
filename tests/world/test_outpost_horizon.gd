extends SceneTree

const Polar = preload("res://src/world/polar_terrain.gd")
const Terrain = preload("res://src/world/outpost_terrain.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _init() -> void:
	for site in JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json")).sites:
		var id := str(site.site_id)
		var patch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/polar/%s_terrain.json" % id))
		var n := int(patch.size)
		# Check all four outer edges against the source DEM, including corners.
		for i in range(n):
			for cell in [Vector2i(i, 0), Vector2i(i, n-1), Vector2i(0, i), Vector2i(n-1, i)]:
				var p := Vector2.ONE * float(patch.origin_m) + Vector2(cell) * float(patch.step_m)
				check(absf(Polar.height(id, p.x, p.y) - float(patch.height_m[cell.y*n+cell.x])) < 0.001, id + ": outer relief must not rise to pad height")
		check(is_equal_approx(Polar.height(id, 0, 0), 0.0), id + ": landing pad remains level")
		var ground := Terrain.build(site)
		var horizon := Terrain.build_surroundings(site, ground.material_override)
		var vertices: PackedVector3Array = horizon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			check(is_finite(point.y), id + ": finite horizon geometry")
			if is_equal_approx(maxf(absf(point.x), absf(point.z)), 60.0):
				check(absf(point.y - Polar.height(id, point.x, point.z)) < 0.001, id + ": seamless playable boundary")
		check(horizon.get_aabb().size.x >= 6000.0, id + ": scenery extends beyond source patch")
		ground.free()
		horizon.free()
	print("Outpost horizons: %d failures across all four sites." % failures)
	quit(1 if failures else 0)
