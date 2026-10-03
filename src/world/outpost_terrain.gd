extends RefCounted

# Deterministic art direction per site, not a reconstruction of LOLA pixels.
static func build(site: Dictionary) -> MeshInstance3D:
	var seed_value := absi(str(site.get("site_id", "ridge_a")).hash())
	var noise := FastNoiseLite.new()
	noise.seed = seed_value % 2147483647
	noise.frequency = 0.055
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var amplitude := 2.0 + float(seed_value % 5)
	for z in range(-30, 30):
		for x in range(-30, 30):
			var points: Array[Vector3] = []
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var px: float = (float(x) + offset.x) * 2.0
				var pz: float = (float(z) + offset.y) * 2.0
				var blend := smoothstep(12.0, 27.0, Vector2(px, pz).length())
				var height := blend * (1.5 + noise.get_noise_2d(px, pz) * amplitude)
				points.append(Vector3(px, height, pz))
			for index in [0, 1, 2, 1, 3, 2]:
				surface.set_uv(Vector2(points[index].x, points[index].z) * 0.12)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "LunarRegolith"
	terrain.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	var tones := [Color("666774"), Color("77716c"), Color("626875"), Color("817b70")]
	material.albedo_color = tones[seed_value % tones.size()]
	material.roughness = 0.98
	var grain := NoiseTexture2D.new()
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = noise.seed
	grain_noise.frequency = 0.12
	grain.noise = grain_noise
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.65, 0.65, 0.65), Color(0.9, 0.9, 0.9)])
	grain.color_ramp = ramp
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	material.albedo_texture = grain
	terrain.material_override = material
	return terrain
