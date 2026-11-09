extends RefCounted
## Compact NASA LOLA-derived local patches. Flattening the landing pad is an
## explicit gameplay adaptation; the horizon retains the sampled relief.
static var patches: Dictionary = {}

static func height(site_id: String, east: float, south: float) -> float:
	if not patches.has(site_id):
		patches[site_id] = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/polar/%s_terrain.json" % site_id))
	var patch: Dictionary = patches[site_id]
	var x := clampf((east - float(patch.origin_m)) / float(patch.step_m), 0.0, float(patch.size) - 1.0)
	var z := clampf((south - float(patch.origin_m)) / float(patch.step_m), 0.0, float(patch.size) - 1.0)
	var ix := mini(int(x), int(patch.size) - 2)
	var iz := mini(int(z), int(patch.size) - 2)
	var index := iz * int(patch.size) + ix
	var heights: Array = patch.height_m
	var first := lerpf(float(heights[index]), float(heights[index + 1]), x - ix)
	var second := lerpf(float(heights[index + int(patch.size)]), float(heights[index + int(patch.size) + 1]), x - ix)
	var sampled_height := lerpf(first, second, z - iz)
	var local_relief := sampled_height * smoothstep(32.0, 60.0, Vector2(east, south).length())
	# Never fade the DEM to pad height: these high landing sites overlook deep
	# basins, so that produced a square, hundreds-of-metres-high enclosing wall.
	# Beyond the source patch, carry its edge elevation into a gently descending
	# visual apron instead. This continuation is scenery, not measured topography.
	var outside := Vector2(east, south) - Vector2(clampf(east, -2500.0, 2500.0), clampf(south, -2500.0, 2500.0))
	return local_relief - outside.length_squared() / (2.0 * 1737400.0)
