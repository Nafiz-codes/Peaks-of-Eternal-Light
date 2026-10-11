extends RefCounted

# Decoded from the archived MAP2 GeoTIFF; rows run north to south.
# DN * 0.5 = meters above the 1,737,400 m lunar reference sphere.
const HEIGHTS := [[-1076.0, -1069.5, -1068.0], [-1063.5, -1054.0, -1050.5]]
const RADIUS := 1737400.0
const PIXEL_SIZE := 59.2252938
const UPPER_LEFT_X := 10573017.899764
const UPPER_LEFT_Y := -1315038.4235352
const CENTER_LAT := -43.37
const CENTER_LON := 348.68
const PAD_RADIUS := 32.0
const PAD_BLEND_END := 48.0

static func elevation(x: float, z: float) -> float:
	# +X east, -Z north. Equirectangular source has its standard parallel at 0.
	var projected_x := RADIUS * deg_to_rad(CENTER_LON) + x / cos(deg_to_rad(CENTER_LAT))
	var projected_y := RADIUS * deg_to_rad(CENTER_LAT) - z
	# Pixel centers, not pixel edges. Column zero is NoData in both rows.
	# Clamp to valid centers at crop edges instead of treating NoData as height.
	var column := clampf((projected_x - UPPER_LEFT_X) / PIXEL_SIZE - 1.5, 0.0, 2.0)
	var row := clampf((UPPER_LEFT_Y - projected_y) / PIXEL_SIZE - 0.5, 0.0, 1.0)
	var left := mini(int(floor(column)), 1)
	var fraction := column - float(left)
	return lerpf(lerpf(HEIGHTS[0][left], HEIGHTS[0][left + 1], fraction), lerpf(HEIGHTS[1][left], HEIGHTS[1][left + 1], fraction), row)

static func height(x: float, z: float) -> float:
	# Keep the existing level landing pad and feather it into measured relief.
	return (elevation(x, z) - elevation(0.0, 0.0)) * smoothstep(PAD_RADIUS, PAD_BLEND_END, Vector2(x, z).length())
